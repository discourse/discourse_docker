# frozen_string_literal: true

require "net/http"
require "json"
require_relative "constants"
require_relative "tui_components"

module DiscourseSetup
  class Prompts
    # Helper for confirm dialogs using ratatui
    def self.ratatui_confirm(prompt, default: true)
      TuiComponents::ConfirmDialog.new(prompt, default: default).run
    end

    # Helper for text input using ratatui
    def self.ratatui_input(placeholder:, value: "", header: "", password: false)
      TuiComponents::TextInput.new(
        placeholder: placeholder,
        value: value,
        header: header,
        password: password
      ).run
    end

    # Helper for selection menu using ratatui
    def self.ratatui_choose(items, header: nil)
      TuiComponents::ChooseMenu.new(items, header: header).run
    end

    # Default placeholder values that indicate unconfigured settings
    PLACEHOLDER_VALUES = {
      "DISCOURSE_HOSTNAME" => "discourse.example.com",
      "DISCOURSE_DEVELOPER_EMAILS" => "me@example.com,you@example.com",
      "DISCOURSE_SMTP_ADDRESS" => "smtp.example.com",
      "DISCOURSE_SMTP_USER_NAME" => "user@example.com",
      "DISCOURSE_SMTP_PASSWORD" => "pa$$word"
    }.freeze

    # Known SMTP providers with special username requirements
    SMTP_PROVIDERS = {
      "smtp.sparkpostmail.com" => "SMTP_Injection",
      "smtp.sendgrid.net" => "apikey"
    }.freeze

    def initialize(config_generator:, ui:)
      @config = config_generator
      @ui = ui
      @values = {}
    end

    def collect_all
      loop do
        collect_developer_emails
        collect_has_domain
        if @values[:has_domain]
          collect_hostname
        else
          collect_free_subdomain
        end
        collect_smtp_enabled
        if @values[:smtp_enabled]
          collect_smtp_settings
          collect_notification_email
        end

        # Let's Encrypt is always enabled
        @values[:letsencrypt_enabled] = true

        break if confirm_settings
      end

      @values
    end

    private

    def collect_hostname
      current = @config.read_value("DISCOURSE_HOSTNAME")
      current = nil if current == PLACEHOLDER_VALUES["DISCOURSE_HOSTNAME"]

      loop do
        hostname = Prompts.ratatui_input(
          placeholder: "discourse.example.com",
          value: current || "",
          header: "Hostname for your Discourse?"
        )

        if hostname.empty?
          @ui.error("Hostname is required")
          next
        end

        # Check if it's an IP address
        if hostname.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
          @ui.error("Discourse requires a DNS hostname. IP addresses are unsupported and will not work.")
          current = nil
          next
        end

        @values[:hostname] = hostname
        break
      end
    end

    def collect_has_domain
      @values[:has_domain] = Prompts.ratatui_confirm(
        "Do you have a domain name for your Discourse?",
        default: true
      )
    end

    def collect_free_subdomain
      subdomain_url = "#{DISCOURSE_ID_URL}#{DISCOURSE_ID_SUBDOMAIN_PATH}"

      # Display instructions
      @ui.puts
      @ui.box(<<~INSTRUCTIONS)
        To get a free subdomain:

        1. Visit #{subdomain_url}
        2. Log in and claim your desired subdomain
        3. Click "Generate Code" to get a verification code
        4. Return here and enter your subdomain and code
      INSTRUCTIONS

      # Wait for user to be ready
      Prompts.ratatui_input(
        placeholder: "Press Enter when ready...",
        header: ""
      )

      loop do
        # Collect subdomain
        subdomain = Prompts.ratatui_input(
          placeholder: "mysite",
          header: "Subdomain (without .#{FREE_DOMAIN_BASE})?"
        )

        if subdomain.empty?
          @ui.error("Subdomain is required")
          next
        end

        # Remove the base domain if user accidentally included it
        subdomain = subdomain.sub(/\.#{Regexp.escape(FREE_DOMAIN_BASE)}$/i, "")

        # Collect verification code
        code = Prompts.ratatui_input(
          placeholder: "123456",
          header: "Verification code from Discourse ID?"
        )

        if code.empty?
          @ui.error("Verification code is required")
          next
        end

        # Detect public IP
        @ui.info("Detecting your server's public IP address...")
        ip_address = Prompts.detect_public_ip

        if ip_address.nil?
          @ui.error("Could not detect your server's public IP address.")
          @ui.info("Please check your internet connection and try again.")
          next
        end

        @ui.info("Public IP: #{ip_address}")

        # Verify with Discourse ID
        @ui.info("Verifying subdomain with Discourse ID...")
        begin
          full_domain = verify_subdomain_with_discourse_id(subdomain, code, ip_address)
          @ui.success("Success! Your domain is: #{full_domain}")
          @values[:hostname] = full_domain
          @values[:free_subdomain] = subdomain
          break
        rescue SubdomainNotFound
          @ui.error("Subdomain '#{subdomain}' not found. Please claim it at #{subdomain_url} first.")
        rescue InvalidVerificationCode
          @ui.error("Invalid or expired verification code. Please generate a new code.")
        rescue RateLimited
          @ui.error("Too many attempts. Please wait a moment and try again.")
        rescue VerificationError => e
          @ui.error("Verification failed: #{e.message}")
        end
      end
    end

    # Error classes for subdomain verification
    class SubdomainNotFound < StandardError; end
    class InvalidVerificationCode < StandardError; end
    class RateLimited < StandardError; end
    class VerificationError < StandardError; end

    def verify_subdomain_with_discourse_id(subdomain, code, ip_address)
      uri = URI("#{DISCOURSE_ID_URL}#{DISCOURSE_ID_VERIFY_ENDPOINT}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request.body = {
        subdomain: subdomain,
        code: code,
        ip_address: ip_address
      }.to_json

      response = http.request(request)

      case response.code.to_i
      when 200
        data = JSON.parse(response.body)
        data["full_domain"] || "#{subdomain}.#{FREE_DOMAIN_BASE}"
      when 404
        raise SubdomainNotFound
      when 422
        data = JSON.parse(response.body) rescue {}
        error_msg = data["errors"]&.first || data["error"] || "Verification failed"
        if error_msg.downcase.include?("code") || error_msg.downcase.include?("expired")
          raise InvalidVerificationCode
        else
          raise VerificationError, error_msg
        end
      when 429
        raise RateLimited
      else
        raise VerificationError, "Unexpected response: #{response.code}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise VerificationError, "Connection timed out. Please try again."
    rescue JSON::ParserError
      raise VerificationError, "Invalid response from server"
    rescue Errno::ECONNREFUSED, SocketError => e
      raise VerificationError, "Could not connect to Discourse ID: #{e.message}"
    end

    # Get the server's public IP address
    def self.detect_public_ip
      ip_services = [
        "https://ipv4.icanhazip.com",
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://checkip.amazonaws.com"
      ]

      ip_services.each do |service|
        begin
          uri = URI(service)
          response = Net::HTTP.get(uri).strip
          return response if response.match?(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/)
        rescue StandardError
          next
        end
      end

      nil
    end

    def collect_developer_emails
      current = @config.read_value("DISCOURSE_DEVELOPER_EMAILS")
      current = nil if current == PLACEHOLDER_VALUES["DISCOURSE_DEVELOPER_EMAILS"]

      loop do
        emails = Prompts.ratatui_input(
          placeholder: "admin@example.com",
          value: current || "",
          header: "Email address for admin account(s)?"
        )

        if emails.empty?
          @ui.error("Admin email is required")
          next
        end

        # Basic email validation
        unless emails.length >= 7 && emails.include?("@")
          @ui.error("Invalid email address format")
          next
        end

        @values[:developer_emails] = emails
        break
      end
    end

    def collect_smtp_enabled
      @values[:smtp_enabled] = Prompts.ratatui_confirm(
        "Configure SMTP for sending emails? (Requires SMTP credentials)",
        default: false
      )
    end

    def collect_smtp_settings
      collect_smtp_address
      collect_smtp_port
      collect_smtp_username
      collect_smtp_password
    end

    def collect_smtp_address
      current = @config.read_value("DISCOURSE_SMTP_ADDRESS")
      current = nil if current == PLACEHOLDER_VALUES["DISCOURSE_SMTP_ADDRESS"]

      @values[:smtp_address] = Prompts.ratatui_input(
        placeholder: "smtp.example.com",
        value: current || "",
        header: "SMTP server address?"
      )
    end

    def collect_smtp_port
      current = @config.read_value("DISCOURSE_SMTP_PORT") || "587"

      @values[:smtp_port] = Prompts.ratatui_input(
        placeholder: "587",
        value: current,
        header: "SMTP port?"
      )
    end

    def collect_smtp_username
      current = @config.read_value("DISCOURSE_SMTP_USER_NAME")

      # Auto-set username for known providers if still at placeholder
      if current == PLACEHOLDER_VALUES["DISCOURSE_SMTP_USER_NAME"] || current.nil?
        if SMTP_PROVIDERS.key?(@values[:smtp_address])
          current = SMTP_PROVIDERS[@values[:smtp_address]]
        elsif @values[:smtp_address] == "smtp.mailgun.org"
          current = "postmaster@#{@values[:hostname]}"
        end
      end

      @values[:smtp_user_name] = Prompts.ratatui_input(
        placeholder: "user@example.com",
        value: current || "",
        header: "SMTP user name?"
      )
    end

    def collect_smtp_password
      current = @config.read_value("DISCOURSE_SMTP_PASSWORD")
      current = "" if current == PLACEHOLDER_VALUES["DISCOURSE_SMTP_PASSWORD"]

      @values[:smtp_password] = Prompts.ratatui_input(
        placeholder: "Enter SMTP password",
        value: current || "",
        header: "SMTP password?",
        password: true
      )
    end

    def collect_notification_email
      current = @config.read_value("DISCOURSE_NOTIFICATION_EMAIL")

      # Default to noreply@hostname if not set or using placeholder
      if current.nil? || current.empty? || current.start_with?("noreply@discourse.example.com")
        current = "noreply@#{@values[:hostname]}"
      end

      @values[:notification_email] = Prompts.ratatui_input(
        placeholder: "noreply@#{@values[:hostname]}",
        value: current,
        header: "Notification email address? (address to send notifications from)"
      )

      # Also set SMTP domain based on notification email
      @values[:smtp_domain] = @values[:notification_email].split("@").last
    end

    def confirm_settings
      @ui.puts
      @ui.section("Review Configuration")

      hostname_display = @values[:hostname]
      hostname_display += " (free subdomain)" if @values[:free_subdomain]

      summary_items = {
        "Hostname" => hostname_display,
        "Admin Email" => @values[:developer_emails]
      }

      if @values[:smtp_enabled]
        summary_items.merge!(
          "SMTP Server" => @values[:smtp_address],
          "SMTP Port" => @values[:smtp_port],
          "SMTP Username" => @values[:smtp_user_name],
          "SMTP Password" => mask_password(@values[:smtp_password]),
          "From Address" => @values[:notification_email]
        )
      else
        summary_items["SMTP"] = "(not configured)"
      end

      summary_items["Let's Encrypt"] = "Enabled"

      @ui.summary_box(summary_items)

      @ui.confirm("Does this look right?", default: true)
    end

    def mask_password(password)
      return "(not set)" if password.nil? || password.empty?

      "*" * [password.length, 8].min
    end
  end
end

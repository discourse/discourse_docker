# frozen_string_literal: true

require "gum"

module DiscourseSetup
  class Prompts
    # Default placeholder values that indicate unconfigured settings
    PLACEHOLDER_VALUES = {
      "DISCOURSE_HOSTNAME" => "discourse.example.com",
      "DISCOURSE_DEVELOPER_EMAILS" => "me@example.com,you@example.com",
      "DISCOURSE_SMTP_ADDRESS" => "smtp.example.com",
      "DISCOURSE_SMTP_USER_NAME" => "user@example.com",
      "DISCOURSE_SMTP_PASSWORD" => "pa$$word",
      "LETSENCRYPT_ACCOUNT_EMAIL" => "me@example.com",
      "DISCOURSE_MAXMIND_ACCOUNT_ID" => "123456",
      "DISCOURSE_MAXMIND_LICENSE_KEY" => "1234567890123456"
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
        collect_hostname
        collect_developer_emails
        collect_smtp_settings
        collect_notification_email
        collect_letsencrypt
        collect_maxmind

        break if confirm_settings
      end

      @values
    end

    private

    def collect_hostname
      current = @config.read_value("DISCOURSE_HOSTNAME")
      current = nil if current == PLACEHOLDER_VALUES["DISCOURSE_HOSTNAME"]

      loop do
        hostname = Gum.input(
          placeholder: "discourse.example.com",
          value: current || "",
          header: "Hostname for your Discourse?"
        )

        if hostname.nil? || hostname.empty?
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

    def collect_developer_emails
      current = @config.read_value("DISCOURSE_DEVELOPER_EMAILS")
      current = nil if current == PLACEHOLDER_VALUES["DISCOURSE_DEVELOPER_EMAILS"]

      loop do
        emails = Gum.input(
          placeholder: "admin@example.com",
          value: current || "",
          header: "Email address for admin account(s)?"
        )

        if emails.nil? || emails.empty?
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

    def collect_smtp_settings
      collect_smtp_address
      collect_smtp_port
      collect_smtp_username
      collect_smtp_password
    end

    def collect_smtp_address
      current = @config.read_value("DISCOURSE_SMTP_ADDRESS")
      current = nil if current == PLACEHOLDER_VALUES["DISCOURSE_SMTP_ADDRESS"]

      @values[:smtp_address] = Gum.input(
        placeholder: "smtp.example.com",
        value: current || "",
        header: "SMTP server address?"
      )
    end

    def collect_smtp_port
      current = @config.read_value("DISCOURSE_SMTP_PORT") || "587"

      @values[:smtp_port] = Gum.input(
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

      @values[:smtp_user_name] = Gum.input(
        placeholder: "user@example.com",
        value: current || "",
        header: "SMTP user name?"
      )
    end

    def collect_smtp_password
      current = @config.read_value("DISCOURSE_SMTP_PASSWORD")
      current = "" if current == PLACEHOLDER_VALUES["DISCOURSE_SMTP_PASSWORD"]

      @values[:smtp_password] = Gum.input(
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

      @values[:notification_email] = Gum.input(
        placeholder: "noreply@#{@values[:hostname]}",
        value: current,
        header: "Notification email address? (address to send notifications from)"
      )

      # Also set SMTP domain based on notification email
      @values[:smtp_domain] = @values[:notification_email].split("@").last
    end

    def collect_letsencrypt
      current = @config.read_value("LETSENCRYPT_ACCOUNT_EMAIL")

      if current == PLACEHOLDER_VALUES["LETSENCRYPT_ACCOUNT_EMAIL"] || current.nil?
        status_hint = "ENTER to skip"
        current = ""
      else
        status_hint = "Enter 'OFF' to disable"
      end

      @values[:letsencrypt_email] = Gum.input(
        placeholder: "your-email@example.com (#{status_hint})",
        value: current,
        header: "Optional email address for Let's Encrypt warnings?"
      )
    end

    def collect_maxmind
      current_id = @config.read_value("DISCOURSE_MAXMIND_ACCOUNT_ID")

      if current_id == PLACEHOLDER_VALUES["DISCOURSE_MAXMIND_ACCOUNT_ID"] || current_id.nil?
        status_hint = "ENTER to skip"
        current_id = ""
      else
        status_hint = "Currently configured"
      end

      account_id = Gum.input(
        placeholder: "Account ID (#{status_hint})",
        value: current_id,
        header: "Optional MaxMind Account ID for GeoLite2 geolocation?"
      )

      @values[:maxmind_account_id] = account_id

      # Only ask for license key if account ID was provided
      return if account_id.nil? || account_id.empty?

      current_key = @config.read_value("DISCOURSE_MAXMIND_LICENSE_KEY")
      current_key = "" if current_key == PLACEHOLDER_VALUES["DISCOURSE_MAXMIND_LICENSE_KEY"]

      @values[:maxmind_license_key] = Gum.input(
        placeholder: "License key",
        value: current_key || "",
        header: "MaxMind License key?"
      )
    end

    def confirm_settings
      @ui.puts
      @ui.section("Review Configuration")

      summary_items = {
        "Hostname" => @values[:hostname],
        "Admin Email" => @values[:developer_emails],
        "SMTP Server" => @values[:smtp_address],
        "SMTP Port" => @values[:smtp_port],
        "SMTP Username" => @values[:smtp_user_name],
        "SMTP Password" => mask_password(@values[:smtp_password]),
        "From Address" => @values[:notification_email],
        "Let's Encrypt" => letsencrypt_enabled? ? @values[:letsencrypt_email] : nil,
        "MaxMind" => maxmind_enabled? ? @values[:maxmind_account_id] : nil
      }

      @ui.summary_box(summary_items)

      @ui.confirm("Does this look right?", default: true)
    end

    def mask_password(password)
      return "(not set)" if password.nil? || password.empty?

      "*" * [password.length, 8].min
    end

    def letsencrypt_enabled?
      email = @values[:letsencrypt_email]
      email && !email.empty? && email.downcase != "off"
    end

    def maxmind_enabled?
      id = @values[:maxmind_account_id]
      id && !id.empty? && id != PLACEHOLDER_VALUES["DISCOURSE_MAXMIND_ACCOUNT_ID"]
    end
  end
end

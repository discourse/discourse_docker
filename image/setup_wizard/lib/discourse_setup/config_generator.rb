# frozen_string_literal: true

require "yaml"
require "fileutils"

module DiscourseSetup
  class ConfigGenerator
    TEMPLATE_PATH = "samples/standalone.yml"
    CONFIG_PATH = "containers/app.yml"

    SSL_TEMPLATE = "templates/web.ssl.template.yml"
    LETSENCRYPT_TEMPLATE = "templates/web.letsencrypt.ssl.template.yml"

    # Settings that should be quoted in YAML
    QUOTED_SETTINGS = %w[
      DISCOURSE_SMTP_PASSWORD
      DISCOURSE_DEVELOPER_EMAILS
    ].freeze

    def initialize(base_dir:, ui:)
      @base_dir = base_dir
      @ui = ui
      @template_path = File.join(base_dir, TEMPLATE_PATH)
      @config_path = File.join(base_dir, CONFIG_PATH)
    end

    def config_exists?
      File.exist?(@config_path)
    end

    def load_or_create_config
      if config_exists?
        @ui.info("Found existing configuration at #{CONFIG_PATH}")
        backup_config
        load_existing_config
      else
        @ui.info("Creating new configuration from template...")
        create_from_template
      end
    end

    def load_existing_config
      @content = File.read(@config_path)
      parse_config_values
    end

    def create_from_template
      FileUtils.mkdir_p(File.dirname(@config_path))
      FileUtils.cp(@template_path, @config_path)
      FileUtils.chmod(0o600, @config_path)
      @content = File.read(@config_path)
      parse_config_values
    end

    def backup_config
      timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      backup_path = "#{@config_path}.#{timestamp}.bak"
      @ui.info("Saving backup to #{File.basename(backup_path)}")
      FileUtils.cp(@config_path, backup_path)
      FileUtils.chmod(0o600, backup_path)
    end

    def read_value(key)
      @parsed_values[key]
    end

    def update_config(settings)
      settings.each do |key, value|
        update_setting(key, value)
      end
    end

    def enable_ssl(letsencrypt_email)
      return if letsencrypt_email.nil? || letsencrypt_email.empty? || letsencrypt_email.downcase == "off"

      enable_template(SSL_TEMPLATE)
      enable_template(LETSENCRYPT_TEMPLATE)
      update_setting("LETSENCRYPT_ACCOUNT_EMAIL", letsencrypt_email)
    end

    def save
      File.write(@config_path, @content)
      FileUtils.chmod(0o600, @config_path)
      @ui.success("Configuration saved to #{CONFIG_PATH}")
    end

    private

    def parse_config_values
      @parsed_values = {}

      # Parse key settings from the file content
      settings_to_parse = %w[
        DISCOURSE_HOSTNAME
        DISCOURSE_DEVELOPER_EMAILS
        DISCOURSE_SMTP_ADDRESS
        DISCOURSE_SMTP_PORT
        DISCOURSE_SMTP_USER_NAME
        DISCOURSE_SMTP_PASSWORD
        DISCOURSE_SMTP_DOMAIN
        DISCOURSE_NOTIFICATION_EMAIL
        LETSENCRYPT_ACCOUNT_EMAIL
        DISCOURSE_MAXMIND_ACCOUNT_ID
        DISCOURSE_MAXMIND_LICENSE_KEY
      ]

      settings_to_parse.each do |key|
        @parsed_values[key] = extract_value(key)
      end

      @parsed_values
    end

    def extract_value(key)
      # Match both commented and uncommented lines
      # Format: "  #?KEY: value" or "  #?KEY: 'value'" or "  #?KEY: \"value\""
      pattern = /^\s*#?\s*#{Regexp.escape(key)}:\s*(.+)$/

      match = @content.match(pattern)
      return nil unless match

      value = match[1].strip

      # Remove surrounding quotes if present
      if (value.start_with?('"') && value.end_with?('"')) ||
         (value.start_with?("'") && value.end_with?("'"))
        value = value[1..-2]
      end

      value
    end

    def update_setting(key, value)
      return if value.nil?

      # Determine if we need to quote the value
      quoted_value = format_value(key, value)

      # Pattern matches both commented and uncommented versions
      pattern = /^(\s*)#?\s*(#{Regexp.escape(key)}:).*/

      if @content.match?(pattern)
        # Update existing line (uncomment if necessary)
        @content.gsub!(pattern, "\\1#{key}: #{quoted_value}")
        @ui.debug("Updated #{key}") if @ui.respond_to?(:debug)
      else
        @ui.warning("Setting #{key} not found in config file")
      end
    end

    def format_value(key, value)
      value_str = value.to_s

      # Always quote certain settings
      if QUOTED_SETTINGS.include?(key)
        return "'#{value_str}'"
      end

      # Quote if value contains special characters
      if needs_quoting?(value_str)
        # Use double quotes and escape internal double quotes
        escaped = value_str.gsub('"', '\\"')
        return "\"#{escaped}\""
      end

      value_str
    end

    def needs_quoting?(value)
      # Quote if contains special YAML characters or looks like it could be misinterpreted
      value.match?(/[:#\[\]{}|>&*!?,\\'"@`]/) ||
        value.match?(/^\s/) ||
        value.match?(/\s$/) ||
        value.match?(/^(true|false|null|yes|no|on|off)$/i)
    end

    def enable_template(template_path)
      # Pattern to match commented template line
      escaped_path = Regexp.escape(template_path)
      pattern = /^(\s*)#\s*-\s*"#{escaped_path}"/

      if @content.match?(pattern)
        @content.gsub!(pattern, '\\1- "' + template_path + '"')
        @ui.info("Enabled #{File.basename(template_path)}")
      elsif @content.include?(template_path)
        @ui.info("#{File.basename(template_path)} already enabled")
      else
        @ui.warning("Could not find #{template_path} in config")
      end
    end

    def ensure_setting_exists(key, default_value, after_key: nil)
      return if @content.match?(/^\s*#?\s*#{Regexp.escape(key)}:/)

      # Setting doesn't exist, need to add it
      if after_key
        pattern = /^(\s*)(#{Regexp.escape(after_key)}:.*)$/
        if @content.match?(pattern)
          formatted = format_value(key, default_value)
          @content.gsub!(pattern, "\\1\\2\n\\1##{key}: #{formatted}")
          @ui.info("Added #{key} placeholder to config")
          return
        end
      end

      @ui.warning("Could not add #{key} to config - please add it manually")
    end
  end
end

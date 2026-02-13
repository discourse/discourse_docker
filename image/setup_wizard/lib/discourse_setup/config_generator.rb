# frozen_string_literal: true

require "yaml"
require "fileutils"

module DiscourseSetup
  class ConfigGenerator
    TEMPLATE_PATH = "samples/standalone.yml"
    CONFIG_PATH = "containers/app.yml"

    SSL_TEMPLATE = "templates/web.ssl.template.yml"
    LETSENCRYPT_TEMPLATE = "templates/web.letsencrypt.ssl.template.yml"

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
      @config = YAML.load_file(@config_path)
      @config["env"] ||= {}
      @config["params"] ||= {}
    end

    def create_from_template
      FileUtils.mkdir_p(File.dirname(@config_path))
      @config = YAML.load_file(@template_path)
      @config["env"] ||= {}
      @config["params"] ||= {}
    end

    def backup_config
      timestamp = Time.now.strftime("%Y-%m-%d-%H%M%S")
      backup_path = "#{@config_path}.#{timestamp}.bak"
      @ui.info("Saving backup to #{File.basename(backup_path)}")
      FileUtils.cp(@config_path, backup_path)
      FileUtils.chmod(0o600, backup_path)
    end

    def read_value(key)
      @config["env"][key]&.to_s || @config["params"][key]&.to_s
    end

    def update_config(settings)
      settings.each do |key, value|
        next if value.nil?

        if key.start_with?("DISCOURSE_", "LETSENCRYPT_", "UNICORN_")
          @config["env"][key] = value
        else
          @config["params"][key] = value
        end
      end
    end

    def remove_keys(*keys)
      keys.each do |key|
        @config["env"].delete(key)
        @config["params"].delete(key)
      end
    end

    def enable_ssl
      @config["templates"] ||= []

      [SSL_TEMPLATE, LETSENCRYPT_TEMPLATE].each do |template|
        unless @config["templates"].include?(template)
          @config["templates"] << template
          @ui.info("Enabled #{File.basename(template)}")
        end
      end
      @config["env"]["ENABLE_LETSENCRYPT"] = 1
    end

    def save
      yaml = format_yaml(@config.to_yaml)
      File.write(@config_path, yaml)
      FileUtils.chmod(0o600, @config_path)
      @ui.success("Configuration saved to #{CONFIG_PATH}")
    end

    private

    def format_yaml(yaml)
      IO.popen(["yq", ".", "--indent", "2", "--no-doc"], "r+") do |io|
        io.write(yaml)
        io.close_write
        io.read
      end
    end
  end
end

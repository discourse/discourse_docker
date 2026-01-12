# frozen_string_literal: true

require "bundler/setup"

require_relative "lib/discourse_setup/cli"
require_relative "lib/discourse_setup/ui"
require_relative "lib/discourse_setup/system_checks"
require_relative "lib/discourse_setup/network_checks"
require_relative "lib/discourse_setup/resource_scaler"
require_relative "lib/discourse_setup/config_generator"
require_relative "lib/discourse_setup/prompts"
require_relative "lib/discourse_setup/launcher"

module DiscourseSetup
  class Wizard
    # Base directory is mounted from host at /discourse_docker
    BASE_DIR = ENV.fetch("DISCOURSE_DOCKER_DIR", "/discourse_docker")

    def initialize(args = ARGV)
      @cli = CLI.new(args)
      @ui = UI.new(debug: @cli.debug)
    end

    TOTAL_STEPS = 5

    def run
      print_banner
      run_system_checks
      setup_config
      collect_user_config
      apply_resource_scaling
      validate_network
      save_config
      print_success
      rebuild_container
    rescue SystemChecks::CheckError => e
      @ui.puts
      @ui.error(e.message)
      exit 1
    rescue NetworkChecks::NetworkError => e
      @ui.puts
      @ui.error(e.message)
      exit 1
    rescue Interrupt
      @ui.puts
      @ui.puts
      @ui.warning("Setup cancelled by user.")
      exit 130
    rescue StandardError => e
      @ui.puts
      @ui.error("Unexpected error: #{e.message}")
      @ui.debug(e.backtrace.join("\n")) if @cli.debug
      exit 1
    end

    private

    def print_banner
      @ui.banner
      @ui.info("This wizard will help you configure your Discourse installation.")
      @ui.info("Press Ctrl+C at any time to cancel.")
    end

    def run_system_checks
      @ui.section("System Checks")
      @ui.step(1, TOTAL_STEPS, "Verifying system requirements")

      @system_checks = SystemChecks.new(ui: @ui, base_dir: BASE_DIR)

      @ui.spin("Checking root privileges...") { @system_checks.check_root }
      @ui.success("Running as root")

      @ui.spin("Checking Docker...") { @system_checks.check_docker }
      @ui.success("Docker is available")

      @ui.spin("Checking memory and disk...") { @system_checks.check_disk_and_memory }
      @ui.success("Memory: #{@system_checks.available_memory_gb}GB, CPU: #{@system_checks.available_cpu_cores} cores")

      # Prompt for swap creation outside spinner (interactive)
      @system_checks.prompt_swap_creation
    end

    def setup_config
      @ui.section("Configuration")
      @ui.step(2, TOTAL_STEPS, "Preparing configuration")

      @config = ConfigGenerator.new(base_dir: BASE_DIR, ui: @ui)

      if @config.config_exists?
        @ui.info("Found existing configuration - reconfiguring...")
        @launcher = Launcher.new(base_dir: BASE_DIR, ui: @ui, debug: @cli.debug)
        @launcher.stop_existing
      else
        @system_checks.check_ports(skip: @cli.skip_connection_test)
        @ui.info("Creating new configuration...")
      end

      @config.load_or_create_config
    end

    def collect_user_config
      @ui.section("Site Settings")
      @ui.step(3, TOTAL_STEPS, "Enter your site details")

      @prompts = Prompts.new(config_generator: @config, ui: @ui)
      @user_values = @prompts.collect_all
    end

    def apply_resource_scaling
      scaler = ResourceScaler.new(
        memory_gb: @system_checks.available_memory_gb,
        cpu_cores: @system_checks.available_cpu_cores,
        ui: @ui
      )

      @scaling_params = {}
      scaler.apply_scaling(@scaling_params)
    end

    def validate_network
      @ui.section("Network Validation")
      @ui.step(4, TOTAL_STEPS, "Verifying domain configuration")

      if @cli.skip_connection_test
        @ui.info("Skipping connection test (--skip-connection-test)")
        return
      end

      network = NetworkChecks.new(ui: @ui, skip: @cli.skip_connection_test, debug: @cli.debug)
      network.check_hostname(@user_values[:hostname])
    end

    def save_config
      @ui.section("Saving Configuration")
      @ui.step(5, TOTAL_STEPS, "Writing configuration file")

      @ui.spin("Applying settings...") do
        # Apply core user settings
        @config.update_config(
          "DISCOURSE_HOSTNAME" => @user_values[:hostname],
          "DISCOURSE_DEVELOPER_EMAILS" => @user_values[:developer_emails]
        )

        # Apply SMTP settings only if configured, otherwise remove placeholders
        if @user_values[:smtp_enabled]
          @config.update_config(
            "DISCOURSE_SMTP_ADDRESS" => @user_values[:smtp_address],
            "DISCOURSE_SMTP_PORT" => @user_values[:smtp_port],
            "DISCOURSE_SMTP_USER_NAME" => @user_values[:smtp_user_name],
            "DISCOURSE_SMTP_PASSWORD" => @user_values[:smtp_password],
            "DISCOURSE_NOTIFICATION_EMAIL" => @user_values[:notification_email],
            "DISCOURSE_SMTP_DOMAIN" => @user_values[:smtp_domain]
          )
        else
          @config.remove_keys(
            "DISCOURSE_SMTP_ADDRESS",
            "DISCOURSE_SMTP_PORT",
            "DISCOURSE_SMTP_USER_NAME",
            "DISCOURSE_SMTP_PASSWORD",
            "DISCOURSE_NOTIFICATION_EMAIL",
            "DISCOURSE_SMTP_DOMAIN"
          )
          @config.update_config("DISCOURSE_SKIP_EMAIL_SETUP" => "1")
        end

        # Apply MaxMind settings if provided
        if @user_values[:maxmind_account_id] && !@user_values[:maxmind_account_id].empty?
          @config.update_config(
            "DISCOURSE_MAXMIND_ACCOUNT_ID" => @user_values[:maxmind_account_id],
            "DISCOURSE_MAXMIND_LICENSE_KEY" => @user_values[:maxmind_license_key]
          )
        end

        # Apply resource scaling
        @config.update_config(
          "db_shared_buffers" => @scaling_params.dig("params", "db_shared_buffers"),
          "UNICORN_WORKERS" => @scaling_params.dig("env", "UNICORN_WORKERS")
        )

        # Always enable Let's Encrypt SSL
        @config.enable_ssl(@user_values[:letsencrypt_email])

        @config.save
      end

      @ui.success("Configuration saved to containers/app.yml")
    end

    def print_success
      @ui.puts
      @ui.divider
      @ui.puts
      @ui.success("Discourse has been configured successfully!")
      @ui.puts
    end

    def rebuild_container
      @launcher ||= Launcher.new(base_dir: BASE_DIR, ui: @ui, debug: @cli.debug)
      @launcher.rebuild(skip: @cli.skip_rebuild)
    end
  end
end

# Run the wizard
DiscourseSetup::Wizard.new.run if $PROGRAM_NAME == __FILE__

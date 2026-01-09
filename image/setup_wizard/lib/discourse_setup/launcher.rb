# frozen_string_literal: true

require "docker-api"

module DiscourseSetup
  class Launcher
    APP_NAME = "app"
    REBUILD_SIGNAL_FILE = "/discourse_docker/.wizard_rebuild_needed"

    def initialize(base_dir:, ui:, debug: false)
      @base_dir = base_dir
      @ui = ui
      @debug = debug

      Docker.url = "unix:///var/run/docker.sock"
    end

    def stop_existing
      return unless container_exists?

      if @debug
        @ui.info("DEBUG MODE: Not stopping the container.")
        return
      end

      @ui.info("Stopping existing container in 5 seconds (Ctrl+C to cancel)...")
      sleep 5

      stop_container
    end

    def rebuild(skip: false)
      if skip
        @ui.success("Updates successful. --skip-rebuild requested.")
        return true
      end

      # Signal to the wrapper script that a rebuild is needed
      # The actual rebuild runs on the host, not in the container
      signal_rebuild_needed

      @ui.success("Configuration complete!")
      @ui.info("The wrapper script will now rebuild Discourse...")

      true
    end

    private

    def container_exists?
      Docker::Container.all(all: true).any? { |c| c.info["Names"].include?("/#{APP_NAME}") }
    rescue Docker::Error::DockerError
      false
    end

    def stop_container
      container = Docker::Container.all(all: true).find { |c| c.info["Names"].include?("/#{APP_NAME}") }
      return unless container

      @ui.info("Stopping container #{APP_NAME}...")
      container.stop(timeout: 600)
      @ui.success("Container stopped.")
    rescue Docker::Error::DockerError => e
      @ui.warning("Could not stop container: #{e.message}")
    end

    def signal_rebuild_needed
      # Write a signal file that the wrapper script checks
      File.write(REBUILD_SIGNAL_FILE, APP_NAME)
    end
  end
end

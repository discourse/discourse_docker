# frozen_string_literal: true

require "docker-api"

module DiscourseSetup
  class SystemChecks
    MIN_MEMORY_GB = 1
    MIN_DISK_KB = 5_000_000  # 5GB in KB
    MIN_SWAP_GB = 2
    SWAP_THRESHOLD_GB = 4

    class CheckError < StandardError; end

    def initialize(ui:, base_dir: "/discourse_docker")
      @ui = ui
      @base_dir = base_dir
    end

    def run_all
      check_root
      check_docker
      check_disk_and_memory
    end

    def check_root
      return if Process.uid.zero?

      raise CheckError, "This script must be run as root. Please sudo or log in as root first."
    end

    def check_docker
      # Use docker-api gem to communicate directly with the Docker socket
      Docker.url = "unix:///var/run/docker.sock"
      Docker.version
      true
    rescue Docker::Error::DockerError, Excon::Error::Socket => e
      raise CheckError, <<~MSG
        Docker not accessible: #{e.message}
        Please ensure Docker is installed and running: https://get.docker.com/
      MSG
    end

    def check_disk_and_memory
      check_memory
      check_disk
    end

    def swap_needed?
      available_memory_gb <= SWAP_THRESHOLD_GB && calculate_swap_gb < MIN_SWAP_GB
    end

    def prompt_swap_creation
      return unless swap_needed?

      @ui.warning(<<~MSG)
        Discourse requires at least #{MIN_SWAP_GB}GB of swap when running with #{SWAP_THRESHOLD_GB}GB of RAM or less.
        This system has #{calculate_swap_gb}GB of swap.

        Without sufficient swap, your site may not work properly.
      MSG

      if @ui.confirm("Create a 2GB swapfile?", default: true)
        signal_swap_creation
      else
        @ui.warning("Proceeding without swap. This may cause issues.")
      end
    end

    def check_ports(skip: false)
      return if skip

      check_port(80)
      check_port(443)
      @ui.success("Ports 80 and 443 are free for use")
    end

    def available_memory_gb
      @available_memory_gb ||= calculate_available_memory
    end

    def available_cpu_cores
      @available_cpu_cores ||= calculate_cpu_cores
    end

    private

    def check_memory
      mem_gb = available_memory_gb

      if mem_gb < MIN_MEMORY_GB
        raise CheckError, <<~MSG
          Discourse requires #{MIN_MEMORY_GB}GB RAM to run. This system has #{mem_gb}GB.

          Your site may not work properly, or future upgrades may not complete successfully.
        MSG
      end
    end

    def signal_swap_creation
      # Signal the host wrapper script to create swap
      # The wizard runs in a container, so swap must be created on the host
      signal_file = File.join(@base_dir, ".wizard_swap_needed")
      File.write(signal_file, "2G")
      @ui.info("Swap creation requested. The host script will create the swapfile.")

      # Exit with special code so host can create swap and re-run wizard
      exit 42
    end

    def check_disk
      # Get free disk space in KB for the mounted directory (host filesystem)
      # Use -Pk for POSIX-portable output with 1K blocks
      free_disk_kb = `df -Pk #{@base_dir} 2>/dev/null | tail -n 1 | awk '{print $4}'`.to_i

      return if free_disk_kb >= MIN_DISK_KB

      free_gb = (free_disk_kb / 1_000_000.0).round(1)
      required_gb = (MIN_DISK_KB / 1_000_000.0).round(1)

      raise CheckError, <<~MSG
        Discourse requires at least #{required_gb}GB free disk space. This system has #{free_gb}GB.

        Please free up some space, or expand your disk, before continuing.

        Run `apt-get autoremove && apt-get autoclean` to clean up unused packages
        and `./launcher cleanup` to remove stale Docker containers.
      MSG
    end

    def check_port(port)
      # Check if port is in use using lsof
      output = `lsof -i:#{port} 2>/dev/null | grep LISTEN`.strip

      return if output.empty?

      process_info = `lsof -i tcp:#{port} -s tcp:listen 2>/dev/null`.strip

      raise CheckError, <<~MSG
        Port #{port} appears to already be in use.

        Process using port #{port}:
        #{process_info}

        If you are trying to run Discourse with another web server like Apache or nginx,
        you will need to bind to a different port.

        See https://meta.discourse.org/t/17247

        If you are reconfiguring an already-configured Discourse, use:
          ./launcher stop app
        to stop Discourse before reconfiguring.
      MSG
    end

    def calculate_available_memory
      if macos?
        # macOS memory detection
        mem_bytes = `memory_pressure 2>/dev/null | head -n 1 | awk '{ print $4 }'`.to_i
        mem_bytes / 1024 / 1024 / 1024
      else
        # Linux memory detection
        mem_mb = `free -m --si 2>/dev/null | awk '/Mem:/ {print $2}'`.to_i

        # Some VMs report just under 1GB, allow 990MB+
        if mem_mb >= 990 && mem_mb < 1000
          1
        else
          `free -g --si 2>/dev/null | awk '/Mem:/ {print $2}'`.to_i
        end
      end
    end

    def calculate_swap_gb
      `free -g --si 2>/dev/null | awk '/Swap:/ {print $2}'`.to_i
    end

    def calculate_cpu_cores
      if macos?
        `sysctl hw.ncpu 2>/dev/null | awk '/hw.ncpu:/ {print $2}'`.to_i
      else
        # Get logical CPU count and threads per core
        cpus = `lscpu 2>/dev/null | awk '/^CPU\\(s\\):/ {print $2}'`.to_i
        threads_per_core = `lscpu 2>/dev/null | awk -F: '/Thread\\(s\\) per core/ {gsub(/ /, "", $2); print $2}'`.to_i
        threads_per_core = 1 if threads_per_core.zero?

        cpus * threads_per_core
      end
    end

    def macos?
      RUBY_PLATFORM.include?("darwin")
    end
  end
end

# frozen_string_literal: true

require "socket"
require "timeout"
require "securerandom"

module DiscourseSetup
  class NetworkChecks
    CONNECT_TIMEOUT = 3

    def initialize(ui:, skip: false, debug: false)
      @ui = ui
      @skip = skip
      @debug = debug
    end

    def check_hostname(hostname)
      return :skipped if @skip

      @ui.info("Checking your domain name...")

      result = connect_to_port(hostname, 443)

      case result
      when :success
        @ui.success("Connection to #{hostname} succeeded.")
        :success
      when :no_netcat
        if @ui.confirm("netcat is not installed. Continue without connection check?", default: true)
          :skipped
        else
          raise NetworkError, "Cannot verify connection without netcat. Please install netcat and try again."
        end
      when :failed
        handle_connection_failure(hostname)
      end
    end

    class NetworkError < StandardError; end

    private

    def connect_to_port(host, port)
      # Check if netcat is available
      nc_path = `which nc 2>/dev/null`.strip
      if nc_path.empty?
        debug("netcat not found in PATH")
        return :no_netcat
      end
      debug("Using netcat: #{nc_path}")

      # Check if port is already in use
      port_check = `lsof -i :#{port} 2>/dev/null`.strip
      unless port_check.empty?
        debug("Port #{port} is already in use:")
        debug(port_check)
      end

      # Check DNS resolution
      resolved_ip = `getent hosts #{host} 2>/dev/null`.strip
      if resolved_ip.empty?
        debug("DNS lookup failed for #{host}")
      else
        debug("DNS resolution: #{resolved_ip}")
      end

      # Generate a unique verification string
      verify = SecureRandom.hex(10)
      debug("Verification token: #{verify}")

      # Start a simple HTTP server on the port to receive the test connection
      nc_cmd = "echo -e 'HTTP/1.1 200 OK\n\n#{verify}' | nc -w 4 -l -p #{port}"
      debug("Starting listener: #{nc_cmd}")

      server_pid = spawn(nc_cmd, [:out, :err] => "/dev/null")
      Process.detach(server_pid)
      debug("Listener PID: #{server_pid}")

      # Give the server a moment to start
      sleep 0.5

      # Verify listener is running
      listener_check = `lsof -i :#{port} -P 2>/dev/null | grep LISTEN`.strip
      if listener_check.empty?
        debug("WARNING: Listener does not appear to be running on port #{port}")
      else
        debug("Listener status: #{listener_check}")
      end

      begin
        # Try to connect from the external hostname
        curl_cmd = "curl --proto =http -s #{host}:#{port} --connect-timeout #{CONNECT_TIMEOUT}"
        debug("Testing connection: #{curl_cmd}")

        response = `#{curl_cmd} 2>&1`
        debug("Curl response: '#{response}'")

        if response.include?(verify)
          debug("Verification succeeded!")
          :success
        else
          debug("Verification failed - token not found in response")
          # Clean up the listener if curl didn't reach it
          `curl --proto =http -s localhost:#{port} >/dev/null 2>&1`
          :failed
        end
      rescue StandardError => e
        debug("Exception during connection test: #{e.message}")
        :failed
      ensure
        # Ensure we kill the background nc process
        Process.kill("TERM", server_pid) rescue nil
      end
    end

    def debug(msg)
      @ui.puts("  [DEBUG] #{msg}") if @debug
    end

    def handle_connection_failure(hostname)
      @ui.warning("Port 443 of this computer does not appear to be accessible using hostname: #{hostname}")

      # Check if port 80 works
      if connect_to_port(hostname, 80) == :success
        @ui.puts("")
        @ui.success("A connection to port 80 succeeds!")
        @ui.puts(<<~MSG)
          This suggests that your DNS settings are correct,
          but something is keeping traffic to port 443 from getting to your server.
          Check your networking configuration to see that connections to port 443 are allowed.
        MSG
      else
        @ui.warning("Connection to http://#{hostname} (port 80) also fails.")
        @ui.puts(<<~MSG)

          This suggests that #{hostname} resolves to some IP address that does not reach this
          machine where you are installing Discourse.
        MSG
      end

      @ui.puts(<<~MSG)

        The first thing to do is confirm that #{hostname} resolves to the IP address of this server.
        You usually do this at the same place you purchased the domain.

        If you are sure that the IP address resolves correctly, it could be a firewall issue.
        A web search for "open ports YOUR CLOUD SERVICE" might help.

        This tool is designed only for the most standard installations. If you cannot resolve
        the issue above, you will need to edit containers/app.yml yourself and then type:

            ./launcher rebuild app

      MSG

      raise NetworkError, "DNS verification failed for #{hostname}"
    end
  end
end

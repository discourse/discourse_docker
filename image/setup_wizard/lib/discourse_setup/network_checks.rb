# frozen_string_literal: true

require "socket"
require "timeout"
require "securerandom"

module DiscourseSetup
  class NetworkChecks
    CONNECT_TIMEOUT = 3

    def initialize(ui:, skip: false)
      @ui = ui
      @skip = skip
    end

    def check_hostname(hostname)
      return :skipped if @skip

      # Network checks are unreliable from inside a container, skip for now
      # TODO: Move network checks to run on the host via a mounted script
      @ui.info("Skipping connection test (running inside container)")
      :skipped
    end

    class NetworkError < StandardError; end

    private

    def connect_to_port(host, port)
      # Check if netcat is available
      nc_path = `which nc 2>/dev/null`.strip
      if nc_path.empty?
        return :no_netcat
      end

      # Generate a unique verification string
      verify = SecureRandom.hex(10)

      # Start a simple HTTP server on the port to receive the test connection
      server_pid = spawn(
        "echo -e 'HTTP/1.1 200 OK\n\n#{verify}' | nc -w 4 -l -p #{port} >/dev/null 2>&1",
        [:out, :err] => "/dev/null"
      )
      Process.detach(server_pid)

      # Give the server a moment to start
      sleep 0.5

      begin
        # Try to connect from the external hostname
        response = `curl --proto =http -s #{host}:#{port} --connect-timeout #{CONNECT_TIMEOUT} 2>/dev/null`

        if response.include?(verify)
          :success
        else
          # Clean up the listener if curl didn't reach it
          `curl --proto =http -s localhost:#{port} >/dev/null 2>&1`
          :failed
        end
      rescue StandardError
        :failed
      ensure
        # Ensure we kill the background nc process
        Process.kill("TERM", server_pid) rescue nil
      end
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

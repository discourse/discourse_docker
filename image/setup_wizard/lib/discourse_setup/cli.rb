# frozen_string_literal: true

module DiscourseSetup
  class CLI
    attr_reader :debug, :skip_rebuild, :skip_connection_test

    def initialize(args = ARGV)
      @debug = false
      @skip_rebuild = false
      @skip_connection_test = false

      parse(args)
    end

    def parse(args)
      args.each do |arg|
        case arg
        when "--debug"
          @debug = true
          @skip_rebuild = true
        when "--skip-rebuild"
          @skip_rebuild = true
        when "--skip-connection-test"
          @skip_connection_test = true
        when "--help", "-h"
          print_help
          exit 0
        end
      end
    end

    def print_help
      puts <<~HELP
        Discourse Setup Wizard

        Usage: wizard.rb [OPTIONS]

        Options:
          --debug                 Enable debug mode (implies --skip-rebuild)
          --skip-rebuild          Skip the rebuild step after configuration
          --skip-connection-test  Skip DNS/port connectivity tests
          --help, -h              Show this help message

      HELP
    end
  end
end

# frozen_string_literal: true

require_relative "tui_components"

module DiscourseSetup
  class UI
    # ANSI color codes (Catppuccin Mocha-inspired)
    COLORS = {
      success: "\e[38;2;166;227;161m",   # Green #a6e3a1
      error: "\e[38;2;243;139;168m",     # Red #f38ba8
      warning: "\e[38;2;249;226;175m",   # Yellow #f9e2af
      info: "\e[38;2;137;180;250m",      # Blue #89b4fa
      muted: "\e[38;2;108;112;134m",     # Gray #6c7086
      accent: "\e[38;2;203;166;247m",    # Mauve #cba6f7
      text: "\e[38;2;205;214;244m",      # Text #cdd6f4
      subtext: "\e[38;2;166;173;200m"    # Subtext #a6adc8
    }.freeze

    RESET = "\e[0m"
    BOLD = "\e[1m"

    BANNER = <<~'BANNER'
       ___  _
      |   \(_)___ __ ___ _  _ _ _ ___ ___
      | |) | (_-</ _/ _ \ || | '_(_-</ -_)
      |___/|_/__/\__\___/\_,_|_| /__/\___|
                             Setup Wizard
    BANNER

    def initialize(debug: false)
      @debug = debug
    end

    def puts(message = "")
      Kernel.puts(message)
    end

    def print(message)
      Kernel.print(message)
    end

    def success(message)
      styled_puts(message, :success, prefix: "✓")
    end

    def error(message)
      styled_puts(message, :error, prefix: "✗")
    end

    def warning(message)
      styled_puts(message, :warning, prefix: "⚠")
    end

    def info(message)
      styled_puts(message, :info, prefix: "→")
    end

    def debug(message)
      return unless @debug

      styled_puts(message, :muted, prefix: "⋯")
    end

    def banner
      puts
      puts "#{COLORS[:accent]}#{BOLD}#{BANNER}#{RESET}"
      puts
    end

    def section(title)
      puts
      puts "#{COLORS[:subtext]}#{BOLD}── #{title} ──#{RESET}"
      puts
    end

    def confirm(prompt, default: true)
      TuiComponents::ConfirmDialog.new(prompt, default: default).run
    end

    def spin(message, &block)
      TuiComponents::Spinner.new(message).run(&block)
    end

    def box(content, title: nil, color: :info)
      color_code = COLORS[color] || COLORS[:info]

      lines = content.split("\n")
      max_width = lines.map(&:length).max || 0
      max_width = [max_width, 40].max # Minimum width

      # Box drawing characters
      top = "#{color_code}╭#{"─" * (max_width + 4)}╮#{RESET}"
      bottom = "#{color_code}╰#{"─" * (max_width + 4)}╯#{RESET}"

      if title
        puts "#{color_code}#{BOLD} #{title} #{RESET}"
      end

      puts top
      lines.each do |line|
        puts "#{color_code}│#{RESET}  #{line.ljust(max_width)}  #{color_code}│#{RESET}"
      end
      puts bottom
    end

    def summary_box(items)
      max_key_length = items.keys.map(&:length).max

      lines = items.map do |key, value|
        key_styled = "#{COLORS[:subtext]}#{key.ljust(max_key_length)}#{RESET}"
        value_display = value.to_s.empty? ? "#{COLORS[:muted]}(not set)#{RESET}" : value
        "#{key_styled}  #{value_display}"
      end

      max_width = lines.map { |l| strip_ansi(l).length }.max || 0
      max_width = [max_width, 40].max

      # Box drawing
      top = "#{COLORS[:accent]}╭#{"─" * (max_width + 4)}╮#{RESET}"
      bottom = "#{COLORS[:accent]}╰#{"─" * (max_width + 4)}╯#{RESET}"

      puts
      puts top
      puts "#{COLORS[:accent]}│#{RESET}  #{" " * max_width}  #{COLORS[:accent]}│#{RESET}"
      lines.each do |line|
        padding = max_width - strip_ansi(line).length
        puts "#{COLORS[:accent]}│#{RESET}  #{line}#{" " * padding}  #{COLORS[:accent]}│#{RESET}"
      end
      puts "#{COLORS[:accent]}│#{RESET}  #{" " * max_width}  #{COLORS[:accent]}│#{RESET}"
      puts bottom
      puts
    end

    def step(number, total, description)
      progress = "#{COLORS[:accent]}#{BOLD}[#{number}/#{total}]#{RESET}"
      Kernel.puts "#{progress} #{description}"
    end

    def divider
      puts "#{COLORS[:muted]}#{"─" * 50}#{RESET}"
    end

    private

    def styled_puts(message, color, prefix: nil)
      color_code = COLORS[color] || COLORS[:text]

      if prefix
        styled_prefix = "#{color_code}#{BOLD}#{prefix}#{RESET}"
        Kernel.puts "#{styled_prefix} #{message}"
      else
        Kernel.puts "#{color_code}#{message}#{RESET}"
      end
    end

    def strip_ansi(str)
      str.gsub(/\e\[[0-9;]*m/, "")
    end
  end
end

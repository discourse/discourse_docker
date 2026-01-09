# frozen_string_literal: true

require "gum"
require "glamour"

module DiscourseSetup
  class UI
    # Catppuccin Mocha-inspired colors
    COLORS = {
      success: "#a6e3a1",   # Green
      error: "#f38ba8",     # Red
      warning: "#f9e2af",   # Yellow
      info: "#89b4fa",      # Blue
      muted: "#6c7086",     # Gray
      accent: "#cba6f7",    # Mauve
      text: "#cdd6f4",      # Text
      subtext: "#a6adc8"    # Subtext
    }.freeze

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
      puts Gum.style(
        BANNER,
        foreground: COLORS[:accent],
        bold: true
      )
      puts
    end

    def header(title)
      puts
      puts Gum.style(
        " #{title} ",
        foreground: "#1e1e2e",
        background: COLORS[:accent],
        bold: true,
        padding: "0 2"
      )
      puts
    end

    def section(title)
      puts
      puts Gum.style(
        "── #{title} ──",
        foreground: COLORS[:subtext],
        bold: true
      )
      puts
    end

    def confirm(prompt, default: true)
      puts
      Gum.confirm(prompt, default: default, affirmative: "Yes", negative: "No")
    end

    def spin(message, &block)
      result = nil
      Gum.spin(message, spinner: :dot) { result = block.call }
      result
    end

    def box(content, title: nil, color: :info)
      border_color = COLORS[color] || COLORS[:info]

      styled = Gum.style(
        content,
        border: :rounded,
        padding: "1 2",
        border_foreground: border_color
      )

      if title
        title_styled = Gum.style(" #{title} ", foreground: border_color, bold: true)
        puts title_styled
      end

      puts styled
    end

    def summary_box(items)
      max_key_length = items.keys.map(&:length).max

      lines = items.map do |key, value|
        key_styled = Gum.style(key.ljust(max_key_length), foreground: COLORS[:subtext])
        value_display = value.to_s.empty? ? Gum.style("(not set)", foreground: COLORS[:muted]) : value
        "#{key_styled}  #{value_display}"
      end

      puts
      puts Gum.style(
        lines.join("\n"),
        border: :rounded,
        padding: "1 2",
        border_foreground: COLORS[:accent]
      )
      puts
    end

    def step(number, total, description)
      progress = Gum.style("[#{number}/#{total}]", foreground: COLORS[:accent], bold: true)
      Kernel.puts "#{progress} #{description}"
    end

    def markdown(text)
      puts Glamour.render(text, style: "dark", width: 80)
    end

    def divider
      puts Gum.style("─" * 50, foreground: COLORS[:muted])
    end

    private

    def styled_puts(message, color, prefix: nil)
      color_code = COLORS[color] || COLORS[:text]

      if prefix
        styled_prefix = Gum.style(prefix, foreground: color_code, bold: true)
        Kernel.puts "#{styled_prefix} #{message}"
      else
        Kernel.puts Gum.style(message, foreground: color_code)
      end
    end
  end
end

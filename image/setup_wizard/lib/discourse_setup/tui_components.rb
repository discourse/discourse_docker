# frozen_string_literal: true

require "ratatui_ruby"

module DiscourseSetup
  module TuiComponents
    Style = RatatuiRuby::Style::Style
    Span = RatatuiRuby::Text::Span
    Line = RatatuiRuby::Text::Line
    Paragraph = RatatuiRuby::Widgets::Paragraph
    List = RatatuiRuby::Widgets::List
    ListItem = RatatuiRuby::Widgets::ListItem

    # Text input component using Ratatui inline viewport
    class TextInput
      CURSOR = "▌"

      def initialize(placeholder:, value: "", header: "", password: false)
        @placeholder = placeholder
        @value = value
        @header = header
        @password = password
      end

      def run
        unless @header.empty?
          puts
          puts @header
        end

        result = RatatuiRuby.run(viewport: :inline, height: 1) do |tui|
          loop do
            tui.draw do |frame|
              display = @password ? "*" * @value.length : @value
              text = if display.empty?
                Line.new(spans: [
                  Span.new(content: @placeholder).with(style: Style.new.with(fg: :dark_gray)),
                  Span.new(content: CURSOR)
                ])
              else
                Line.new(spans: [
                  Span.new(content: display),
                  Span.new(content: CURSOR)
                ])
              end

              widget = Paragraph.new(text: text)
              frame.render_widget(widget, frame.area)
            end

            event = tui.poll_event
            raise Interrupt if event.ctrl_c?

            if event.enter?
              break @value
            elsif event.backspace?
              @value = @value.chop
            elsif event.key?
              char = event.to_s
              @value += char if char.length == 1 && char.match?(/[[:print:]]/)
            end
          end
        end

        puts
        result
      end
    end

    # Confirm dialog with Yes/No selection
    class ConfirmDialog
      def initialize(prompt, default: true)
        @prompt = prompt
        @selected = default ? 0 : 1 # 0 = Yes, 1 = No
      end

      def run
        puts
        puts @prompt

        result = RatatuiRuby.run(viewport: :inline, height: 1) do |tui|
          loop do
            tui.draw do |frame|
              yes_span = if @selected == 0
                Span.new(content: "▸ Yes").with(style: Style.new.with(fg: :green, modifiers: [:bold]))
              else
                Span.new(content: "  Yes")
              end

              no_span = if @selected == 1
                Span.new(content: "▸ No").with(style: Style.new.with(fg: :red, modifiers: [:bold]))
              else
                Span.new(content: "  No")
              end

              line = Line.new(spans: [yes_span, Span.new(content: "    "), no_span])
              widget = Paragraph.new(text: line)
              frame.render_widget(widget, frame.area)
            end

            event = tui.poll_event
            raise Interrupt if event.ctrl_c?

            if event.enter?
              break @selected == 0
            elsif event.left? || event.right? || event.tab?
              @selected = (@selected + 1) % 2
            elsif event.h?
              @selected = 0
            elsif event.l?
              @selected = 1
            elsif event.y?
              break true
            elsif event.n?
              break false
            end
          end
        end

        puts
        result
      end
    end

    # Selection menu from multiple items
    class ChooseMenu
      def initialize(items, header: nil)
        @items = items
        @header = header
        @selected = 0
      end

      def run
        puts @header if @header

        result = RatatuiRuby.run(viewport: :inline, height: @items.length) do |tui|
          loop do
            tui.draw do |frame|
              list_items = @items.map { |item| ListItem.new(content: item) }
              widget = List.new(items: list_items)
                .with(
                  highlight_symbol: "▸ ",
                  highlight_style: Style.new.with(fg: :magenta, modifiers: [:bold])
                )

              state = RatatuiRuby::ListState.new
              state.select(@selected)
              frame.render_stateful_widget(widget, frame.area, state)
            end

            event = tui.poll_event
            raise Interrupt if event.ctrl_c?

            if event.enter?
              break @items[@selected]
            elsif event.up? || event.k?
              @selected = (@selected - 1) % @items.length
            elsif event.down? || event.j?
              @selected = (@selected + 1) % @items.length
            end
          end
        end

        puts
        result
      end
    end

    # Spinner with animated loading indicator
    class Spinner
      FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
      FRAME_DELAY = 0.08

      def initialize(message)
        @message = message
      end

      def run(&block)
        result = nil
        error = nil
        done = false

        worker = Thread.new do
          result = block.call
        rescue => e
          error = e
        ensure
          done = true
        end

        frame_idx = 0
        last_frame_time = Time.now

        RatatuiRuby.run(viewport: :inline, height: 1) do |tui|
          until done
            now = Time.now
            if now - last_frame_time >= FRAME_DELAY
              frame_idx += 1
              last_frame_time = now
            end

            tui.draw do |frame|
              spinner_frame = FRAMES[frame_idx % FRAMES.length]
              line = Line.new(spans: [
                Span.new(content: spinner_frame).with(style: Style.new.with(fg: :magenta)),
                Span.new(content: " #{@message}")
              ])
              widget = Paragraph.new(text: line)
              frame.render_widget(widget, frame.area)
            end

            # Short timeout to stay responsive when work completes
            event = tui.poll_event(timeout: 0.01)
            raise Interrupt if event&.ctrl_c?
          end

          # Clear the line before exiting so next output starts clean
          tui.draw do |frame|
            widget = Paragraph.new(text: Line.new(spans: []))
            frame.render_widget(widget, frame.area)
          end
        end

        # Clear any remnants and move to fresh line
        print "\r\e[K"

        worker.join
        raise error if error

        result
      end
    end
  end
end

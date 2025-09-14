# common/status_line.rb
# Provides terminal status line functionality with improved maintainability
# Uses ANSI sequences with better organization and error handling

module Common
  module StatusLine
    def self.included(base)
      base.class_eval do
        # Prepend a module to hook into initialize
        prepend Module.new {
          def initialize(...)
            super(...)
            initialize_status_line if respond_to?(:initialize_status_line, true)
          end
        }
      end

      # Register cleanup handler
      at_exit do
        StatusLine.cleanup_terminal
      end
    end

    def self.cleanup_terminal
      begin
        if $stdout.tty?
          rows = get_terminal_rows
          if rows
            # Reset scrolling region to full screen
            print "\033[1;#{rows}r"
            # Clear the status line
            print "\033[#{rows};1H\033[K"
            $stdout.flush
          end
        end
      rescue => e
        # Silently ignore cleanup errors
      end
    end

    def self.get_terminal_rows
      rows, _ = IO.popen("stty size", "r") { |io| io.read.split.map(&:to_i) }
      rows
    rescue => e
      nil
    end

    def initialize_status_line
      return unless $stdout.tty?

      begin
        @terminal_rows, @terminal_columns = get_terminal_size
        @program_name = File.basename($0, ".*")
        @status_line_mutex = Mutex.new # Thread safety for status updates

        if @terminal_rows && @terminal_columns
          setup_terminal_scrolling
          clear_screen
          display_initial_status
        end
      rescue => e
        # If terminal operations fail, continue without status line
        disable_status_line
      end
    end

    def status_line(text)
      return unless status_line_enabled?

      @status_line_mutex.synchronize do
        begin
          update_status_display(text)
        rescue => e
          # Silently ignore status line update errors
        end
      end
    end

    def restore_terminal
      return unless status_line_enabled?

      begin
        clear_status_line
        reset_scrolling_region
      rescue => e
        # Silently ignore terminal restore errors
      end
    end

    # Handle terminal resize gracefully
    def handle_terminal_resize
      return unless status_line_enabled?

      begin
        old_rows, old_cols = @terminal_rows, @terminal_columns
        @terminal_rows, @terminal_columns = get_terminal_size

        if @terminal_rows != old_rows || @terminal_columns != old_cols
          setup_terminal_scrolling
          # Re-display current status with new dimensions
          status_line(@last_status_text) if @last_status_text
        end
      rescue => e
        # Ignore resize errors
      end
    end

    private

    def status_line_enabled?
      @terminal_rows && @terminal_columns && $stdout.tty?
    end

    def disable_status_line
      @terminal_rows = nil
      @terminal_columns = nil
    end

    def setup_terminal_scrolling
      # Set up scrolling region (leave bottom line for status)
      print "\033[1;#{@terminal_rows - 1}r"
      $stdout.flush
    end

    def clear_screen
      # Clear screen and position cursor at top
      print "\033[2J\033[H"
      $stdout.flush
    end

    def display_initial_status
      status_line('started')
    end

    def update_status_display(text)
      # Store current status for resize handling
      @last_status_text = text

      # Build the complete status line text
      full_text = build_status_text(text)

      # Save cursor position, move to status line, update, restore cursor
      print cursor_save_sequence
      print move_to_status_line_sequence
      print clear_line_sequence
      print full_text
      print cursor_restore_sequence
      $stdout.flush
    end

    def build_status_text(text)
      # Build the full status line
      parts = []
      parts << @program_name
      parts << @status_line_prefix if @status_line_prefix
      parts << text

      full_text = parts.join(": ")

      # Truncate if too long, preserving program name
      if full_text.length >= @terminal_columns
        truncate_status_text(text)
      else
        pad_status_text(full_text)
      end
    end

    def truncate_status_text(text)
      available_space = @terminal_columns - @program_name.length - 3 # -3 for ": "

      if available_space > 10 # Ensure reasonable space for status
        truncated_text = text[0...available_space - 1] + "…"
        full_text = "#{@program_name}: #{truncated_text}"
      else
        # Terminal too narrow, just show program name
        full_text = @program_name[0...@terminal_columns - 1]
      end

      pad_status_text(full_text)
    end

    def pad_status_text(text)
      # Pad to full width to clear any previous longer text
      text.ljust(@terminal_columns - 1)
    end

    def clear_status_line
      return unless @terminal_rows

      print "\033[#{@terminal_rows};1H\033[K"
      $stdout.flush
    end

    def reset_scrolling_region
      return unless @terminal_rows

      print "\033[1;#{@terminal_rows}r"
      $stdout.flush
    end

    # ANSI escape sequence helpers for better readability
    def cursor_save_sequence
      "\033[s"
    end

    def cursor_restore_sequence
      "\033[u"
    end

    def move_to_status_line_sequence
      "\033[#{@terminal_rows};1H"
    end

    def clear_line_sequence
      "\033[2K"
    end

    def get_terminal_size
      rows, columns = IO.popen("stty size", "r") { |io| io.read.split.map(&:to_i) }
      [rows, columns]
    rescue => e
      [nil, nil]
    end
  end
end

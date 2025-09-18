#!/usr/bin/env ruby
# network_animation.rb
#
# Animated visualization of SmartMessage network traffic using Gosu
# Shows messages flowing between department nodes

require 'gosu'
require 'json'
require 'time'

class Department
  attr_reader :name, :x, :y, :color
  attr_accessor :message_count, :last_activity

  def initialize(name, x, y)
    @name = name
    @x = x
    @y = y
    @radius = 30
    @color = Gosu::Color.new(255, 100, 150, 255)
    @message_count = 0
    @last_activity = 0
  end

  def draw(font, window)
    # Draw department circle
    activity_fade = [(Time.now.to_f - @last_activity) * 2, 1.0].min
    intensity = 255 - (activity_fade * 100).to_i
    active_color = Gosu::Color.new(intensity, 100, 150, 255)

    draw_circle(window, @x, @y, @radius, active_color)

    # Draw department name
    text_width = font.text_width(@name[0..15])
    font.draw_text(@name[0..15], @x - text_width/2, @y + @radius + 5,
                   10, 1, 1, Gosu::Color::WHITE)

    # Draw message count
    count_text = @message_count.to_s
    count_width = font.text_width(count_text)
    font.draw_text(count_text, @x - count_width/2, @y - 10,
                   11, 1, 1, Gosu::Color::YELLOW)
  end

  private

  def draw_circle(window, x, y, radius, color)
    segments = 32
    angle_step = 2 * Math::PI / segments

    segments.times do |i|
      angle1 = i * angle_step
      angle2 = (i + 1) * angle_step

      x1 = x + radius * Math.cos(angle1)
      y1 = y + radius * Math.sin(angle1)
      x2 = x + radius * Math.cos(angle2)
      y2 = y + radius * Math.sin(angle2)

      window.draw_triangle(
        x, y, color,
        x1, y1, color,
        x2, y2, color,
        5
      )
    end
  end
end

class Message
  attr_reader :from_dept, :to_dept, :message_class, :start_time
  attr_accessor :progress

  def initialize(from_dept, to_dept, message_class)
    @from_dept = from_dept
    @to_dept = to_dept
    @message_class = message_class
    @start_time = Time.now.to_f
    @progress = 0.0
    @is_broadcast = to_dept.nil?
  end

  def update(speed)
    # Broadcasts animate slower for better visibility
    adjusted_speed = @is_broadcast ? speed * 0.5 : speed
    @progress += adjusted_speed
    @progress >= 1.0
  end

  def broadcast?
    @is_broadcast
  end

  def draw(window, departments, font)
    if @is_broadcast
      # Calculate center of the department circle
      center_x = window.width / 2
      center_y = window.height / 2 - 50

      # Draw connecting line from department to center (stays visible throughout)
      line_alpha = (255 * (1.0 - @progress * 0.5)).to_i  # Slowly fades
      line_color = Gosu::Color.new(line_alpha, 255, 200, 100)

      # Draw thick line with glow
      5.times do |thickness|
        thick_alpha = [line_alpha - thickness * 20, 0].max
        thick_color = Gosu::Color.new(thick_alpha, 255, 200, 100)
        window.draw_line(
          @from_dept.x, @from_dept.y, thick_color,
          center_x, center_y, thick_color,
          10 - thickness
        )
      end

      # Highlight the broadcasting department
      pulse = Math.sin(@progress * Math::PI * 4) * 0.5 + 0.5
      highlight_alpha = (255 * pulse * (1.0 - @progress * 0.7)).to_i
      highlight_color = Gosu::Color.new(highlight_alpha, 255, 255, 100)
      draw_circle(window, @from_dept.x, @from_dept.y, 40 + pulse * 10, highlight_color)
      draw_circle(window, @from_dept.x, @from_dept.y, 35 + pulse * 8, highlight_color)

      # Draw broadcast ripples emanating from CENTER outward
      num_waves = 8
      num_waves.times do |wave|
        # Each wave has an offset in the animation
        wave_progress = (@progress + wave * 0.1) % 1.0

        # Skip if wave hasn't started yet
        next if wave_progress <= (wave * 0.1)

        # Ripples expand outward from CENTER of circle
        ripple_radius = wave_progress * 400

        # Wave amplitude with pulsing
        amplitude = Math.sin(wave_progress * Math::PI) * 0.5 + 0.5

        # Alpha fades as ripple expands
        base_alpha = 255 * (1.0 - wave_progress * 0.7) * amplitude

        # Draw concentric ripples from CENTER
        5.times do |ring|
          ring_radius = ripple_radius + (ring * 20)
          ring_alpha = [base_alpha - (ring * 35), 40].max.to_i

          # Vibrant broadcast colors matching the line color
          color = case ring
          when 0
            Gosu::Color.new(ring_alpha, 100, 255, 255)  # Bright cyan
          when 1
            Gosu::Color.new(ring_alpha * 0.9, 50, 220, 255)  # Bright blue
          when 2
            Gosu::Color.new(ring_alpha * 0.8, 0, 200, 255)  # Deep blue
          when 3
            Gosu::Color.new(ring_alpha * 0.6, 0, 150, 220)  # Navy blue
          else
            Gosu::Color.new(ring_alpha * 0.4, 0, 100, 180)  # Dark blue
          end

          # Draw expanding rings from the CENTER
          3.times do |thickness|
            draw_expanding_circle(window, center_x, center_y, ring_radius + thickness, color)
          end
        end

        # Add bright core at center for each wave start
        if wave_progress < 0.2
          core_alpha = (255 * (1.0 - wave_progress / 0.2)).to_i
          core_color = Gosu::Color.new(core_alpha, 255, 255, 255)
          draw_circle(window, center_x, center_y, 25, core_color)

          # Extra bright inner core
          inner_alpha = (200 * (1.0 - wave_progress / 0.2)).to_i
          inner_color = Gosu::Color.new(inner_alpha, 200, 255, 255)
          draw_circle(window, center_x, center_y, 15, inner_color)
        end
      end
    else
      # Draw point-to-point message
      return unless @to_dept

      # Calculate position along path
      x = @from_dept.x + (@to_dept.x - @from_dept.x) * @progress
      y = @from_dept.y + (@to_dept.y - @from_dept.y) * @progress

      # Draw much larger message particle
      color = message_color

      # Add outer glow layers for more prominence
      glow_color1 = Gosu::Color.new(30, color.red, color.green, color.blue)
      glow_color2 = Gosu::Color.new(60, color.red, color.green, color.blue)
      glow_color3 = Gosu::Color.new(100, color.red, color.green, color.blue)

      draw_circle(window, x, y, 25, glow_color1)
      draw_circle(window, x, y, 20, glow_color2)
      draw_circle(window, x, y, 15, glow_color3)
      draw_circle(window, x, y, 12, color)

      # Draw much longer message trail with more particles
      trail_length = 20  # Even more trail particles
      (1..trail_length).each do |i|
        trail_progress = @progress - (i * 0.012)  # Even closer spacing
        next if trail_progress < 0

        trail_x = @from_dept.x + (@to_dept.x - @from_dept.x) * trail_progress
        trail_y = @from_dept.y + (@to_dept.y - @from_dept.y) * trail_progress

        # Gradual size reduction and alpha fade
        trail_size = 15 - (i * 0.6)  # Start larger, gradually smaller
        trail_alpha = 255 - (i * 12)  # More gradual fade
        trail_color = Gosu::Color.new(trail_alpha, color.red, color.green, color.blue)

        draw_circle(window, trail_x, trail_y, trail_size, trail_color)
      end
    end
  end

  private

  def message_color
    case @message_class
    when /Emergency/, /Fire/, /Alarm/
      Gosu::Color.new(255, 255, 100, 100)  # Red
    when /Police/
      Gosu::Color.new(255, 100, 100, 255)  # Blue
    when /Health/
      Gosu::Color.new(255, 100, 255, 100)  # Green
    else
      Gosu::Color.new(255, 200, 200, 200)  # Gray
    end
  end

  def draw_circle(window, x, y, radius, color)
    segments = 16
    angle_step = 2 * Math::PI / segments

    segments.times do |i|
      angle1 = i * angle_step
      angle2 = (i + 1) * angle_step

      x1 = x + radius * Math.cos(angle1)
      y1 = y + radius * Math.sin(angle1)
      x2 = x + radius * Math.cos(angle2)
      y2 = y + radius * Math.sin(angle2)

      window.draw_triangle(
        x, y, color,
        x1, y1, color,
        x2, y2, color,
        8
      )
    end
  end

  def draw_expanding_circle(window, x, y, radius, color)
    segments = 32
    angle_step = 2 * Math::PI / segments

    segments.times do |i|
      angle1 = i * angle_step
      angle2 = (i + 1) * angle_step

      x1 = x + radius * Math.cos(angle1)
      y1 = y + radius * Math.sin(angle1)
      x2 = x + radius * Math.cos(angle2)
      y2 = y + radius * Math.sin(angle2)

      window.draw_line(x1, y1, color, x2, y2, color, 7)
    end
  end
end

class NetworkAnimationWindow < Gosu::Window
  def initialize(jsonl_path, clock_rate = 1.0)
    # Get screen dimensions - make it square (use 90% of the smaller dimension)
    screen_size = [Gosu.screen_width, Gosu.screen_height].min * 0.9

    super(screen_size.to_i, screen_size.to_i, false)
    self.caption = "SmartMessage Network Traffic Animation"

    @jsonl_path = jsonl_path
    @clock_rate = clock_rate
    @messages_data = []
    @departments = {}
    @active_messages = []
    @current_index = 0
    @last_update = Time.now.to_f
    @paused = false
    @stats = { total: 0, broadcasts: 0, point_to_point: 0 }
    @needs_rearrange = false

    @font = Gosu::Font.new(14)
    @title_font = Gosu::Font.new(20)

    load_messages
    # Don't arrange departments yet - they'll be added dynamically
  end

  def load_messages
    unless File.exist?(@jsonl_path)
      puts "❌ File not found: #{@jsonl_path}"
      exit 1
    end

    File.foreach(@jsonl_path) do |line|
      begin
        data = JSON.parse(line)
        @messages_data << {
          from: data['from'],
          to: data['to'],
          message_class: data['message_class'],
          timestamp: data['timestamp']
        }
      rescue JSON::ParserError
        # Skip invalid lines
      end
    end

    puts "📊 Loaded #{@messages_data.size} messages"
  end

  def arrange_departments
    # Arrange existing departments in a circle
    return if @departments.empty?

    center_x = width / 2
    center_y = height / 2 - 50
    radius = [width, height].min / 3

    dept_names = @departments.keys
    dept_names.each_with_index do |name, i|
      angle = (2 * Math::PI * i) / dept_names.size - Math::PI / 2
      x = center_x + radius * Math.cos(angle)
      y = center_y + radius * Math.sin(angle)

      # Update position of existing department
      dept = @departments[name]
      dept.instance_variable_set(:@x, x)
      dept.instance_variable_set(:@y, y)
    end

    @needs_rearrange = false
  end

  def add_department_if_needed(name)
    return if name.nil? || name == 'broadcast' || name == 'unknown'
    return if @departments.key?(name)

    # Add new department at temporary position
    center_x = width / 2
    center_y = height / 2 - 50

    # Place new department temporarily at center
    @departments[name] = Department.new(name, center_x, center_y)
    @needs_rearrange = true
  end

  def update
    return if @paused

    current_time = Time.now.to_f

    # Rearrange departments if needed (with smooth animation)
    if @needs_rearrange && @departments.size > 0
      arrange_departments
    end

    # Check if any broadcasts are active
    has_active_broadcast = @active_messages.any?(&:broadcast?)

    # Slow down clock rate when broadcasts are active for better visibility
    effective_clock_rate = has_active_broadcast ? @clock_rate * 2.0 : @clock_rate

    # Check if it's time for next message (based on effective clock rate)
    if current_time - @last_update >= effective_clock_rate
      @last_update = current_time

      # Add next message from data
      if @current_index < @messages_data.size
        msg_data = @messages_data[@current_index]

        # Don't add new messages if a broadcast is currently animating
        # This gives broadcasts time to be fully visible
        unless has_active_broadcast
          @current_index += 1

          # Add departments dynamically as they appear in messages
          add_department_if_needed(msg_data[:from])
          add_department_if_needed(msg_data[:to])

          from_dept = @departments[msg_data[:from]]
          to_dept = @departments[msg_data[:to]]

          if from_dept
            from_dept.message_count += 1
            from_dept.last_activity = current_time

            if msg_data[:to].nil? || msg_data[:to] == 'broadcast' || msg_data[:to] == 'unknown'
              # Broadcast message
              @active_messages << Message.new(from_dept, nil, msg_data[:message_class])
              @stats[:broadcasts] += 1
            elsif to_dept
              # Point-to-point message
              @active_messages << Message.new(from_dept, to_dept, msg_data[:message_class])
              to_dept.last_activity = current_time
              @stats[:point_to_point] += 1
            end

            @stats[:total] += 1
          end
        end
      elsif @current_index >= @messages_data.size && @active_messages.empty?
        # Restart animation - keep departments but reset counts
        @current_index = 0
        @departments.each { |_, dept| dept.message_count = 0 }
        @stats = { total: 0, broadcasts: 0, point_to_point: 0 }
      end
    end

    # Update message animations
    message_speed = 0.02 / @clock_rate
    @active_messages.reject! { |msg| msg.update(message_speed) }
  end

  def draw
    # Black background
    draw_quad(
      0, 0, Gosu::Color::BLACK,
      width, 0, Gosu::Color::BLACK,
      width, height, Gosu::Color::BLACK,
      0, height, Gosu::Color::BLACK,
      0
    )

    # Draw title
    title = "SmartMessage Network Traffic"
    title_width = @title_font.text_width(title)
    @title_font.draw_text(title, width/2 - title_width/2, 20,
                          10, 1, 1, Gosu::Color::WHITE)

    # Draw departments
    @departments.each_value do |dept|
      dept.draw(@font, self)
    end

    # Draw active messages
    @active_messages.each do |msg|
      msg.draw(self, @departments, @font)
    end

    # Draw stats
    draw_stats

    # Draw controls
    draw_controls
  end

  def draw_stats
    y = height - 120
    @font.draw_text("Departments: #{@departments.size}", 20, y, 10, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Total: #{@stats[:total]}", 20, y + 20, 10, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Broadcasts: #{@stats[:broadcasts]}", 20, y + 40, 10, 1, 1, Gosu::Color::YELLOW)
    @font.draw_text("Point-to-Point: #{@stats[:point_to_point]}", 20, y + 60, 10, 1, 1, Gosu::Color::CYAN)
    @font.draw_text("Clock Rate: #{@clock_rate}s", 20, y + 80, 10, 1, 1, Gosu::Color::GREEN)
  end

  def draw_controls
    y = height - 100
    x = width - 200
    @font.draw_text("Controls:", x, y, 10, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("SPACE: Pause/Resume", x, y + 20, 10, 1, 1, Gosu::Color::GRAY)
    @font.draw_text("↑/↓: Speed up/down", x, y + 40, 10, 1, 1, Gosu::Color::GRAY)
    @font.draw_text("R: Restart", x, y + 60, 10, 1, 1, Gosu::Color::GRAY)
    @font.draw_text("ESC: Quit", x, y + 80, 10, 1, 1, Gosu::Color::GRAY)

    if @paused
      pause_text = "PAUSED"
      pause_width = @title_font.text_width(pause_text)
      @title_font.draw_text(pause_text, width/2 - pause_width/2, height/2,
                            100, 1, 1, Gosu::Color::RED)
    end
  end

  def button_down(id)
    case id
    when Gosu::KB_ESCAPE
      close
    when Gosu::KB_SPACE
      @paused = !@paused
    when Gosu::KB_UP
      @clock_rate = [@clock_rate - 0.1, 0.1].max
    when Gosu::KB_DOWN
      @clock_rate = @clock_rate + 0.1
    when Gosu::KB_R
      # Full restart - clear departments and start fresh
      @current_index = 0
      @active_messages.clear
      @departments.clear
      @stats = { total: 0, broadcasts: 0, point_to_point: 0 }
      @needs_rearrange = false
    end
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: #{$0} <path_to_jsonl_file> [clock_rate]"
    puts "Example: #{$0} city_sim_message_log.jsonl 1.0"
    puts "         clock_rate: seconds between messages (default: 1.0)"
    exit 1
  end

  jsonl_path = ARGV[0]
  clock_rate = ARGV[1] ? ARGV[1].to_f : 1.0

  window = NetworkAnimationWindow.new(jsonl_path, clock_rate)
  window.show
end
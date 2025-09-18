#!/usr/bin/env ruby
# examples/multi_program_demo/redis_monitor.rb
#
# Redis Monitor for SmartMessage Traffic
# Shows formatted, real-time message activity

require 'redis'
require 'json'

require_relative 'common/status_line'

class RedisMonitor
  include Common::StatusLine

  def initialize
    @redis = Redis.new
    @log_file = File.open('city_sim_message_log.jsonl', 'a')
    puts "🔍 SmartMessage Redis Monitor"
    puts "   Monitoring Redis pub/sub traffic..."
    puts "   Logging to: city_sim_message_log.jsonl"
    puts "   Press Ctrl+C to stop\n\n"
    setup_signal_handlers
  end

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        puts "\n🔍 Redis monitor shutting down..."
        @log_file&.close
        exit(0)
      end
    end
  end

  def start_monitoring
    # Use psubscribe to catch all channels
    @redis.psubscribe("*") do |on|
      on.pmessage do |pattern, channel, message|
        display_message(channel, message)
      end
    end
  rescue => e
    puts "❌ Error monitoring Redis: #{e.message}"
    retry
  end

  private

  def display_message(channel, message)
    begin
      data = JSON.parse(message)
      header = data['_sm_header'] || {}
      payload = data['_sm_payload'] || {}

      timestamp = Time.now.strftime('%H:%M:%S')
      iso_timestamp = Time.now.iso8601
      from = header['from'] || 'unknown'
      to = header['to'] || 'broadcast'
      message_class = header['message_class'] || channel

      # Log to JSONL file
      log_entry = {
        timestamp: iso_timestamp,
        channel: channel,
        message_class: message_class,
        from: from,
        to: to,
        header: header,
        payload: payload,
        raw_message: message
      }
      @log_file.puts(log_entry.to_json)
      @log_file.flush

      # Color code by message type
      color = message_color(message_class)

      puts "#{color}[#{timestamp}] #{message_class}#{color_reset}"
      puts "   📤 From: #{from}"
      puts "   📥 To: #{to}"

      # Show relevant payload details
      show_payload_details(message_class, payload)
      puts ""

    rescue JSON::ParserError
      # Handle non-JSON messages
      iso_timestamp = Time.now.iso8601
      log_entry = {
        timestamp: iso_timestamp,
        channel: channel,
        message_class: 'raw',
        from: 'unknown',
        to: 'unknown',
        header: {},
        payload: {},
        raw_message: message
      }
      @log_file.puts(log_entry.to_json)
      @log_file.flush

      puts "📋 [#{Time.now.strftime('%H:%M:%S')}] #{channel}: #{message[0..100]}..."
      puts ""
    end
  end

  def show_payload_details(message_class, payload)
    case message_class
    when /HealthCheck/
      check_id = payload['check_id']
      puts "   🏥 Check ID: #{check_id ? check_id[0..7] : 'unknown'}..."
    when /HealthStatus/
      status = payload['status'] || 'unknown'
      status_color = status_color(status)
      puts "   #{status_color}📊 #{payload['service_name']}: #{status.upcase}#{color_reset}"
      puts "   📝 #{payload['details']}"
    when /FireEmergency/
      puts "   🔥 #{payload['house_address']} - #{payload['fire_type']} (#{payload['severity']})"
      puts "   👥 Occupants: #{payload['occupants_status']}"
    when /FireDispatch/
      puts "   🚒 Engines: #{payload['engines_assigned']&.join(', ')}"
      puts "   📍 Location: #{payload['location']}"
      puts "   ⏱️  ETA: #{payload['estimated_arrival']}"
    when /SilentAlarm/
      puts "   🚨 #{payload['bank_name']} - #{payload['alarm_type']} (#{payload['severity']})"
      puts "   📍 #{payload['location']}"
    when /PoliceDispatch/
      puts "   🚔 Units: #{payload['units_assigned']&.join(', ')}"
      puts "   📍 Location: #{payload['location']}"
      puts "   ⏱️  ETA: #{payload['estimated_arrival']}"
    when /EmergencyResolved/
      puts "   ✅ #{payload['incident_type']} resolved"
      puts "   📍 #{payload['location']}"
      puts "   ⏱️  Duration: #{payload['duration_minutes']} minutes"
    end
  end

  def message_color(message_class)
    case message_class
    when /Health/ then "\e[32m"      # Green
    when /Fire/ then "\e[31m"        # Red
    when /Police/ then "\e[34m"      # Blue
    when /Alarm/ then "\e[33m"       # Yellow
    when /Emergency/ then "\e[35m"   # Magenta
    else "\e[37m"                    # White
    end
  end

  def status_color(status)
    case status
    when 'healthy' then "\e[32m"     # Green
    when 'warning' then "\e[33m"     # Yellow
    when 'critical' then "\e[93m"    # Orange
    when 'failed' then "\e[31m"      # Red
    else "\e[0m"
    end
  end

  def color_reset
    "\e[0m"
  end
end

if __FILE__ == $0
  monitor = RedisMonitor.new
  monitor.start_monitoring
end

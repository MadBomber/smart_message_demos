#!/usr/bin/env ruby
# network_activity.rb
#
# Network Activity Analyzer for SmartMessage Traffic
# Analyzes JSONL files to visualize communication patterns between departments

require 'json'
require 'set'
require 'time'

class NetworkActivityAnalyzer
  def initialize(jsonl_path)
    @jsonl_path = jsonl_path
    @connections = Hash.new { |h, k| h[k] = Hash.new(0) }
    @message_classes = Hash.new(0)
    @department_stats = Hash.new { |h, k| h[k] = { sent: 0, received: 0, broadcast: 0 } }
    @broadcast_messages = []
    @total_messages = 0
  end

  def analyze
    unless File.exist?(@jsonl_path)
      puts "❌ File not found: #{@jsonl_path}"
      exit 1
    end

    puts "📊 Network Activity Analysis"
    puts "📁 Analyzing: #{@jsonl_path}"
    puts "-" * 60

    parse_file
    display_results
  end

  private

  def parse_file
    File.foreach(@jsonl_path) do |line|
      begin
        data = JSON.parse(line)
        process_message(data)
      rescue JSON::ParserError => e
        puts "⚠️  Skipping invalid JSON line: #{e.message}"
      end
    end
  rescue => e
    puts "❌ Error reading file: #{e.message}"
    exit 1
  end

  def process_message(data)
    from = data['from']
    to = data['to']
    message_class = data['message_class']

    @total_messages += 1

    # Track message classes
    @message_classes[message_class] += 1 if message_class

    # Handle department statistics
    if from
      @department_stats[from][:sent] += 1
    end

    if to.nil? || to == 'broadcast' || to == 'unknown'
      # Broadcast message
      @broadcast_messages << {
        from: from || 'unknown',
        message_class: message_class || 'unknown',
        timestamp: data['timestamp']
      }
      @department_stats[from][:broadcast] += 1 if from
    else
      # Point-to-point message
      @connections[from || 'unknown'][to] += 1
      @department_stats[to][:received] += 1
    end
  end

  def display_results
    puts "\n📈 SUMMARY"
    puts "=" * 60
    puts "Total Messages: #{@total_messages}"
    puts "Broadcast Messages: #{@broadcast_messages.size}"
    puts "Point-to-Point Messages: #{@total_messages - @broadcast_messages.size}"
    puts "Unique Departments: #{@department_stats.keys.size}"
    puts "Unique Message Classes: #{@message_classes.keys.size}"

    display_top_message_classes
    display_department_activity
    display_connection_matrix
    display_broadcast_summary
  end

  def display_top_message_classes
    puts "\n📨 TOP MESSAGE CLASSES"
    puts "=" * 60

    sorted_classes = @message_classes.sort_by { |_, count| -count }.first(10)
    max_class_length = sorted_classes.map { |cls, _| cls.to_s.length }.max || 0

    sorted_classes.each do |message_class, count|
      percentage = (count.to_f / @total_messages * 100).round(1)
      bar_length = (percentage / 2).round
      bar = '█' * bar_length

      printf "%-#{max_class_length}s : %5d (%5.1f%%) %s\n",
        message_class || 'unknown', count, percentage, bar
    end
  end

  def display_department_activity
    puts "\n🏢 DEPARTMENT ACTIVITY"
    puts "=" * 60
    puts sprintf("%-30s %8s %8s %10s", "Department", "Sent", "Received", "Broadcast")
    puts "-" * 60

    sorted_depts = @department_stats.sort_by { |_, stats|
      -(stats[:sent] + stats[:received])
    }

    sorted_depts.each do |dept, stats|
      next if dept.nil? || dept == 'unknown'

      printf "%-30s %8d %8d %10d\n",
        dept[0..29],
        stats[:sent],
        stats[:received],
        stats[:broadcast]
    end
  end

  def display_connection_matrix
    puts "\n🔗 TOP COMMUNICATION PATHS"
    puts "=" * 60

    # Flatten and sort connections
    all_connections = []
    @connections.each do |from, destinations|
      destinations.each do |to, count|
        all_connections << { from: from, to: to, count: count }
      end
    end

    top_connections = all_connections.sort_by { |c| -c[:count] }.first(20)

    if top_connections.empty?
      puts "No point-to-point connections found"
    else
      max_from = top_connections.map { |c| c[:from].to_s.length }.max
      max_to = top_connections.map { |c| c[:to].to_s.length }.max

      top_connections.each do |conn|
        bar_length = [conn[:count], 50].min
        bar = '→' * bar_length

        printf "%-#{max_from}s → %-#{max_to}s : %4d %s\n",
          conn[:from][0..[max_from, 30].min],
          conn[:to][0..[max_to, 30].min],
          conn[:count],
          bar
      end
    end
  end

  def display_broadcast_summary
    puts "\n📢 BROADCAST MESSAGES"
    puts "=" * 60

    if @broadcast_messages.empty?
      puts "No broadcast messages found"
      return
    end

    # Group broadcasts by sender
    broadcasts_by_sender = @broadcast_messages.group_by { |m| m[:from] }

    puts "Broadcasters:"
    broadcasts_by_sender.sort_by { |_, msgs| -msgs.size }.each do |sender, msgs|
      puts "  #{sender}: #{msgs.size} broadcasts"

      # Show message class distribution for this sender
      class_counts = msgs.group_by { |m| m[:message_class] }
                         .transform_values(&:size)
                         .sort_by { |_, count| -count }
                         .first(3)

      class_counts.each do |msg_class, count|
        puts "    - #{msg_class}: #{count}"
      end
    end

    # Show recent broadcasts
    puts "\nRecent Broadcasts (last 5):"
    @broadcast_messages.last(5).reverse.each do |msg|
      timestamp = msg[:timestamp] ? Time.parse(msg[:timestamp]).strftime('%H:%M:%S') : 'unknown'
      puts "  [#{timestamp}] #{msg[:from]} → ALL : #{msg[:message_class]}"
    end
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: #{$0} <path_to_jsonl_file>"
    puts "Example: #{$0} city_sim_message_log.jsonl"
    exit 1
  end

  analyzer = NetworkActivityAnalyzer.new(ARGV[0])
  analyzer.analyze
end
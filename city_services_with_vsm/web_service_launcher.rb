#!/usr/bin/env ruby

require 'sinatra/base'
require 'json'
require 'yaml'
require 'fileutils'
require 'securerandom'
require 'redis'

class ServiceLauncher < Sinatra::Base
  set :port, 4567
  set :public_folder, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'

  configure do
    enable :sessions
    # Use environment variable or generate a persistent secret
    session_secret = ENV['SESSION_SECRET'] || begin
      secret_file = File.join(File.dirname(__FILE__), '.session_secret')
      if File.exist?(secret_file)
        File.read(secret_file).strip
      else
        new_secret = SecureRandom.hex(32)
        File.write(secret_file, new_secret)
        new_secret
      end
    end
    set :session_secret, 'city_services_secret_2025_' + session_secret
    set :services_dir, File.dirname(__FILE__)
    set :running_services, {}

    # Initialize Redis with error handling
    begin
      set :redis_client, Redis.new(host: 'localhost', port: 6379, timeout: 1)
      settings.redis_client.ping # Test connection
      set :redis_available, true
    rescue => e
      puts "⚠️  Redis not available: #{e.message}"
      set :redis_available, false
      set :redis_client, nil
    end

    set :message_history, []
    set :service_metrics, Hash.new { |h, k| h[k] = { messages_sent: 0, messages_received: 0, uptime: 0 } }
  end

  helpers do
    def discover_services
      services = {
        departments: [],
        infrastructure: [],
        actors: [],
        monitors: []
      }

      # Discover YAML-configured departments
      Dir.glob(File.join(settings.services_dir, '*_department.yml')).each do |file|
        dept_name = File.basename(file, '.yml')
        next if dept_name.start_with?('test_')

        config = YAML.load_file(file)
        services[:departments] << {
          name: dept_name,
          display_name: config['department_name'] || dept_name.gsub('_', ' ').split.map(&:capitalize).join(' '),
          type: 'yaml',
          command: "bundle exec ruby generic_department.rb #{dept_name}",
          description: config['description'] || "Generic department service"
        }
      end

      # Discover native Ruby departments
      Dir.glob(File.join(settings.services_dir, '*_department.rb')).each do |file|
        dept_name = File.basename(file, '.rb')
        next if dept_name == 'generic_department' || dept_name.start_with?('test_')
        next if services[:departments].any? { |d| d[:name] == dept_name }

        services[:departments] << {
          name: dept_name,
          display_name: dept_name.gsub('_', ' ').split.map(&:capitalize).join(' '),
          type: 'ruby',
          command: "bundle exec ruby #{dept_name}.rb",
          description: "Native Ruby department service"
        }
      end

      # Infrastructure services
      services[:infrastructure] = [
        { name: 'city_council', display_name: 'City Council', command: 'bundle exec ruby city_council.rb', description: 'Department generator and governance' },
        { name: 'emergency_dispatch', display_name: 'Emergency Dispatch (911)', command: 'bundle exec ruby emergency_dispatch_center.rb', description: 'Routes emergency calls' },
        { name: 'local_bank', display_name: 'Local Bank', command: 'bundle exec ruby local_bank.rb', description: 'Generates silent alarms' }
      ]

      # Actor services (houses, citizens, visitors)
      services[:actors] = [
        { name: 'house_1', display_name: 'House - 456 Oak Street', command: "bundle exec ruby house.rb '456 Oak Street'", description: 'Residential unit' },
        { name: 'house_2', display_name: 'House - 789 Pine Lane', command: "bundle exec ruby house.rb '789 Pine Lane'", description: 'Residential unit' },
        { name: 'house_3', display_name: 'House - 321 Elm Drive', command: "bundle exec ruby house.rb '321 Elm Drive'", description: 'Residential unit' },
        { name: 'house_4', display_name: 'House - 654 Maple Road', command: "bundle exec ruby house.rb '654 Maple Road'", description: 'Residential unit' },
        { name: 'citizen_1', display_name: 'Citizen - John Smith', command: "bundle exec ruby citizen.rb 'John Smith' auto", description: 'Makes emergency calls' },
        { name: 'citizen_2', display_name: 'Citizen - Mary Johnson', command: "bundle exec ruby citizen.rb 'Mary Johnson' auto", description: 'Makes emergency calls' },
        { name: 'citizen_3', display_name: 'Citizen - Robert Williams', command: "bundle exec ruby citizen.rb 'Robert Williams' auto", description: 'Makes emergency calls' },
        { name: 'visitor_1', display_name: 'Visitor - Chicago', command: "bundle exec ruby visitor.rb 'Chicago'", description: 'City visitor' },
        { name: 'visitor_2', display_name: 'Visitor - Boston', command: "bundle exec ruby visitor.rb 'Boston'", description: 'City visitor' }
      ]

      # Monitoring services
      services[:monitors] = [
        { name: 'redis_monitor', display_name: 'Redis Monitor', command: 'bundle exec ruby redis_monitor.rb', description: 'Real-time message traffic' },
        { name: 'redis_stats', display_name: 'Redis Statistics', command: 'bundle exec ruby redis_stats.rb', description: 'Performance metrics dashboard' }
      ]

      services
    end

    def service_running?(service_name)
      settings.running_services[service_name] &&
        settings.running_services[service_name][:pid] &&
        process_alive?(settings.running_services[service_name][:pid])
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end

    def start_service(service)
      puts "🚀 [DEBUG] Attempting to start service: #{service[:name]}"
      puts "🚀 [DEBUG] Service details: #{service.inspect}"

      if service_running?(service[:name])
        puts "⚠️  [DEBUG] Service #{service[:name]} is already running"
        return { success: false, message: "Service already running" }
      end

      begin
        # Create log directory if it doesn't exist
        log_dir = File.join(settings.services_dir, 'log')
        FileUtils.mkdir_p(log_dir)

        log_file = File.join(log_dir, "#{service[:name]}.log")
        puts "📝 [DEBUG] Log file: #{log_file}"

        # Create pipes for capturing STDOUT and STDERR
        stdout_r, stdout_w = IO.pipe
        stderr_r, stderr_w = IO.pipe

        # Start the service in background with pipe redirection
        puts "💾 [DEBUG] Spawning command: '#{service[:command]}'"
        puts "💾 [DEBUG] Working directory: #{settings.services_dir}"

        pid = spawn(
          service[:command],
          chdir: settings.services_dir,
          out: stdout_w,
          err: stderr_w
        )

        puts "✅ [DEBUG] Successfully spawned process with PID: #{pid}"

        # Close write ends in parent process
        stdout_w.close
        stderr_w.close

        Process.detach(pid)
        puts "🔄 [DEBUG] Process detached successfully"

        # Create a circular buffer for recent output (last 1000 lines)
        output_buffer = []
        output_mutex = Mutex.new

        # Start threads to read from pipes and write to both log file and buffer
        stdout_thread = Thread.new do
          begin
            File.open(log_file, 'a') do |log|
              stdout_r.each_line do |line|
                log.puts line
                log.flush
                output_mutex.synchronize do
                  output_buffer << { type: 'stdout', line: line.chomp, timestamp: Time.now.to_f }
                  output_buffer.shift if output_buffer.length > 1000
                end
              end
            end
          rescue IOError, Errno::EBADF
            # Stream was closed, thread terminating normally
          rescue => e
            puts "Error in stdout thread: #{e.message}"
          end
        end

        stderr_thread = Thread.new do
          begin
            File.open(log_file, 'a') do |log|
              stderr_r.each_line do |line|
                log.puts "[ERROR] #{line}"
                log.flush
                output_mutex.synchronize do
                  output_buffer << { type: 'stderr', line: line.chomp, timestamp: Time.now.to_f }
                  output_buffer.shift if output_buffer.length > 1000
                end
              end
            end
          rescue IOError, Errno::EBADF
            # Stream was closed, thread terminating normally
          rescue => e
            puts "Error in stderr thread: #{e.message}"
          end
        end

        settings.running_services[service[:name]] = {
          pid: pid,
          command: service[:command],
          started_at: Time.now,
          log_file: log_file,
          stdout_pipe: stdout_r,
          stderr_pipe: stderr_r,
          stdout_thread: stdout_thread,
          stderr_thread: stderr_thread,
          output_buffer: output_buffer,
          output_mutex: output_mutex
        }

        puts "🎉 [DEBUG] Service #{service[:name]} successfully registered with PID #{pid}"
        puts "🎉 [DEBUG] Service is now tracked in running_services"

        { success: true, message: "Started #{service[:display_name]}", pid: pid }
      rescue => e
        puts "❌ [DEBUG] Failed to start service #{service[:name]}: #{e.class}: #{e.message}"
        puts "❌ [DEBUG] Backtrace: #{e.backtrace.first(3).join(', ')}"
        { success: false, message: "Failed to start: #{e.message}" }
      end
    end

    def stop_service(service_name)
      return { success: false, message: "Service not running" } unless service_running?(service_name)

      begin
        service_info = settings.running_services[service_name]
        pid = service_info[:pid]

        # Kill the process
        Process.kill('TERM', pid)

        # Close pipes if they exist
        service_info[:stdout_pipe]&.close rescue nil
        service_info[:stderr_pipe]&.close rescue nil

        # Kill threads if they exist
        service_info[:stdout_thread]&.kill rescue nil
        service_info[:stderr_thread]&.kill rescue nil

        settings.running_services.delete(service_name)
        { success: true, message: "Stopped service" }
      rescue => e
        { success: false, message: "Failed to stop: #{e.message}" }
      end
    end

    def stop_all_services
      settings.running_services.keys.each do |service_name|
        stop_service(service_name)
      end
    end
  end

  # Routes
  get '/' do
    @services = discover_services
    @running_services = settings.running_services
    erb :index
  end

  post '/start' do
    content_type :json

    service_name = params[:service]
    puts "🌐 [DEBUG] POST /start received request for service: #{service_name}"

    services = discover_services
    puts "🌐 [DEBUG] Discovered #{services.values.flatten.length} total services"

    # Find the service in all categories
    service = nil
    services.each do |category, items|
      service = items.find { |s| s[:name] == service_name }
      break if service
    end

    unless service
      puts "🌐 [DEBUG] Service #{service_name} not found in discovered services"
      return { success: false, message: "Service not found" }.to_json
    end

    puts "🌐 [DEBUG] Found service: #{service[:name]} (#{service[:command]})"
    result = start_service(service)
    puts "🌐 [DEBUG] Start result: #{result}"
    result.to_json
  end

  post '/stop' do
    content_type :json

    service_name = params[:service]
    result = stop_service(service_name)
    result.to_json
  end

  post '/start_selected' do
    content_type :json

    selected = JSON.parse(request.body.read)['services']
    puts "🌐 [DEBUG] POST /start_selected received request for services: #{selected.inspect}"

    services = discover_services
    puts "🌐 [DEBUG] Discovered #{services.values.flatten.length} total services"

    results = []

    selected.each do |service_name|
      puts "🌐 [DEBUG] Processing service: #{service_name}"
      service = nil
      services.each do |category, items|
        service = items.find { |s| s[:name] == service_name }
        break if service
      end

      if service
        puts "🌐 [DEBUG] Found service: #{service[:name]} (#{service[:command]})"
        result = start_service(service)
        puts "🌐 [DEBUG] Start result for #{service_name}: #{result}"
        results << { service: service_name, **result }
      else
        puts "🌐 [DEBUG] Service #{service_name} not found"
        results << { service: service_name, success: false, message: "Service not found" }
      end
    end

    puts "🌐 [DEBUG] Final results: #{results}"
    { results: results }.to_json
  end

  post '/stop_all' do
    content_type :json

    stop_all_services
    { success: true, message: "All services stopped" }.to_json
  end

  get '/status' do
    content_type :json

    status = {}
    settings.running_services.each do |name, info|
      status[name] = {
        running: process_alive?(info[:pid]),
        pid: info[:pid],
        started_at: info[:started_at],
        uptime: Time.now - info[:started_at]
      }
    end

    status.to_json
  end

  # Service status for network view - includes all services with full metadata
  get '/services/status' do
    content_type :json
    service_data = {}
    discover_services.each do |category, services|
      services.each do |service|
        service_data[service[:name]] = {
          name: service[:name],
          display_name: service[:display_name],
          type: category.to_s,
          running: service_running?(service[:name]),
          metrics: settings.service_metrics[service[:name]]
        }
      end
    end
    service_data.to_json
  end

  get '/logs/:service' do
    service_name = params[:service]

    return "Service not found" unless settings.running_services[service_name]

    log_file = settings.running_services[service_name][:log_file]

    if File.exist?(log_file)
      content_type :text
      File.read(log_file).split("\n").last(100).join("\n")
    else
      "No logs available"
    end
  end

  # Get recent console output from buffer
  get '/console/:service' do
    service_name = params[:service]
    service_info = settings.running_services[service_name]

    return { error: "Service not found" }.to_json unless service_info

    content_type :json

    output = []
    if service_info[:output_buffer] && service_info[:output_mutex]
      service_info[:output_mutex].synchronize do
        output = service_info[:output_buffer].last(100)
      end
    end

    {
      service: service_name,
      running: service_running?(service_name),
      output: output,
      lines: output.length
    }.to_json
  end

  # Stream live console output
  get '/console/:service/stream' do
    service_name = params[:service]
    service_info = settings.running_services[service_name]

    return "Service not found" unless service_info

    content_type 'text/event-stream'
    headers 'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
            'Access-Control-Allow-Origin' => '*'

    stream(:keep_open) do |out|
      out << "data: #{JSON.generate(type: 'connected', service: service_name)}\n\n"

      last_index = 0
      running = true

      while running && service_running?(service_name)
        begin
          if service_info[:output_buffer] && service_info[:output_mutex]
            new_lines = []
            service_info[:output_mutex].synchronize do
              buffer = service_info[:output_buffer]
              if buffer.length > last_index
                new_lines = buffer[last_index..-1]
                last_index = buffer.length
              end
            end

            new_lines.each do |line_data|
              out << "data: #{line_data.to_json}\n\n"
            end
          end

          sleep(0.5) # Check for new output every 500ms
        rescue => e
          out << "data: #{JSON.generate(type: 'error', message: e.message)}\n\n"
          running = false
        end
      end

      out << "data: #{JSON.generate(type: 'disconnected', service: service_name)}\n\n"
    end
  end

  # Service console viewer
  get '/console/:service' do
    erb :console
  end

  # Real-time Dashboard
  get '/dashboard' do
    @services = discover_services
    @running_services = settings.running_services
    erb :dashboard
  end

  # Network Visualization
  get '/network' do
    @services = discover_services
    @running_services = settings.running_services
    erb :network
  end

  # Network SSE stream
  get '/network/stream' do
    content_type 'text/event-stream'
    headers 'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no'

    stream(:keep_open) do |out|
      begin
        # Send initial service status
        service_data = {}
        discover_services.each do |category, services|
          services.each do |service|
            service_data[service[:name]] = {
              name: service[:name],
              display_name: service[:display_name],
              type: category.to_s,
              running: service_running?(service[:name]),
              metrics: settings.service_metrics[service[:name]]
            }
          end
        end
        out << "data: #{JSON.generate({services: service_data})}\n\n"

        # Subscribe to Redis messages if available
        if settings.redis_available
          redis = Redis.new(host: 'localhost', port: 6379)
          redis.psubscribe('*') do |on|
            on.pmessage do |pattern, channel, message|
              begin
                # Send message for network visualization
                out << "data: #{JSON.generate({
                  type: 'message',
                  channel: channel,
                  message: message,
                  timestamp: Time.now.to_f
                })}\n\n"

                # Update metrics
                if message.include?('from:')
                  from_match = message.match(/from:\s*(\S+)/)
                  if from_match
                    sender = from_match[1]
                    settings.service_metrics[sender][:messages_sent] += 1
                  end
                end

                if message.include?('to:')
                  to_match = message.match(/to:\s*(\S+)/)
                  if to_match
                    receiver = to_match[1]
                    settings.service_metrics[receiver][:messages_received] += 1
                  end
                end

                # Periodically send updated service status
                if rand < 0.1  # 10% chance to send status update
                  service_data = {}
                  discover_services.each do |category, services|
                    services.each do |service|
                      service_data[service[:name]] = {
                        name: service[:name],
                        display_name: service[:display_name],
                        type: category.to_s,
                        running: service_running?(service[:name]),
                        metrics: settings.service_metrics[service[:name]]
                      }
                    end
                  end
                  out << "data: #{JSON.generate({services: service_data})}\n\n"
                end
              rescue => e
                puts "Error in network stream: #{e.message}"
              end
            end
          end
        else
          # Fallback: just send periodic status updates
          loop do
            sleep 5
            service_data = {}
            discover_services.each do |category, services|
              services.each do |service|
                service_data[service[:name]] = {
                  name: service[:name],
                  display_name: service[:display_name],
                  type: category.to_s,
                  running: service_running?(service[:name]),
                  metrics: settings.service_metrics[service[:name]]
                }
              end
            end
            out << "data: #{JSON.generate({services: service_data})}\n\n"
          end
        end
      rescue => e
        puts "Network stream error: #{e.message}"
      ensure
        out.close
      end
    end
  end

  # Redis message monitoring
  get '/messages/stream' do
    content_type 'text/event-stream'
    headers 'Cache-Control' => 'no-cache',
            'Connection' => 'keep-alive',
            'Access-Control-Allow-Origin' => '*'

    stream(:keep_open) do |out|
      if !settings.redis_available
        out << "data: #{JSON.generate(type: 'error', message: 'Redis not available. Start Redis server to see live messages.')}\n\n"
        # Send demo messages instead
        Thread.new do
          5.times do |i|
            sleep(2)
            demo_message = {
              type: 'message',
              channel: 'demo-channel',
              message: { content: "Demo message #{i + 1}", demo: true },
              timestamp: Time.now.to_f
            }
            out << "data: #{demo_message.to_json}\n\n"
          end
        end
        return
      end

      # Send initial connection message
      out << "data: #{JSON.generate(type: 'connected', message: 'Message stream connected to Redis')}\n\n"

      begin
        # Create a separate Redis client for this connection
        redis = Redis.new(host: 'localhost', port: 6379, timeout: 5)

        # Subscribe to all channels
        redis.psubscribe('*') do |on|
          on.pmessage do |pattern, channel, message|
            parsed_message = begin
              JSON.parse(message)
            rescue JSON::ParserError
              { content: message, timestamp: Time.now.to_f }
            end

            event_data = {
              type: 'message',
              channel: channel,
              message: parsed_message,
              timestamp: Time.now.to_f
            }

            # Store in history (keep last 100 messages)
            settings.message_history << event_data
            settings.message_history.shift if settings.message_history.length > 100

            # Send to client
            out << "data: #{event_data.to_json}\n\n"
          end
        end
      rescue => e
        out << "data: #{JSON.generate(type: 'error', message: 'Redis connection lost: ' + e.message)}\n\n"
      ensure
        redis&.close
      end
    end
  end

  # Get recent messages
  get '/messages/recent' do
    content_type :json
    settings.message_history.last(50).to_json
  end

  # Analytics dashboard
  get '/analytics' do
    @services = discover_services
    @running_services = settings.running_services
    erb :analytics
  end

  # Service metrics API
  get '/metrics' do
    content_type :json

    metrics = {}
    settings.running_services.each do |service_name, info|
      next unless info[:pid] && process_alive?(info[:pid])

      uptime = Time.now - info[:started_at]
      log_file = info[:log_file]

      message_count = 0
      if File.exist?(log_file)
        message_count = File.readlines(log_file).count { |line| line.include?('message') || line.include?('Message') }
      end

      metrics[service_name] = {
        uptime: uptime,
        message_count: message_count,
        status: 'running',
        started_at: info[:started_at].to_f,
        pid: info[:pid]
      }
    end

    metrics.to_json
  end

  # Citizen Portal
  get '/citizen' do
    erb :citizen_portal
  end

  post '/citizen/emergency' do
    content_type :json

    emergency_data = {
      type: params[:emergency_type],
      description: params[:description],
      location: params[:location],
      reporter: params[:reporter_name],
      timestamp: Time.now.to_f,
      id: SecureRandom.hex(8)
    }

    begin
      if settings.redis_available
        # Publish emergency to Redis
        settings.redis_client.publish('emergency-reports', emergency_data.to_json)
        message = "Emergency reported successfully and sent to dispatch"
      else
        # Store locally when Redis unavailable
        settings.message_history << {
          type: 'message',
          channel: 'emergency-reports',
          message: emergency_data,
          timestamp: Time.now.to_f
        }
        message = "Emergency recorded locally (Redis unavailable)"
      end

      { success: true, message: message, emergency_id: emergency_data[:id] }.to_json
    rescue => e
      { success: false, message: "Failed to report emergency: #{e.message}" }.to_json
    end
  end

  # Graceful shutdown
  at_exit do
    puts "\nShutting down all services..."
    settings.running_services.keys.each do |service_name|
      if settings.running_services[service_name] && settings.running_services[service_name][:pid]
        begin
          Process.kill('TERM', settings.running_services[service_name][:pid])
        rescue Errno::ESRCH
          # Process already dead
        end
      end
    end
  end
end

# Ensure views directory exists
views_dir = File.join(File.dirname(__FILE__), 'views')
FileUtils.mkdir_p(views_dir)

# Run the application
if __FILE__ == $0
  ServiceLauncher.run!
end
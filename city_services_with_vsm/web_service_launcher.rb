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
    set :redis_client, Redis.new(host: 'localhost', port: 6379)
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
          command: "ruby generic_department.rb #{dept_name}",
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
          command: "ruby #{dept_name}.rb",
          description: "Native Ruby department service"
        }
      end

      # Infrastructure services
      services[:infrastructure] = [
        { name: 'city_council', display_name: 'City Council', command: 'ruby city_council.rb', description: 'Department generator and governance' },
        { name: 'emergency_dispatch', display_name: 'Emergency Dispatch (911)', command: 'ruby emergency_dispatch_center.rb', description: 'Routes emergency calls' },
        { name: 'local_bank', display_name: 'Local Bank', command: 'ruby local_bank.rb', description: 'Generates silent alarms' }
      ]

      # Actor services (houses, citizens, visitors)
      services[:actors] = [
        { name: 'house_1', display_name: 'House - 456 Oak Street', command: "ruby house.rb '456 Oak Street'", description: 'Residential unit' },
        { name: 'house_2', display_name: 'House - 789 Pine Lane', command: "ruby house.rb '789 Pine Lane'", description: 'Residential unit' },
        { name: 'house_3', display_name: 'House - 321 Elm Drive', command: "ruby house.rb '321 Elm Drive'", description: 'Residential unit' },
        { name: 'house_4', display_name: 'House - 654 Maple Road', command: "ruby house.rb '654 Maple Road'", description: 'Residential unit' },
        { name: 'citizen_1', display_name: 'Citizen - John Smith', command: "ruby citizen.rb 'John Smith' auto", description: 'Makes emergency calls' },
        { name: 'citizen_2', display_name: 'Citizen - Mary Johnson', command: "ruby citizen.rb 'Mary Johnson' auto", description: 'Makes emergency calls' },
        { name: 'citizen_3', display_name: 'Citizen - Robert Williams', command: "ruby citizen.rb 'Robert Williams' auto", description: 'Makes emergency calls' },
        { name: 'visitor_1', display_name: 'Visitor - Chicago', command: "ruby visitor.rb 'Chicago'", description: 'City visitor' },
        { name: 'visitor_2', display_name: 'Visitor - Boston', command: "ruby visitor.rb 'Boston'", description: 'City visitor' }
      ]

      # Monitoring services
      services[:monitors] = [
        { name: 'redis_monitor', display_name: 'Redis Monitor', command: 'ruby redis_monitor.rb', description: 'Real-time message traffic' },
        { name: 'redis_stats', display_name: 'Redis Statistics', command: 'ruby redis_stats.rb', description: 'Performance metrics dashboard' }
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
      return { success: false, message: "Service already running" } if service_running?(service[:name])

      begin
        # Create log directory if it doesn't exist
        log_dir = File.join(settings.services_dir, 'log')
        FileUtils.mkdir_p(log_dir)

        log_file = File.join(log_dir, "#{service[:name]}.log")

        # Start the service in background
        pid = spawn(
          service[:command],
          chdir: settings.services_dir,
          out: log_file,
          err: log_file
        )

        Process.detach(pid)

        settings.running_services[service[:name]] = {
          pid: pid,
          command: service[:command],
          started_at: Time.now,
          log_file: log_file
        }

        { success: true, message: "Started #{service[:display_name]}", pid: pid }
      rescue => e
        { success: false, message: "Failed to start: #{e.message}" }
      end
    end

    def stop_service(service_name)
      return { success: false, message: "Service not running" } unless service_running?(service_name)

      begin
        pid = settings.running_services[service_name][:pid]
        Process.kill('TERM', pid)
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
    services = discover_services

    # Find the service in all categories
    service = nil
    services.each do |category, items|
      service = items.find { |s| s[:name] == service_name }
      break if service
    end

    return { success: false, message: "Service not found" }.to_json unless service

    result = start_service(service)
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
    services = discover_services
    results = []

    selected.each do |service_name|
      service = nil
      services.each do |category, items|
        service = items.find { |s| s[:name] == service_name }
        break if service
      end

      if service
        result = start_service(service)
        results << { service: service_name, **result }
      end
    end

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

  # Real-time Dashboard
  get '/dashboard' do
    @services = discover_services
    @running_services = settings.running_services
    erb :dashboard
  end

  # Redis message monitoring
  get '/messages/stream' do
    content_type 'text/event-stream'

    Thread.new do
      begin
        settings.redis_client.psubscribe('*') do |on|
          on.pmessage do |pattern, channel, message|
            parsed_message = begin
              JSON.parse(message)
            rescue JSON::ParserError
              { content: message, timestamp: Time.now.to_f }
            end

            event_data = {
              channel: channel,
              message: parsed_message,
              timestamp: Time.now.to_f
            }

            # Store in history (keep last 100 messages)
            settings.message_history << event_data
            settings.message_history.shift if settings.message_history.length > 100

            "data: #{event_data.to_json}\n\n"
          end
        end
      rescue => e
        "data: #{JSON.generate(error: e.message)}\n\n"
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
      # Publish emergency to Redis
      settings.redis_client.publish('emergency-reports', emergency_data.to_json)

      { success: true, message: "Emergency reported successfully", emergency_id: emergency_data[:id] }.to_json
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
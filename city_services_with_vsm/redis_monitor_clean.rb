#!/usr/bin/env ruby
# redis_monitor_simple.rb - Simple web-based Redis pub/sub message monitor using polling

require 'sinatra'
require 'redis'
require 'json'
require 'set'
require 'logger'
require 'thread'

class RedisMonitorSimple < Sinatra::Base
  configure do
    set :bind, '0.0.0.0'
    set :port, 4567
    set :server, 'puma'

    # Setup Redis connections
    set :redis, Redis.new(host: 'localhost', port: 6379, db: 0)
    set :subscriber, Redis.new(host: 'localhost', port: 6379, db: 0)

    # Message buffer for storing recent messages
    set :message_buffer, []
    set :buffer_size, 1000
    set :buffer_lock, Mutex.new

    # Track filters
    set :message_filters, {
      message_types: Set.new,
      services: Set.new
    }

    # Setup logging
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    set :logger, logger
  end

  # Available message types based on messages directory
  MESSAGE_TYPES = %w[
    Messages::Emergency911Message
    Messages::PoliceDispatchMessage
    Messages::FireDispatchMessage
    Messages::FireEmergencyMessage
    Messages::SilentAlarmMessage
    Messages::HealthCheckMessage
    Messages::HealthStatusMessage
    Messages::EmergencyResolvedMessage
    Messages::DepartmentAnnouncementMessage
    Messages::ServiceRequestMessage
  ].freeze

  # Available city services
  CITY_SERVICES = %w[
    emergency-dispatch-center
    health-department
    police-department
    fire-department
    citizens
    houses
    local-bank
    city-council
    visitor
    tip-line
  ].freeze

  # Route to serve the main monitoring interface
  get '/' do
    # Return the HTML directly instead of using ERB template
    content_type 'text/html'
    <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>City Services Redis Message Monitor</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            background-color: #1a1a1a;
            color: #e0e0e0;
            line-height: 1.4;
        }

        .container {
            display: flex;
            height: 100vh;
        }

        .sidebar {
            width: 300px;
            background-color: #2d2d2d;
            padding: 20px;
            overflow-y: auto;
            border-right: 2px solid #404040;
        }

        .main-content {
            flex: 1;
            display: flex;
            flex-direction: column;
        }

        .header {
            background-color: #333;
            padding: 15px 20px;
            border-bottom: 2px solid #404040;
        }

        .filter-section {
            margin-bottom: 25px;
        }

        .filter-section h3 {
            color: #4a9eff;
            margin-bottom: 10px;
            font-size: 14px;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .filter-controls {
            display: flex;
            gap: 5px;
            margin-bottom: 10px;
        }

        .btn {
            padding: 4px 8px;
            font-size: 11px;
            background-color: #404040;
            color: #e0e0e0;
            border: 1px solid #555;
            cursor: pointer;
            border-radius: 3px;
            transition: background-color 0.2s;
        }

        .btn:hover {
            background-color: #505050;
        }

        .btn.select-all {
            background-color: #2d5a2d;
        }

        .btn.deselect-all {
            background-color: #5a2d2d;
        }

        .checkbox-group {
            max-height: 200px;
            overflow-y: auto;
            border: 1px solid #404040;
            padding: 8px;
            background-color: #1f1f1f;
        }

        .checkbox-item {
            display: flex;
            align-items: center;
            margin-bottom: 5px;
            font-size: 12px;
        }

        .checkbox-item input[type="checkbox"] {
            margin-right: 8px;
            transform: scale(1.1);
        }

        .checkbox-item label {
            cursor: pointer;
            flex: 1;
        }

        .status {
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 3px;
            font-size: 12px;
        }

        .status.connected {
            background-color: #2d5a2d;
            color: #90ee90;
        }

        .status.disconnected {
            background-color: #5a2d2d;
            color: #ff9090;
        }

        .message-display {
            flex: 1;
            background-color: #1a1a1a;
            padding: 15px;
            overflow-y: auto;
            font-size: 11px;
        }

        .message {
            margin-bottom: 15px;
            padding: 10px;
            border-left: 3px solid #404040;
            background-color: #222;
            border-radius: 0 3px 3px 0;
        }

        .message.type-message {
            border-left-color: #4a9eff;
        }

        .message.type-connection {
            border-left-color: #90ee90;
        }

        .message.type-raw_message {
            border-left-color: #ffcc4a;
        }

        .message-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 8px;
            padding-bottom: 5px;
            border-bottom: 1px solid #333;
        }

        .message-meta {
            font-size: 10px;
            color: #888;
        }

        .message-type {
            background-color: #404040;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 10px;
            color: #4a9eff;
        }

        .message-route {
            color: #90ee90;
            font-size: 10px;
        }

        .message-content {
            background-color: #1a1a1a;
            padding: 8px;
            border-radius: 3px;
            overflow-x: auto;
            white-space: pre-wrap;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
        }

        .json-content {
            color: #e0e0e0;
        }

        .json-key {
            color: #4a9eff;
        }

        .json-string {
            color: #90ee90;
        }

        .json-number {
            color: #ffcc4a;
        }

        .json-boolean {
            color: #ff9090;
        }

        .controls {
            padding: 10px;
            background-color: #2d2d2d;
            border-top: 1px solid #404040;
        }

        .clear-btn {
            background-color: #5a2d2d;
            color: #ff9090;
            padding: 8px 12px;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            font-size: 12px;
        }

        .clear-btn:hover {
            background-color: #6a3d3d;
        }

        .loading {
            text-align: center;
            color: #888;
            padding: 20px;
        }

        /* Scrollbar styling */
        ::-webkit-scrollbar {
            width: 8px;
        }

        ::-webkit-scrollbar-track {
            background: #1a1a1a;
        }

        ::-webkit-scrollbar-thumb {
            background: #404040;
            border-radius: 4px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: #505050;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="sidebar">
            <h2 style="color: #4a9eff; margin-bottom: 20px; font-size: 16px;">Message Filters</h2>

            <div id="status" class="status connected">
                Connected to Redis
            </div>

            <div class="filter-section">
                <h3>Message Types</h3>
                <div class="filter-controls">
                    <button class="btn select-all" onclick="selectAllMessages()">All</button>
                    <button class="btn deselect-all" onclick="deselectAllMessages()">None</button>
                </div>
                <div class="checkbox-group" id="messageTypeFilters">
                    <div class="loading">Loading message types...</div>
                </div>
            </div>

            <div class="filter-section">
                <h3>City Services</h3>
                <div class="filter-controls">
                    <button class="btn select-all" onclick="selectAllServices()">All</button>
                    <button class="btn deselect-all" onclick="deselectAllServices()">None</button>
                </div>
                <div class="checkbox-group" id="serviceFilters">
                    <div class="loading">Loading services...</div>
                </div>
            </div>

            <div class="controls">
                <button class="clear-btn" onclick="clearMessages()">Clear Messages</button>
            </div>
        </div>

        <div class="main-content">
            <div class="header">
                <h1 style="color: #4a9eff;">City Services Redis Message Monitor</h1>
                <p style="color: #888; font-size: 12px; margin-top: 5px;">Real-time monitoring of Messages::* Redis pub/sub channels (Polling Mode)</p>
            </div>
            <div class="message-display" id="messageDisplay">
                <div class="loading">Waiting for messages...</div>
            </div>
        </div>
    </div>

    <script>
        let lastTimestamp = new Date().toISOString();
        let messageCount = 0;
        const MAX_MESSAGES = 500;
        let pollingInterval;

        // Initialize the application
        document.addEventListener('DOMContentLoaded', function() {
            loadFilters();
            startPolling();
        });

        // Load available filters from the server
        function loadFilters() {
            fetch('/api/filters')
                .then(response => response.json())
                .then(data => {
                    populateMessageTypeFilters(data.message_types);
                    populateServiceFilters(data.services);
                })
                .catch(error => {
                    console.error('Error loading filters:', error);
                });
        }

        // Populate message type checkboxes
        function populateMessageTypeFilters(messageTypes) {
            const container = document.getElementById('messageTypeFilters');
            container.innerHTML = '';

            messageTypes.forEach(type => {
                const div = document.createElement('div');
                div.className = 'checkbox-item';
                div.innerHTML = `
                    <input type="checkbox" id="msg_\${type}" onchange="updateFilters()">
                    <label for="msg_\${type}">\${type}</label>
                `;
                container.appendChild(div);
            });
        }

        // Populate service checkboxes
        function populateServiceFilters(services) {
            const container = document.getElementById('serviceFilters');
            container.innerHTML = '';

            services.forEach(service => {
                const div = document.createElement('div');
                div.className = 'checkbox-item';
                div.innerHTML = `
                    <input type="checkbox" id="svc_\${service}" onchange="updateFilters()">
                    <label for="svc_\${service}">\${service}</label>
                `;
                container.appendChild(div);
            });
        }

        // Start polling for messages
        function startPolling() {
            pollingInterval = setInterval(pollForMessages, 1000);
        }

        // Poll server for new messages
        function pollForMessages() {
            fetch(`/api/messages?since=\${encodeURIComponent(lastTimestamp)}`)
                .then(response => response.json())
                .then(data => {
                    if (data.messages && data.messages.length > 0) {
                        data.messages.forEach(message => {
                            displayMessage(message);
                        });
                    }
                    lastTimestamp = data.timestamp;
                })
                .catch(error => {
                    console.error('Error polling for messages:', error);
                    updateStatus('disconnected', 'Error connecting to server');
                });
        }

        // Update connection status
        function updateStatus(status, message) {
            const statusElement = document.getElementById('status');
            statusElement.className = `status \${status}`;
            statusElement.textContent = message;
        }

        // Display a message in the message area
        function displayMessage(data) {
            const messageDisplay = document.getElementById('messageDisplay');

            // Remove loading message if present
            if (messageDisplay.querySelector('.loading')) {
                messageDisplay.innerHTML = '';
            }

            // Create message element
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message type-message';

            messageDiv.innerHTML = `
                <div class="message-header">
                    <div>
                        <span class="message-type">\${data.message_type}</span>
                        <span class="message-route">\${data.from} → \${data.to}</span>
                    </div>
                    <div class="message-meta">\${formatTimestamp(data.timestamp)}</div>
                </div>
                <div class="message-content">\${formatJSON(data.content)}</div>
            `;

            // Add to display
            messageDisplay.appendChild(messageDiv);

            // Limit number of messages
            messageCount++;
            if (messageCount > MAX_MESSAGES) {
                const firstMessage = messageDisplay.querySelector('.message');
                if (firstMessage) {
                    messageDisplay.removeChild(firstMessage);
                    messageCount--;
                }
            }

            // Auto-scroll to bottom
            messageDisplay.scrollTop = messageDisplay.scrollHeight;
        }

        // Format timestamp for display
        function formatTimestamp(timestamp) {
            const date = new Date(timestamp);
            return date.toLocaleTimeString() + '.' + String(date.getMilliseconds()).padStart(3, '0');
        }

        // Format JSON for display with syntax highlighting
        function formatJSON(obj) {
            return JSON.stringify(obj, null, 2)
                .replace(/("([^"]+)":\\s*)/g, '<span class="json-key">$1</span>')
                .replace(/:\\s*"([^"]+)"/g, ': <span class="json-string">"$1"</span>')
                .replace(/:\\s*(\\d+)/g, ': <span class="json-number">$1</span>')
                .replace(/:\\s*(true|false)/g, ': <span class="json-boolean">$1</span>');
        }

        // Update filters on the server
        function updateFilters() {
            const messageTypes = Array.from(document.querySelectorAll('#messageTypeFilters input:checked'))
                .map(input => input.id.replace('msg_', ''));

            const services = Array.from(document.querySelectorAll('#serviceFilters input:checked'))
                .map(input => input.id.replace('svc_', ''));

            fetch('/api/filters', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    message_types: messageTypes,
                    services: services
                })
            })
            .then(response => response.json())
            .then(data => {
                console.log('Filters updated:', data);
            })
            .catch(error => {
                console.error('Error updating filters:', error);
            });
        }

        // Select all message type checkboxes
        function selectAllMessages() {
            document.querySelectorAll('#messageTypeFilters input[type="checkbox"]')
                .forEach(input => input.checked = true);
            updateFilters();
        }

        // Deselect all message type checkboxes
        function deselectAllMessages() {
            document.querySelectorAll('#messageTypeFilters input[type="checkbox"]')
                .forEach(input => input.checked = false);
            updateFilters();
        }

        // Select all service checkboxes
        function selectAllServices() {
            document.querySelectorAll('#serviceFilters input[type="checkbox"]')
                .forEach(input => input.checked = true);
            updateFilters();
        }

        // Deselect all service checkboxes
        function deselectAllServices() {
            document.querySelectorAll('#serviceFilters input[type="checkbox"]')
                .forEach(input => input.checked = false);
            updateFilters();
        }

        // Clear all messages from display
        function clearMessages() {
            const messageDisplay = document.getElementById('messageDisplay');
            messageDisplay.innerHTML = '<div class="loading">Waiting for messages...</div>';
            messageCount = 0;
        }

        // Cleanup on page unload
        window.addEventListener('beforeunload', function() {
            if (pollingInterval) {
                clearInterval(pollingInterval);
            }
        });
    </script>
</body>
</html>
    HTML
  end

  # API endpoint to get available filters
  get '/api/filters' do
    content_type :json
    {
      message_types: MESSAGE_TYPES,
      services: CITY_SERVICES
    }.to_json
  end

  # API endpoint to update filters
  post '/api/filters' do
    content_type :json

    begin
      data = JSON.parse(request.body.read)

      # Update message type filters
      if data['message_types']
        settings.message_filters[:message_types] = Set.new(data['message_types'])
      end

      # Update service filters
      if data['services']
        settings.message_filters[:services] = Set.new(data['services'])
      end

      settings.logger.info "Filters updated - Messages: #{settings.message_filters[:message_types].to_a}, Services: #{settings.message_filters[:services].to_a}"

      { status: 'success', filters: settings.message_filters }.to_json
    rescue JSON::ParserError => e
      status 400
      { error: 'Invalid JSON' }.to_json
    end
  end

  # API endpoint to poll for new messages
  get '/api/messages' do
    content_type :json

    since = params['since'] ? Time.parse(params['since']) : Time.now - 3600

    # Get filtered messages from buffer
    filtered_messages = []

    settings.buffer_lock.synchronize do
      settings.message_buffer.each do |msg|
        begin
          # Parse timestamp string to Time for comparison
          msg_time = Time.parse(msg[:timestamp])
          next if msg_time <= since
        rescue => e
          # If timestamp parsing fails, include the message (safer default)
          settings.logger.warn "Error parsing timestamp #{msg[:timestamp]}: #{e.message}"
        end

        if self.class.should_display_message?(msg[:message_type], msg[:from], msg[:to])
          filtered_messages << msg
        end
      end
    end

    {
      messages: filtered_messages,
      timestamp: Time.now.iso8601
    }.to_json
  end

  # Start Redis subscription in background thread
  def self.start_redis_subscriber
    Thread.new do
      begin
        # Subscribe to all SmartMessage channels using pattern
        settings.subscriber.psubscribe('Messages::*') do |on|
          on.pmessage do |pattern, channel, message|
            begin
              # Parse the message
              parsed_message = JSON.parse(message)

              # Extract message metadata
              message_type = extract_message_type(parsed_message)
              from_service = parsed_message.dig('_sm_header', 'from') || parsed_message.dig('headers', 'from') || 'unknown'
              to_service = parsed_message.dig('_sm_header', 'to') || parsed_message.dig('headers', 'to') || 'broadcast'

              # Prepare message for buffer
              display_message = {
                timestamp: Time.now.iso8601,
                channel: channel,
                message_type: message_type,
                from: from_service,
                to: to_service,
                content: parsed_message,
                raw_message: message
              }

              # Add to buffer
              add_to_buffer(display_message)

            rescue JSON::ParserError => e
              # Handle non-JSON messages
              display_message = {
                timestamp: Time.now.iso8601,
                channel: channel,
                message_type: 'RawMessage',
                from: 'unknown',
                to: 'unknown',
                content: { raw: message },
                error: 'Non-JSON message'
              }
              add_to_buffer(display_message)
            rescue => e
              settings.logger.error "Error processing message: #{e.message}"
            end
          end
        end
      rescue => e
        settings.logger.error "Redis subscription error: #{e.message}"
        sleep 5
        retry
      end
    end
  end

  private

  def self.extract_message_type(parsed_message)
    # Try to extract message type from various places
    parsed_message.dig('_sm_header', 'message_class') ||
    parsed_message.dig('headers', 'message_class') ||
    parsed_message.dig('type') ||
    parsed_message.dig('class') ||
    'UnknownMessage'
  end

  def self.add_to_buffer(message)
    settings.buffer_lock.synchronize do
      settings.message_buffer << message

      # Keep buffer size manageable
      if settings.message_buffer.size > settings.buffer_size
        settings.message_buffer.shift
      end
    end
  end

  def self.should_display_message?(message_type, from_service, to_service)
    message_filters = settings.message_filters

    # If no filters are set, show NO messages (both filters default to unselected)
    return false if message_filters[:message_types].empty? && message_filters[:services].empty?

    # Check message type filter
    message_type_match = message_filters[:message_types].empty? ||
                        message_filters[:message_types].include?(message_type)

    # Check service filter (check both from and to, plus broadcast)
    service_match = message_filters[:services].empty? ||
                   message_filters[:services].include?(from_service) ||
                   message_filters[:services].include?(to_service) ||
                   to_service == 'broadcast'

    message_type_match && service_match
  end

  # Start the Redis subscriber when the app starts
  start_redis_subscriber

  run! if app_file == $0
end

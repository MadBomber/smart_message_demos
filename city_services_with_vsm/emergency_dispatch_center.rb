#!/usr/bin/env ruby
# examples/multi_program_demo/emergency_dispatch_center.rb

require 'smart_message'
require_relative 'messages/emergency_911_message'
require_relative 'messages/fire_emergency_message'
require_relative 'messages/silent_alarm_message'
require_relative 'messages/service_request_message'
require_relative 'messages/department_announcement_message'
require_relative 'messages/department_change_notification_message'

require_relative 'common/health_monitor'
require_relative 'common/logger'
require_relative 'common/status_line'

require 'ruby_llm'
require 'json'

class EmergencyDispatchCenter
  include Common::HealthMonitor
  include Common::Logger
  include Common::StatusLine

  def initialize
    @service_name = 'emergency-dispatch-center'

    @status = 'healthy'
    @start_time = Time.now
    @call_counter = 0
    @active_calls = {}
    @dispatch_stats = Hash.new(0)
    @available_departments = discover_departments
    @department_routing = {} # Track routing changes from consolidations/terminations
    @fallback_departments = {} # Track fallback routing for terminated departments

    setup_ai
    setup_messaging
    setup_signal_handlers
    setup_health_monitor
  end
  
  def setup_ai
    begin
      RubyLLM.configure do |config|
        config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
        config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
        config.log_file = "log/#{@service_name}_llm.log"
        config.log_level = :info
      end
      @llm = RubyLLM.chat
      @ai_available = true
      logger.info("AI model initialized for Emergency Dispatch")
    rescue => e
      @ai_available = false
      logger.warn("AI not available: #{e.message}. Using fallback department mapping.")
    end
  end

  def discover_departments
    # Discover available departments by looking at *_department.yml config files
    # Note: With the new architecture, departments are defined by YAML configs
    # and run via: ruby generic_department.rb <department_name>
    yaml_deps = Dir.glob('*_department.yml').map do |file|
      File.basename(file, '.yml')
    end
    
    # Also include legacy Ruby file departments for backward compatibility
    rb_deps = Dir.glob('*_department.rb').select do |file|
      !file.include?('generic_department.rb') # Exclude the template
    end.map do |file|
      File.basename(file, '.rb')  
    end
    
    (yaml_deps + rb_deps).uniq
  end


  def setup_messaging
    Messages::Emergency911Message.from(@service_name)
    Messages::FireEmergencyMessage.from(@service_name)
    Messages::SilentAlarmMessage.from(@service_name)
    Messages::ServiceRequestMessage.from(@service_name)
    Messages::DepartmentAnnouncementMessage.from(@service_name)
    Messages::DepartmentChangeNotificationMessage.from(@service_name)

    # Subscribe to 911 emergency calls
    Messages::Emergency911Message.subscribe(to: '911') do |message|
      handle_emergency_call(message)
    end

    # Subscribe to department announcements from City Council
    Messages::DepartmentAnnouncementMessage.subscribe do |message|
      handle_department_announcement(message)
    end

    # Subscribe to department change notifications (consolidations/terminations)
    Messages::DepartmentChangeNotificationMessage.subscribe(to: @service_name) do |message|
      handle_department_change_notification(message)
    end

    puts '📞 Emergency Dispatch Center (911) operational'
    puts '   🤖 AI-powered department routing enabled' if @ai_available
    puts '   📋 Using fallback logic when AI unavailable' unless @ai_available
    puts "   🏢 Available departments: #{@available_departments.join(', ')}"
    puts '   🏛️ Will request new departments from City Council as needed'
    puts '   📡 Subscribed to department announcements from City Council'
    puts '   🔄 Subscribed to department change notifications'
    puts '   📝 Logging to: emergency_dispatch_center.log'
    puts "   Press Ctrl+C to stop\n\n"
    logger.info("Emergency Dispatch Center ready - #{@available_departments.size} departments available, AI: #{@ai_available ? 'enabled' : 'disabled'}")
  end


  def get_status_details
    [@status, @details]
  end

  def setup_signal_handlers
    %w[INT TERM].each do |signal|
      Signal.trap(signal) do
        puts "\n📞 Emergency Dispatch Center going offline..."
        show_statistics
        logger.info('Emergency Dispatch Center shutting down')
        exit(0)
      end
    end
  end


  def run
    puts '📞 Emergency Dispatch Center listening for 911 calls...'
    
    # Start a thread to periodically check for new departments
    Thread.new do
      loop do
        sleep 30  # Check every 30 seconds
        check_for_new_departments
      end
    end
    
    loop do
      sleep 1
      @status = 'healthy'
    end
  rescue StandardError => e
    puts "📞 Error in dispatch center: #{e.message}"
    logger.error({alert:"Error in dispatch center", message: e.message, traceback: e.backtrace})
    logger.error(e.backtrace.join("\n"))
  end
  
  def check_for_new_departments
    current_departments = discover_departments
    new_departments = current_departments - @available_departments
    
    if new_departments.any?
      puts "\n📞 NEW DEPARTMENTS DETECTED: #{new_departments.join(', ')}"
      logger.info("New departments available: #{new_departments.join(', ')}")
      @available_departments = current_departments
    end
  end
  
  def handle_department_announcement(announcement)
    case announcement.status
    when 'created'
      logger.info("City Council created new department: #{announcement.department_name}")
      puts "\n🏛️ CITY COUNCIL: Created #{announcement.department_name}"
      
    when 'launched'
      logger.info("City Council launched new department: #{announcement.department_name} (PID: #{announcement.process_id})")
      puts "\n🚀 CITY COUNCIL: Launched #{announcement.department_name} (PID: #{announcement.process_id})"
      
      # Immediately add to our available departments list
      unless @available_departments.include?(announcement.department_name)
        @available_departments << announcement.department_name
        puts "📞 DISPATCH: Now routing calls to #{announcement.department_name}"
        logger.info("Added #{announcement.department_name} to available departments")
      end
      
    when 'failed'
      logger.error("City Council failed to create department: #{announcement.department_name} - #{announcement.description}")
      puts "\n❌ CITY COUNCIL: Failed to create #{announcement.department_name}"
      puts "   Error: #{announcement.description}"
      
    when 'active'
      # Department is fully operational
      unless @available_departments.include?(announcement.department_name)
        @available_departments << announcement.department_name
        logger.info("Department now active: #{announcement.department_name}")
        puts "\n✅ DEPARTMENT ACTIVE: #{announcement.department_name}"
      end
    end
  rescue => e
    logger.error("Error handling department announcement: #{e.message}")
  end

  private

  def handle_emergency_call(call)
    @call_counter += 1
    call_id = "911-#{Time.now.strftime('%Y%m%d-%H%M%S')}-#{@call_counter.to_s.rjust(4, '0')}"

    # Color code based on severity
    severity_color = case call.severity
                     when 'critical' then "\e[91m" # Bright red
                     when 'high' then "\e[31m"     # Red
                     when 'medium' then "\e[33m"   # Yellow
                     else "\e[32m"                 # Green
                     end

    puts "\n#{severity_color}📞 911 CALL RECEIVED\e[0m ##{call_id}"
    puts "   📍 Location: #{call.caller_location}"
    puts "   🚨 Type: #{call.emergency_type.upcase}"
    puts "   📝 Description: #{call.description}"
    puts "   ⚠️  Severity: #{call.severity&.upcase || 'UNKNOWN'}"
    puts "   👤 Caller: #{call.caller_name || 'Anonymous'} (#{call.caller_phone || 'No phone'})"

    logger.warn("911 CALL #{call_id}: #{call.emergency_type} at #{call.caller_location} - #{call.description}")

    @active_calls[call_id] = {
      call: call,
      received_at: Time.now,
      dispatched_to: []
    }

    # Determine which departments to dispatch to
    departments_to_dispatch = determine_dispatch_departments(call)

    puts "   🚨 Dispatching to: #{departments_to_dispatch.join(', ')}"

    # Route to appropriate departments
    departments_to_dispatch.each do |dept|
      route_to_department(call, dept, call_id)
      @dispatch_stats[dept] += 1
    end

    # After a delay, consider the call handled
    Thread.new do
      sleep(rand(60..180)) # Simulate response time
      if @active_calls[call_id]
        puts "📞 Call #{call_id} marked as handled"
        logger.info("Call #{call_id} handled after #{(Time.now - @active_calls[call_id][:received_at]).round} seconds")
        @active_calls.delete(call_id)
      end
    end
  rescue StandardError => e
    puts "📞 Error handling 911 call: #{e.message} #{e.backtrace.join("\n")}"
    logger.error({alert:"Error handling 911 call", message: e.message, traceback: e.backtrace})
  end


  def determine_dispatch_departments(call)
    # Use AI to determine which departments should handle this emergency
    required_departments = if @ai_available
                             ai_determine_departments(call)
                           else
                             fallback_determine_departments(call)
                           end

    available_departments = []
    missing_departments = []

    # Check which departments exist and which need to be created
    required_departments.each do |dept_name|
      if department_exists?(dept_name)
        available_departments << dept_name
      else
        missing_departments << dept_name
      end
    end

    # Request missing departments from city council
    if missing_departments.any?
      request_new_departments(call, missing_departments)
    end

    # If no specific departments available, default to police if it exists
    if available_departments.empty? && department_exists?('police_department')
      available_departments << 'police_department'
    end

    available_departments
  end

  def ai_determine_departments(call)
    available_depts = @available_departments.join(', ')
    
    # Common city department types for AI reference
    common_departments = [
      'police_department', 'fire_department', 'health_department',
      'water_management_department', 'utilities_department', 'sanitation_department',
      'transportation_department', 'parks_recreation_department', 'building_inspection_department',
      'animal_control_department', 'environmental_services_department', 'public_works_department'
    ]

    prompt = <<~PROMPT
      Analyze this 911 emergency call and determine which city departments should handle it:
      
      EMERGENCY CALL:
      Type: #{call.emergency_type}
      Description: #{call.description}
      Location: #{call.caller_location}
      Severity: #{call.severity}
      Injuries: #{call.injuries_reported || 'none reported'}
      Fire involved: #{call.fire_involved || false}
      Weapons involved: #{call.weapons_involved || false}
      Hazardous materials: #{call.hazardous_materials || false}
      Vehicles involved: #{call.vehicles_involved || 0}
      Suspects: #{call.suspects_on_scene || false}
      
      CURRENTLY AVAILABLE DEPARTMENTS:
      #{available_depts.empty? ? 'None' : available_depts}
      
      COMMON CITY DEPARTMENTS:
      #{common_departments.join(', ')}
      
      Instructions:
      1. Determine which department(s) would typically handle this type of emergency
      2. Use standard city department naming with underscores (e.g., "water_management_department")
      3. Consider the severity and specific needs of the situation
      4. You can suggest departments even if they don't currently exist
      
      Respond with ONLY a JSON array of department names:
      ["department_name_1", "department_name_2"]
    PROMPT

    begin
      response = @llm.ask(prompt)
      departments = JSON.parse(response.content)
      
      # Validate response format
      unless departments.is_a?(Array) && departments.all? { |d| d.is_a?(String) }
        raise "Invalid department list format"
      end
      
      logger.info("AI determined departments: #{departments.join(', ')}")
      departments
    rescue => e
      logger.error("AI department determination failed: #{e.message}")
      fallback_determine_departments(call)
    end
  end

  def fallback_determine_departments(call)
    departments = []
    
    # Check for specifically requested department first
    if call.requested_department && !call.requested_department.empty?
      departments << call.requested_department
      return departments
    end
    
    # Basic emergency categorization
    case call.emergency_type&.downcase
    when 'fire', 'rescue'
      departments << 'fire_department'
    when 'crime', 'accident'
      departments << 'police_department'
    when 'medical'
      departments << 'fire_department' # EMS typically handled by fire
    when 'water_emergency'
      departments << 'water_department'
    when 'animal_emergency'
      departments << 'animal_control'
    when 'transportation_emergency'
      departments << 'transportation_department'
    when 'environmental_emergency'
      departments << 'environmental_services'
    when 'parks_emergency'
      departments << 'parks_department'
    when 'sanitation_emergency'
      departments << 'sanitation_department'
    when 'infrastructure', 'infrastructure_emergency'
      # Analyze description for specific infrastructure type
      desc = call.description&.downcase || ''
      if desc.match?(/water|sewer|pipe|hydrant/)
        departments << 'water_management_department'
      elsif desc.match?(/power|electric|gas|utility/)
        departments << 'utilities_department'
      elsif desc.match?(/road|street|traffic|bridge/)
        departments << 'transportation_department'
      else
        departments << 'public_works_department'
      end
    when 'other'
      # Try to categorize based on description
      desc = call.description&.downcase || ''
      if desc.match?(/animal|dog|cat|wildlife/)
        departments << 'animal_control_department'
      elsif desc.match?(/building|structure|construction/)
        departments << 'building_inspection_department'
      elsif desc.match?(/park|tree|playground/)
        departments << 'parks_recreation_department'
      else
        departments << 'police_department' # Default fallback
      end
    else
      departments << 'police_department' # Ultimate fallback
    end
    
    # Always include police for serious emergencies
    if (call.weapons_involved || call.suspects_on_scene || 
        call.severity == 'critical') && !departments.include?('police_department')
      departments << 'police_department'
    end
    
    # Include fire for injuries or hazmat
    if (call.injuries_reported || call.hazardous_materials || 
        call.fire_involved) && !departments.include?('fire_department')
      departments << 'fire_department'
    end

    logger.info("Fallback determined departments: #{departments.join(', ')}")
    departments
  end
  
  def department_exists?(dept_name)
    @available_departments.include?(dept_name)
  end
  
  def request_new_departments(call, needed_departments)
    puts "\n🏛️ FORWARDING TO CITY COUNCIL - Missing departments: #{needed_departments.join(', ')}"
    logger.warn("Missing departments for call: #{needed_departments.join(', ')}")
    
    # Send service request to city council
    needed_departments.each do |dept|
      # Convert department name to service name (remove _department suffix for description)
      service_name = dept.gsub('_department', '').gsub('_', ' ')
      
      request = Messages::ServiceRequestMessage.new(
        requesting_service: @service_name,
        emergency_type: call.emergency_type,
        description: "Need #{service_name} department to handle: #{call.description}",
        urgency: call.severity || 'high',
        original_call_id: call._sm_header.uuid,
        details: {
          department_needed: dept,
          original_call: call.to_h,
          reason: "911 emergency requiring #{service_name} department",
          ai_determined: @ai_available
        }
      )
      request._sm_header.from = @service_name
      request._sm_header.to = 'city_council'
      request.publish
      
      logger.info("Requested new department from City Council: #{dept}")
    end
  end


  def route_to_department(call, department, call_id)
    # Check if this department has been consolidated or terminated
    actual_department = resolve_department_routing(department)

    if actual_department != department
      puts "   🔄 Routing redirected: #{department} → #{actual_department}"
      logger.info("Routing redirected from #{department} to #{actual_department} due to department changes")
    end

    case actual_department
    when 'fire_department'
      # Only convert to FireEmergencyMessage for actual fire emergencies
      if call.emergency_type == 'fire'
        fire_msg = Messages::FireEmergencyMessage.new(
          house_address: call.caller_location,
          fire_type: determine_fire_type(call),
          severity: call.severity || 'medium',
          occupants_status: build_occupants_status(call),
          spread_risk: call.hazardous_materials ? 'high' : 'medium',
          timestamp: call._sm_header.published_at,
          emergency_id: call_id
        )
        fire_msg._sm_header.from = '911-dispatch'
        fire_msg._sm_header.to   = 'fire_department'
        fire_msg.publish
        logger.info("Routed call #{call_id} to Fire Department as fire emergency")
      else
        # For medical, rescue, accidents with fire, hazmat - forward the 911 call directly
        forward_call = Messages::Emergency911Message.new(**call.to_h.merge(
                                                           call_id: call_id,
                                                           from: '911-dispatch',
                                                           to: 'fire_department'
                                                         ))
        forward_call._sm_header.from = '911-dispatch'
        forward_call._sm_header.to   = 'fire_department'
        forward_call.publish
        logger.info("Forwarded call #{call_id} to Fire Department for #{call.emergency_type}")
      end

    when 'police_department'
      # Forward all police calls directly as Emergency911Message
      forward_call = Messages::Emergency911Message.new(**call.to_h.merge(
                                                         call_id: call_id,
                                                         from: '911-dispatch',
                                                         to: 'police_department'
                                                       ))
      forward_call._sm_header.from = '911-dispatch'
      forward_call._sm_header.to   = 'police_department'
      forward_call.publish
      
      if call.emergency_type == 'crime' || call.weapons_involved || call.suspects_on_scene
        logger.info("Routed call #{call_id} to Police Department as crime report")
      else
        logger.info("Forwarded call #{call_id} to Police Department")
      end
    else
      # Generic department routing - forward Emergency911Message to any department
      forward_call = Messages::Emergency911Message.new(**call.to_h.merge(
                                                         call_id: call_id,
                                                         from: '911-dispatch',
                                                         to: department
                                                       ))
      forward_call._sm_header.from = '911-dispatch'
      forward_call._sm_header.to   = department
      forward_call.publish
      
      logger.info("Forwarded call #{call_id} to #{department} (generic department)")
      puts "🚨 Dispatching to #{department}: #{call.emergency_type} at #{call.caller_location}"
    end

    @active_calls[call_id][:dispatched_to] << department if @active_calls[call_id]
  rescue StandardError => e
    logger.error({alert:"Error routing to #{department}", message: e.message, trace: e.backtrace})
    raise
  end


  def determine_fire_type(call)
    return 'chemical' if call.hazardous_materials
    return 'vehicle' if call.vehicles_involved && call.vehicles_involved > 0

    desc = call.description.downcase
    return 'electrical' if desc.include?('electrical') || desc.include?('wire')
    return 'grease' if desc.include?('kitchen') || desc.include?('grease')
    return 'chemical' if desc.include?('chemical') || desc.include?('gas')

    'general'
  end


  def determine_alarm_type(call)
    return 'armed_robbery' if call.weapons_involved
    return 'break_in' if call.description =~ /break.?in/i
    return 'assault' if call.description =~ /assault|attack/i
    return 'robbery' if call.description =~ /robbery|theft/i

    'suspicious_activity'
  end


  def build_occupants_status(call)
    if call.injuries_reported
      "#{call.number_of_victims || 'Unknown number of'} injured"
    elsif call.number_of_victims && call.number_of_victims > 0
      "#{call.number_of_victims} people involved"
    else
      'Unknown'
    end
  end


  def show_statistics
    puts "\n📊 Dispatch Statistics:"
    puts "   Total 911 calls handled: #{@call_counter}"
    puts "   Active calls: #{@active_calls.size}"
    puts '   Dispatches by department:'
    @dispatch_stats.each do |dept, count|
      puts "     #{dept}: #{count}"
    end
  end

  def handle_department_change_notification(notification)
    logger.info("Received department change notification: #{notification.change_type}")

    puts "\n🔔 DEPARTMENT CHANGE NOTIFICATION"
    puts "   Type: #{notification.change_type.upcase}"
    puts "   Affected: #{notification.affected_departments.join(', ')}"
    puts "   Effective: #{notification.effective_immediately ? 'IMMEDIATELY' : notification.effective_date}"

    case notification.change_type
    when 'consolidated'
      handle_consolidation(notification)
    when 'terminated'
      handle_termination(notification)
    when 'created'
      handle_new_department(notification)
    when 'renamed'
      handle_rename(notification)
    end

    # Update available departments
    @available_departments = discover_departments
    puts "   🏢 Updated department list: #{@available_departments.join(', ')}"
    logger.info("Updated available departments after #{notification.change_type}: #{@available_departments.size} total")
  end

  def handle_consolidation(notification)
    puts "   🔀 CONSOLIDATION: #{notification.affected_departments.join(' + ')} → #{notification.new_department}"

    # Update routing table
    notification.routing_changes.each do |old_dept, new_dept|
      @department_routing[old_dept] = new_dept
      logger.info("Routing update: #{old_dept} now routes to #{new_dept}")
    end

    # Update fallback
    if notification.fallback_department
      @fallback_departments[notification.new_department] = notification.fallback_department
    end

    # Log affected emergency types
    if notification.emergency_types_affected.any?
      puts "   ⚠️  Affected emergency types: #{notification.emergency_types_affected.join(', ')}"
    end
  end

  def handle_termination(notification)
    terminated_dept = notification.affected_departments.first
    puts "   ❌ TERMINATION: #{terminated_dept}"

    # Update routing for terminated department
    notification.routing_changes.each do |old_dept, new_dept|
      @department_routing[old_dept] = new_dept
      puts "   ↪️  Calls will be routed to: #{new_dept}"
      logger.info("Department terminated: #{old_dept} now routes to #{new_dept}")
    end

    # Set fallback
    if notification.fallback_department
      @fallback_departments[terminated_dept] = notification.fallback_department
    end

    # Alert about affected emergency types
    if notification.emergency_types_affected.any?
      puts "   ⚠️  Affected emergency types: #{notification.emergency_types_affected.join(', ')}"
      puts "   📋 #{notification.additional_instructions}" if notification.additional_instructions
    end
  end

  def handle_new_department(notification)
    new_dept = notification.new_department
    puts "   ✅ NEW DEPARTMENT: #{new_dept}"

    # Remove any routing overrides for this new department
    @department_routing.delete(new_dept)

    # Add to available departments if not already there
    @available_departments << new_dept unless @available_departments.include?(new_dept)

    logger.info("New department added: #{new_dept}")
  end

  def handle_rename(notification)
    old_name = notification.affected_departments.first
    new_name = notification.new_department
    puts "   ✏️  RENAME: #{old_name} → #{new_name}"

    # Update routing
    @department_routing[old_name] = new_name

    # Update any existing routing that pointed to old name
    @department_routing.each do |dept, target|
      @department_routing[dept] = new_name if target == old_name
    end

    logger.info("Department renamed: #{old_name} to #{new_name}")
  end

  def resolve_department_routing(department)
    # Check if this department has been rerouted
    resolved = department
    visited = Set.new

    # Follow routing chain (handle multi-level consolidations)
    while @department_routing.key?(resolved) && !visited.include?(resolved)
      visited.add(resolved)
      resolved = @department_routing[resolved]
    end

    # If department doesn't exist and we have a fallback, use it
    if !@available_departments.include?(resolved) && @fallback_departments[department]
      resolved = @fallback_departments[department]
      logger.warn("Department #{department} not available, using fallback: #{resolved}")
    end

    resolved
  end
end

# Run the dispatch center
if __FILE__ == $0
  dispatch = EmergencyDispatchCenter.new
  dispatch.run
end

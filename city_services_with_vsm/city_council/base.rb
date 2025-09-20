#!/usr/bin/env ruby
# city_council/base.rb
#

require 'async'
require 'date'
require_relative '../common/status_line'

# Main CityCouncil Class
module CityCouncil
  class Base
    # include Common::HealthMonitor
    include Common::Logger
    include Common::StatusLine

    attr_reader :capsule, :existing_departments

    def initialize
      @service_name = "city_council"
      @status = "healthy"
      @start_time = Time.now
      @existing_departments = discover_departments
      @department_processes = {} # Track launched department PIDs
      @last_doge_analysis = nil # Track when we last requested DOGE analysis
      @doge_analysis_interval = 300 # Request analysis every 5 minutes (for demo)

      setup_signal_handlers
      # setup_health_monitor
      setup_vsm_capsule
      setup_messaging

      logger.info("CityCouncil initialized with #{@existing_departments.size} existing departments")
    end

    def discover_departments
      logger.debug("Discovering existing departments in current directory")

      # Discover Ruby-based departments
      ruby_departments = Dir.glob("*_department.rb").map do |file|
        File.basename(file, ".rb")
      end

      # Discover YAML-configured departments
      yaml_departments = Dir.glob("*_department.yml").map do |file|
        File.basename(file, ".yml")
      end

      # Combine both types
      departments = (ruby_departments + yaml_departments).sort.uniq

      logger.info("Discovered #{departments.size} existing departments:")
      logger.info("  Ruby-based: #{ruby_departments.size} (#{ruby_departments.join(", ")})")
      logger.info("  YAML-configured: #{yaml_departments.size} (#{yaml_departments.join(", ")})")
      logger.info("  Total unique: #{departments.join(", ")}")

      departments
    end

    def setup_vsm_capsule
      logger.info("Setting up VSM capsule for CityCouncil")

      # Capture reference to CityCouncil instance before entering DSL block
      council_instance = self

      @capsule = VSM::DSL.define(:city_council) do
        identity klass: VSM::Identity,
                 args: {
                   identity: "city_council",
                   invariants: ["must serve citizens", "create needed services", "maintain city operations"],
                 }

        governance klass: CityCouncil::Governance
        coordination klass: VSM::Coordination
        intelligence klass: CityCouncil::Intelligence, args: { council: council_instance }
        operations klass: CityCouncil::Operations, args: { council: council_instance }
      end

      logger.info("VSM capsule setup completed successfully")

      # Set up VSM bus subscriptions after capsule is ready
      setup_vsm_subscriptions
    end

    def setup_messaging
      logger.info("Setting up SmartMessage subscriptions for CityCouncil")

      # Set up SmartMessage subscriptions for council requests
      if defined?(Messages::ServiceRequestMessage)
        logger.info("Subscribing to ServiceRequestMessage")
        Messages::ServiceRequestMessage.subscribe(to: @service_name) do |message|
          handle_service_request(message)
        end
      else
        logger.warn("ServiceRequestMessage not available for subscription")
      end

      # Subscribe to DOGE consolidation recommendations
      if defined?(Messages::ConsolidationRecommendationMessage)
        logger.info("Subscribing to ConsolidationRecommendationMessage")
        Messages::ConsolidationRecommendationMessage.subscribe(to: @service_name) do |message|
          handle_consolidation_recommendation(message)
        end
      else
        logger.warn("ConsolidationRecommendationMessage not available for subscription")
      end

      # Subscribe to DOGE termination recommendations
      if defined?(Messages::TerminationRecommendationMessage)
        logger.info("Subscribing to TerminationRecommendationMessage")
        Messages::TerminationRecommendationMessage.subscribe(to: @service_name) do |message|
          handle_termination_recommendation(message)
        end
      else
        logger.warn("TerminationRecommendationMessage not available for subscription")
      end

      # Subscribe to health checks
      if defined?(Messages::HealthCheckMessage)
        logger.info("Subscribing to HealthCheckMessage")
        Messages::HealthCheckMessage.subscribe(to: @service_name) do |message|
          respond_to_health_check(message)
        end
      else
        logger.warn("HealthCheckMessage not available for subscription")
      end

      # Subscribe to health status responses from departments
      if defined?(Messages::HealthStatusMessage)
        Messages::HealthStatusMessage.from(@service_name)

        logger.info("Subscribing to HealthStatusMessage responses")
        Messages::HealthStatusMessage.subscribe(to: @service_name) do |message|
          handle_department_health_response(message)
        end
      else
        logger.warn("HealthStatusMessage not available for subscription")
      end

      logger.info("SmartMessage subscriptions setup completed")
    end

    def setup_signal_handlers
      %w[INT TERM].each do |signal|
        Signal.trap(signal) do
          restore_terminal if respond_to?(:restore_terminal)
          puts "\n🏛️ CityCouncil shutting down..."
          logger.info("CityCouncil shutting down")
          cleanup_department_processes
          exit(0)
        end
      end
    end

    def cleanup_department_processes
      unless @department_processes.empty?
        puts "🧹 Cleaning up #{@department_processes.size} department processes..."
        @department_processes.each do |dept_name, pid|
          begin
            Process.kill("TERM", pid)
            logger.info("Terminated #{dept_name} (PID: #{pid})")
          rescue Errno::ESRCH
            # Process already dead
          rescue => e
            logger.warn("Failed to terminate #{dept_name} (PID: #{pid}): #{e.message}")
          end
        end
      end
    end

    def handle_service_request(message)
      logger.info("Received service request from #{message._sm_header.from}")
      logger.debug("Service request details: #{message.inspect}")

      puts "🏛️ 📨 CityCouncil: Received service request from #{message._sm_header.from}"

      # Process the service request with VSM Intelligence
      payload = message.details[:description] || message.description || message.inspect
      logger.info("Processing service request with VSM Intelligence: #{payload}")

      puts "🏛️ 🧠 CityCouncil: Processing request with VSM Intelligence..."
      puts "🏛️ 📋 Request content: #{payload.to_s.slice(0, 100)}#{payload.to_s.length > 100 ? '...' : ''}"

      status_line("Processing request from #{message._sm_header.from}")

      # Create VSM message and process with Intelligence
      vsm_message = VSM::Message.new(
        kind: :service_request,
        payload: payload,
        meta: { msg_id: message._sm_header.uuid }
      )

      # Process with Intelligence component
      puts "🏛️ 🎯 CityCouncil: Forwarding to Intelligence component..."
      intelligence_result = @capsule.roles[:intelligence].handle(vsm_message, bus: @capsule.bus)
      logger.debug("VSM Intelligence processing result: #{intelligence_result}")
      puts "🏛️ ✅ CityCouncil: Intelligence processing #{intelligence_result ? 'completed' : 'failed'}"

      status_line("Governing #{@existing_departments.size} departments")
    end

    # Set up VSM bus message subscriptions
    def setup_vsm_subscriptions
      logger.info("Setting up VSM bus subscriptions for CityCouncil")
      puts "🏛️ 🚌 CityCouncil: Setting up VSM bus subscriptions..."
      puts "🏛️ 🚌 Bus object ID: #{@capsule.bus.object_id}"
      # Subscribe to create_service messages and forward to Operations
      @capsule.bus.subscribe do |vsm_message|
        logger.debug("VSM Bus: Received message - kind=#{vsm_message.kind}")
        puts "🏛️ 🚌 VSM Bus: Received #{vsm_message.kind} message"
        case vsm_message.kind
        when :create_service
          # Forward to Operations component
          logger.info("VSM Bus: Forwarding create_service message to Operations component")
          logger.debug("VSM Bus: create_service payload: #{vsm_message.payload}")
          puts "🏛️ 🏗️ CityCouncil: VSM Bus routing create_service to Operations..."
          puts "🏛️ 📄 Service spec: #{vsm_message.payload[:spec][:name] rescue 'unknown'}"
          operations_result = @capsule.roles[:operations].handle(vsm_message, bus: @capsule.bus)
          logger.debug("VSM Bus: Operations processing result: #{operations_result}")
          puts "🏛️ 🔧 CityCouncil: Operations #{operations_result ? 'succeeded' : 'failed'} in handling create_service"
        when :assistant
          # Log assistant responses
          logger.info("VSM Bus: Assistant response: #{vsm_message.payload}")
          puts "🏛️ 🤖 CityCouncil: VSM Assistant response: #{vsm_message.payload.to_s.slice(0, 80)}#{vsm_message.payload.to_s.length > 80 ? '...' : ''}"
        else
          logger.debug("VSM Bus: Unhandled message kind: #{vsm_message.kind}")
          puts "🏛️ ❓ CityCouncil: Unhandled VSM message kind: #{vsm_message.kind}"
        end
      end
    end

    def register_new_department(department_name, process_id = nil)
      dept_full_name = "#{department_name}_department"
      @existing_departments << dept_full_name unless @existing_departments.include?(dept_full_name)

      if process_id
        @department_processes[dept_full_name] = process_id
      end

      logger.info("Registered new department: #{dept_full_name}#{process_id ? " (PID: #{process_id})" : ""}")
    end

    def update_department_pid(department_name, new_pid)
      dept_full_name = "#{department_name}_department"
      if @department_processes[dept_full_name]
        old_pid = @department_processes[dept_full_name]
        @department_processes[dept_full_name] = new_pid
        logger.info("Updated #{dept_full_name} PID: #{old_pid} → #{new_pid}")
      else
        @department_processes[dept_full_name] = new_pid
        logger.info("Added new PID for #{dept_full_name}: #{new_pid}")
      end
    end

    def start_governance
      logger.info("Starting CityCouncil governance operations")

      puts "🏛️ City Council Active"
      puts "📋 Governing #{@existing_departments.size} departments:"
      @existing_departments.each { |dept| puts "   - #{dept}" }
      puts "🔧 Ready to create new departments as needed"
      puts "👂 Listening for service requests..."

      status_line("Governing #{@existing_departments.size} departments")

      logger.info("CityCouncil governance started successfully")

      # Start main monitoring loop
      logger.info("Starting CityCouncil main monitoring loop")
      logger.info("VSM components available for direct processing")

      # Main loop
      loop do
        monitor_city_operations
        sleep(10)
      end
    rescue => e
      logger.error("Error in CityCouncil governance loop: #{e.message}")
      logger.error("Exception backtrace: #{e.backtrace.join("\n")}")
      logger.info("Restarting governance loop after error")
      retry
    end

    private

    def monitor_city_operations
      logger.debug("Monitoring city operations - checking for new departments")

      # Periodic check of city operations
      current_departments = discover_departments

      if current_departments.size > @existing_departments.size
        new_depts = current_departments - @existing_departments
        logger.info("New departments detected during monitoring: #{new_depts.join(", ")}")
        @existing_departments = current_departments
        status_line("Governing #{@existing_departments.size} departments (new: #{new_depts.first})")
      elsif current_departments.size < @existing_departments.size
        removed_depts = @existing_departments - current_departments
        logger.warn("Departments removed/missing: #{removed_depts.join(", ")}")
        @existing_departments = current_departments
        status_line("Governing #{@existing_departments.size} departments")
      end

      # Check department health status
      health_status = get_department_health_summary
      if health_status[:unhealthy_count] > 0 || health_status[:warning_count] > 0
        health_msg = []
        health_msg << "#{health_status[:unhealthy_count]} unhealthy" if health_status[:unhealthy_count] > 0
        health_msg << "#{health_status[:warning_count]} warning" if health_status[:warning_count] > 0

        logger.warn("CityCouncil: Department health issues - #{health_msg.join(', ')}")
        status_line("#{@existing_departments.size} departments (#{health_msg.join(', ')})")
      elsif health_status[:monitored_count] > 0
        logger.debug("CityCouncil: All #{health_status[:healthy_count]} monitored departments healthy")
      end

      old_status = @status
      @status = determine_health_status
      if old_status != @status
        logger.info("CityCouncil health status changed from #{old_status} to #{@status}")
        status_line("#{@status.upcase} - #{@existing_departments.size} departments")
      end

      # Periodically request DOGE analysis for efficiency review
      if should_request_doge_analysis?
        logger.info("Triggering periodic DOGE efficiency analysis")
        request_doge_analysis('periodic_audit')
        @last_doge_analysis = Time.now
      end
    end

    def should_request_doge_analysis?
      # Only request if we have departments to analyze
      return false if @existing_departments.size < 3

      # Check if enough time has passed since last analysis
      return true if @last_doge_analysis.nil?

      time_since_last = Time.now - @last_doge_analysis
      time_since_last >= @doge_analysis_interval
    end

    def get_department_health_summary
      return { healthy_count: 0, unhealthy_count: 0, monitored_count: 0 } unless @capsule&.roles&.[](:operations)

      health_status = @capsule.roles[:operations].get_department_health_status
      healthy_count = 0
      unhealthy_count = 0
      warning_count = 0

      health_status.each do |dept_name, health_info|
        case health_info[:status]
        when 'running'
          if health_info[:process_healthy] && health_info[:responsive]
            healthy_count += 1
          elsif health_info[:process_healthy] || health_info[:responsive]
            warning_count += 1
          else
            unhealthy_count += 1
          end
        when 'permanently_failed'
          unhealthy_count += 1
        else
          warning_count += 1
        end
      end

      {
        healthy_count: healthy_count,
        unhealthy_count: unhealthy_count,
        warning_count: warning_count,
        monitored_count: health_status.size,
        details: health_status
      }
    end

    def determine_health_status
      # Health based on department count and responsiveness
      case @existing_departments.size
      when 0..2 then "critical"
      when 3..5 then "warning"
      else "healthy"
      end
    end

    def get_status_details
      @status = determine_health_status
      uptime = Time.now - @start_time
      details = {
        uptime: uptime.round(1),
        departments_count: @existing_departments.size,
        departments: @existing_departments,
        department_processes: @department_processes.size,
        ready: true,
      }
      [@status, details]
    end

    def respond_to_health_check(message)
      logger.info("Received health check from #{message._sm_header.from}")

      if defined?(Messages::HealthStatusMessage)
        uptime = Time.now - @start_time
        health_summary = get_department_health_summary
        status_msg = Messages::HealthStatusMessage.new(
          service_name: @service_name,
          check_id: message._sm_header.uuid,
          status: @status,
          details: {
            uptime: uptime,
            departments_count: @existing_departments.size,
            departments: @existing_departments,
            department_processes: @department_processes.size,
            health_summary: health_summary,
            ready: true,
          },
        )
        status_msg._sm_header.from = @service_name
        status_msg._sm_header.to = message._sm_header.from
        status_msg.publish

        logger.info("Responded to health check from #{message._sm_header.from}: #{@status} (#{@existing_departments.size} departments, #{uptime.round(1)}s uptime)")
      else
        logger.warn("HealthStatusMessage not available - cannot respond to health check")
      end
    end

    def handle_department_health_response(message)
      logger.debug("Received health status response from #{message._sm_header.from}")

      # Forward to Operations component for processing
      if @capsule&.roles&.[](:operations)
        dept_name = message.service_name || message._sm_header.from
        @capsule.roles[:operations].handle_health_response(dept_name, message)
        logger.debug("Forwarded health response from #{dept_name} to Operations")
      else
        logger.warn("Operations component not available to handle health response")
      end
    end

    def handle_consolidation_recommendation(message)
      logger.info("Received consolidation recommendation from #{message.analyzed_by}")
      puts "\n🏛️ 📥 CONSOLIDATION RECOMMENDATION RECEIVED"
      puts "   From: #{message.analyzed_by}"
      puts "   Proposed: #{message.proposed_name}"
      puts "   Departments to merge: #{message.departments_to_merge.join(', ')}"
      puts "   Similarity score: #{message.similarity_score}%"
      puts "   Est. savings: $#{message.estimated_annual_savings}"
      puts "   Priority: #{message.priority}"

      # Evaluate the recommendation
      decision = evaluate_consolidation_recommendation(message)

      # Send decision response
      send_council_decision(message.recommendation_id, 'consolidation', decision, message)
    end

    def handle_termination_recommendation(message)
      logger.info("Received termination recommendation from #{message.analyzed_by}")
      puts "\n🏛️ 📥 TERMINATION RECOMMENDATION RECEIVED"
      puts "   From: #{message.analyzed_by}"
      puts "   Department: #{message.department_name}"
      puts "   Reason: #{message.termination_reason}"
      puts "   Annual cost: $#{message.annual_cost}"
      puts "   Priority: #{message.priority}"

      # Evaluate the recommendation
      decision = evaluate_termination_recommendation(message)

      # Send decision response
      send_council_decision(message.recommendation_id, 'termination', decision, message)
    end

    def evaluate_consolidation_recommendation(recommendation)
      # Decision logic for consolidation recommendations
      logger.info("Evaluating consolidation recommendation: #{recommendation.proposed_name}")

      # Auto-approve high-similarity, high-savings recommendations
      if recommendation.similarity_score && recommendation.similarity_score > 70 &&
         recommendation.estimated_annual_savings && recommendation.estimated_annual_savings > 100000
        logger.info("Auto-approving high-value consolidation: #{recommendation.proposed_name}")
        'approved'
      # Defer medium-similarity recommendations for review
      elsif recommendation.similarity_score && recommendation.similarity_score > 50
        logger.info("Deferring medium-similarity consolidation for review: #{recommendation.proposed_name}")
        'deferred'
      # Reject low-similarity recommendations
      else
        logger.info("Rejecting low-similarity consolidation: #{recommendation.proposed_name}")
        'rejected'
      end
    end

    def evaluate_termination_recommendation(recommendation)
      # Decision logic for termination recommendations
      logger.info("Evaluating termination recommendation: #{recommendation.department_name}")

      # Critical departments should never be terminated
      critical_departments = ['police', 'fire', 'health', 'emergency_dispatch_center']
      if critical_departments.any? { |dept| recommendation.department_name.include?(dept) }
        logger.warn("Rejecting termination of critical department: #{recommendation.department_name}")
        return 'rejected'
      end

      # Auto-approve termination of unused/redundant departments
      if %w[redundant obsolete unused].include?(recommendation.termination_reason)
        logger.info("Auto-approving termination: #{recommendation.department_name} (#{recommendation.termination_reason})")
        'approved'
      else
        logger.info("Deferring termination for review: #{recommendation.department_name}")
        'deferred'
      end
    end

    def send_council_decision(recommendation_id, recommendation_type, decision, original_recommendation)
      logger.info("Sending council decision: #{decision} for #{recommendation_type} recommendation #{recommendation_id}")

      rationale = case decision
      when 'approved'
        "Recommendation approved based on cost-benefit analysis and efficiency goals"
      when 'rejected'
        "Recommendation rejected to maintain essential services or insufficient justification"
      when 'deferred'
        "Recommendation deferred pending further review and citizen input"
      else
        "Decision pending additional analysis"
      end

      message = Messages::CouncilDecisionMessage.new(
        recommendation_id: recommendation_id,
        recommendation_type: recommendation_type,
        decision: decision,
        decision_rationale: rationale,
        effective_date: (Date.today + 30).to_s, # 30 days from now
        council_vote: { for: 7, against: 2, abstain: 1 }, # Simulated vote
        decided_by: @service_name
      )

      # Send to DOGE system that made the recommendation
      message.to = original_recommendation.analyzed_by
      message.from = @service_name
      message.publish

      puts "🏛️ 📤 Council Decision Sent: #{decision.upcase}"
      puts "   Rationale: #{rationale}"

      # If approved, trigger implementation
      if decision == 'approved'
        implement_doge_recommendation(recommendation_type, original_recommendation)
      end
    end

    def implement_doge_recommendation(recommendation_type, recommendation)
      logger.info("Implementing approved #{recommendation_type} recommendation")

      case recommendation_type
      when 'consolidation'
        puts "🏛️ 🔨 Implementing consolidation: #{recommendation.proposed_name}"
        notify_department_consolidation(recommendation)
        # TODO: Actual consolidation implementation would happen here
        # This would involve creating the new consolidated department
        # and terminating the old ones
      when 'termination'
        puts "🏛️ 🔨 Terminating department: #{recommendation.department_name}"
        notify_department_termination(recommendation)
        # TODO: Actual termination implementation would happen here
        # This would involve stopping the department process and removing files
      end
    end

    def notify_department_consolidation(recommendation)
      logger.info("Notifying 911 dispatch of department consolidation")

      # Build routing changes map
      routing_changes = {}
      recommendation.departments_to_merge.each do |old_dept|
        routing_changes[old_dept] = recommendation.proposed_name
      end

      # Build capabilities mapping
      capabilities_mapping = {}
      if recommendation.unified_capabilities && recommendation.unified_capabilities.any?
        recommendation.departments_to_merge.each do |old_dept|
          capabilities_mapping[old_dept] = recommendation.unified_capabilities
        end
      end

      # Determine affected emergency types based on department names
      emergency_types = determine_affected_emergency_types(recommendation.departments_to_merge)

      notification = Messages::DepartmentChangeNotificationMessage.new(
        change_type: 'consolidated',
        affected_departments: recommendation.departments_to_merge,
        new_department: recommendation.proposed_name,
        routing_changes: routing_changes,
        capabilities_mapping: capabilities_mapping,
        emergency_types_affected: emergency_types,
        effective_immediately: false,
        effective_date: (Time.now + 86400).iso8601, # 24 hours from now
        fallback_department: 'emergency_dispatch_center',
        additional_instructions: "Departments #{recommendation.departments_to_merge.join(', ')} are being merged into #{recommendation.proposed_name}",
        initiated_by: @service_name
      )

      # Send to 911 dispatch center
      notification.to = 'emergency_dispatch_center'
      notification.from = @service_name
      notification.publish

      logger.info("Sent consolidation notification to emergency_dispatch_center")
      puts "🏛️ 📡 Notified 911 dispatch of consolidation: #{recommendation.proposed_name}"
    end

    def notify_department_termination(recommendation)
      logger.info("Notifying 911 dispatch of department termination")

      # Build routing changes - route to alternative departments or dispatch center
      routing_changes = {}
      fallback = determine_fallback_department(recommendation.department_name)
      routing_changes[recommendation.department_name] = fallback

      # Build reassignment mapping if services are being reassigned
      capabilities_mapping = {}
      if recommendation.services_to_reassign && recommendation.services_to_reassign.any?
        recommendation.services_to_reassign.each do |reassignment|
          capabilities_mapping[reassignment[:service]] = reassignment[:reassign_to]
        end
      end

      # Determine affected emergency types
      emergency_types = determine_affected_emergency_types([recommendation.department_name])

      notification = Messages::DepartmentChangeNotificationMessage.new(
        change_type: 'terminated',
        affected_departments: [recommendation.department_name],
        routing_changes: routing_changes,
        capabilities_mapping: capabilities_mapping,
        emergency_types_affected: emergency_types,
        effective_immediately: false,
        effective_date: (Time.now + 86400).iso8601, # 24 hours from now
        fallback_department: fallback,
        additional_instructions: "Department #{recommendation.department_name} is being terminated. Route calls to #{fallback}",
        initiated_by: @service_name,
        rollback_available: true,
        rollback_instructions: {
          action: 'restore_department',
          department: recommendation.department_name
        }
      )

      # Send to 911 dispatch center
      notification.to = 'emergency_dispatch_center'
      notification.from = @service_name
      notification.publish

      logger.info("Sent termination notification to emergency_dispatch_center")
      puts "🏛️ 📡 Notified 911 dispatch of termination: #{recommendation.department_name}"
    end

    def determine_affected_emergency_types(department_names)
      emergency_types = []

      department_names.each do |dept_name|
        case dept_name.downcase
        when /police/
          emergency_types.concat(['crime', 'theft', 'assault', 'traffic_accident'])
        when /fire/
          emergency_types.concat(['fire', 'rescue', 'hazmat'])
        when /health|medical|ems/
          emergency_types.concat(['medical', 'injury', 'illness'])
        when /animal/
          emergency_types.concat(['animal_attack', 'animal_rescue'])
        when /water|utility/
          emergency_types.concat(['water_leak', 'service_outage'])
        when /parks|recreation/
          emergency_types.concat(['park_emergency', 'facility_issue'])
        end
      end

      emergency_types.uniq
    end

    def determine_fallback_department(terminated_department)
      # Determine the best fallback based on the terminated department type
      case terminated_department.downcase
      when /police/
        'emergency_dispatch_center' # Critical - dispatch handles directly
      when /fire/
        'emergency_dispatch_center' # Critical - dispatch handles directly
      when /health|medical/
        'fire_department' # Fire often handles medical
      when /animal/
        'police_department' # Police can handle animal control
      when /parks|recreation/
        'public_works_department' # Public works can maintain facilities
      when /water|utility/
        'public_works_department' # Public works handles infrastructure
      else
        'emergency_dispatch_center' # Default to dispatch center
      end
    end

    def request_doge_analysis(analysis_type = 'periodic_audit', target_departments = [])
      logger.info("Requesting DOGE analysis: #{analysis_type}")
      puts "\n🏛️ 📤 Requesting DOGE Analysis"
      puts "   Type: #{analysis_type}"
      puts "   Targets: #{target_departments.empty? ? 'All departments' : target_departments.join(', ')}"

      message = Messages::DepartmentAnalysisRequestMessage.new(
        analysis_type: analysis_type,
        requested_by: @service_name,
        target_departments: target_departments,
        focus_areas: ['cost_reduction', 'service_overlap', 'utilization'],
        similarity_threshold: 0.15,
        include_cost_analysis: true,
        include_usage_metrics: true,
        urgency: 'normal',
        reason: 'Periodic efficiency review to optimize city services',
        report_format: 'detailed'
      )

      # Send to both DOGE systems
      ['doge', 'doge_vsm'].each do |doge_system|
        message.to = doge_system
        message.from = @service_name
        message.publish
        logger.info("Sent analysis request to #{doge_system}")
      end

      puts "🏛️ ✅ Analysis request sent to DOGE systems"
    end
  end
end

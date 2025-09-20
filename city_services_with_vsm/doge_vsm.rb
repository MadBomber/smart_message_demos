#!/usr/bin/env ruby
# doge_vsm.rb - Department of Government Efficiency using VSM paradigm
#
# VSM Architecture Benefits:
#
# 1. Identity System
#
# - Defines DOGE's core purpose: government efficiency optimization
# - Establishes invariants ensuring quality and evidence-based decisions
#
# 2. Intelligence System
#
# - AI-ready for LLM integration with sophisticated system prompts
# - Handles conversation flow and tool orchestration
# - Extensible for advanced reasoning capabilities
#
# 3. Operations System - Three Specialized Tools:
#
# - LoadDepartmentsTool: Handles YAML parsing and data extraction
# - SimilarityCalculatorTool: Performs similarity analysis with multiple metrics
# - RecommendationGeneratorTool: Generates detailed consolidation plans with cost estimates
#
# 4. Governance System
#
# - Validates analysis quality (not too few/many combinations)
# - Enforces minimum value thresholds for recommendations
# - Provides policy feedback on analysis quality
#
# 5. Coordination System
#
# - Manages workflow between analysis stages
# - Handles message scheduling and turn management
#
# Key Improvements Over Original:
#
# 1. Separation of Concerns: Each VSM system has specific responsibilities
# 2. Tool-based Architecture: Individual tools can be tested, reused, and extended
# 3. AI Integration Ready: Intelligence system prepared for LLM-driven analysis
# 4. Policy Enforcement: Governance ensures quality standards
# 5. Async Processing: Built on VSM's async foundation for scalability
# 6. Extensibility: Easy to add new analysis tools or modify workflow
#
# Enhanced Output Features:
#
# - Estimated cost savings calculations
# - Consolidation theme analysis
# - Implementation roadmaps
# - Policy validation alerts
# - Rich summary statistics
#
# The VSM paradigm transforms the monolithic DOGE class into a sophisticated, extensible system that's ready for AI integration
# and provides much richer analysis capabilities!

require 'async'
require 'yaml'
require 'set'
require 'securerandom'
require 'securerandom'

require_relative 'common/status_line'
require_relative 'common/logger'

require 'vsm'
require 'smart_message'

# Require the new SmartMessage classes for City Council communication
require_relative 'messages/consolidation_recommendation_message'
require_relative 'messages/termination_recommendation_message'
require_relative 'messages/council_decision_message'
require_relative 'messages/department_analysis_request_message'

# Require health monitoring message classes
require_relative 'messages/health_check_message'
require_relative 'messages/health_status_message'

require_relative 'doge_vsm/base'
require_relative 'doge_vsm/identity'
require_relative 'doge_vsm/intelligence'
require_relative 'doge_vsm/operations'
require_relative 'doge_vsm/governance'
require_relative 'doge_vsm/coordination'

module DogeVSM
  # Build the DOGE VSM capsule
  def self.build_capsule(provider: :openai, model: 'gpt-4o-mini')
    VSM::DSL.define(:doge) do
      identity     klass: DogeVSM::Identity
      governance   klass: DogeVSM::Governance
      coordination klass: DogeVSM::Coordination
      intelligence klass: DogeVSM::Intelligence, args: { provider: provider, model: model }
      operations do
        capsule :load_departments, klass: DogeVSM::Operations::LoadDepartmentsTool
        capsule :generate_recommendations, klass: DogeVSM::Operations::RecommendationGeneratorTool
        capsule :create_consolidated_departments, klass: DogeVSM::Operations::CreateConsolidatedDepartmentsTool
        capsule :validate_department_template, klass: DogeVSM::Operations::TemplateValidationTool
        capsule :generate_department_template, klass: DogeVSM::Operations::DepartmentTemplateGeneratorTool
      end
    end
  end
end

# Service class for continuous operation
class DogeVSMService
  include Common::Logger

  def initialize(provider: :openai, model: 'gpt-4o')
    @provider = provider
    @model = model
    @program = nil
    @running = true
    @last_analysis_time = nil
    @analysis_timeout = 120 # 2 minutes in seconds
    @pending_request = nil
    @service_name = 'doge_vsm'

    setup_signal_handlers
    setup_message_subscription
    setup_health_monitoring
  end

  def start
    log "🚀 DOGE VSM Service starting..."
    log "📡 Listening for analysis requests from City Council"
    log "⏰ Will auto-analyze every #{@analysis_timeout} seconds if no requests received"
    log "🏥 Health monitoring enabled - responding to health checks"
    log "🛑 Press Ctrl+C to stop service gracefully"
    log "🔄 Service will run continuously until interrupted"

    # Perform initial analysis
    perform_analysis("Initial startup analysis")

    # Main service loop
    while @running
      begin
        sleep(1)
        check_analysis_timeout
      rescue Interrupt
        log "🛑 Received interrupt signal, shutting down gracefully..."
        @running = false
      rescue => e
        log "❌ Error in main loop: #{e.message}"
        log "🔄 Continuing service operation..."
        sleep(5)
      end
    end

    log "✅ DOGE VSM Service stopped"
  end

  private

  def setup_signal_handlers
    # Handle SIGINT (Ctrl+C) and SIGTERM gracefully
    Signal.trap('INT') do
      log "🛑 Received SIGINT, initiating graceful shutdown..."
      @running = false
    end

    Signal.trap('TERM') do
      log "🛑 Received SIGTERM, initiating graceful shutdown..."
      @running = false
    end
  end

  def setup_message_subscription
    begin
      # Subscribe to analysis requests from City Council
      Messages::DepartmentAnalysisRequestMessage.from('doge_vsm')
      Messages::DepartmentAnalysisRequestMessage.subscribe(to: 'doge_vsm') do |message|
        handle_analysis_request(message)
      end
      log "📡 Subscribed to analysis requests from City Council"
    rescue => e
      log "⚠️  Failed to setup message subscription: #{e.message}"
      log "🔄 Service will continue with timeout-based analysis only"
    end
  end

  def setup_health_monitoring
    begin
      # Subscribe to health check messages
      Messages::HealthCheckMessage.from(@service_name)
      Messages::HealthCheckMessage.subscribe(to: @service_name) do |message|
        handle_health_check(message)
      end
      log "🏥 Subscribed to health check messages"
    rescue => e
      log "⚠️  Failed to setup health monitoring: #{e.message}"
      log "🔄 Service will continue without health monitoring"
    end
  end

  def handle_analysis_request(message)
    log "📥 Received analysis request from City Council"
    log "🎯 Request ID: #{message.request_id}"
    log "📋 Scope: #{message.analysis_scope}"

    @pending_request = message
    perform_analysis("City Council request: #{message.analysis_scope}")

    # Reset timeout after handling request
    @last_analysis_time = Time.now
  end

  def handle_health_check(message)
    log "🏥 Received health check request (ID: #{message.check_id})"

    # Determine our health status
    status, details = determine_health_status

    begin
      # Send health status response back to health department
      response = Messages::HealthStatusMessage.new(
        service_name: @service_name,
        check_id: message.check_id,
        status: status,
        details: details
      )

      response.from = @service_name
      response.to = message.from
      response.send

      log "📤 Sent health status: #{status.upcase} (#{details})"
    rescue => e
      log "❌ Failed to send health status: #{e.message}"
    end
  end

  def check_analysis_timeout
    return if @last_analysis_time.nil?

    time_since_last = Time.now - @last_analysis_time
    if time_since_last >= @analysis_timeout
      log "⏰ Analysis timeout reached (#{@analysis_timeout}s), performing automatic analysis"
      perform_analysis("Automatic periodic analysis")
    end
  end

  def perform_analysis(reason)
    log "🔍 Starting analysis: #{reason}"

    begin
      # Create fresh program instance for each analysis
      @program = DogeVSM::Base.new(provider: @provider, model: @model)

      # Run the analysis in a thread to avoid blocking the main service loop
      analysis_thread = Thread.new do
        begin
          @program.run
          log "✅ Analysis completed successfully"
        rescue => e
          log "❌ Analysis thread failed: #{e.class}: #{e.message}"
        end
      end

      @last_analysis_time = Time.now

      # Clear pending request
      @pending_request = nil

    rescue => e
      log "❌ Analysis setup failed: #{e.class}: #{e.message}"
      log "🔄 Will retry on next cycle"

      # Reset timeout to try again sooner on failure
      @last_analysis_time = Time.now - (@analysis_timeout - 30)
    end
  end

  def determine_health_status
    # Check various aspects of DOGE VSM service health
    begin
      # Check if we can create a VSM program instance
      test_program = DogeVSM::Base.new(provider: @provider, model: @model)

      # Determine status based on service conditions
      if @running && @program
        if @last_analysis_time && (Time.now - @last_analysis_time) < @analysis_timeout * 2
          ["healthy", "Analysis service operational, recent analysis completed"]
        else
          ["warning", "Service running but no recent analysis activity"]
        end
      elsif @running
        ["warning", "Service running but no analysis program initialized"]
      else
        ["critical", "Service shutdown in progress"]
      end
    rescue => e
      ["failed", "Cannot create VSM program: #{e.message}"]
    end
  end

  def log(message)
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "#{timestamp} [DOGE-VSM] #{message}"
  end
end

# CLI interface
if __FILE__ == $0
  system("rm -f log/doge_vsm.log")

  # Allow provider override via environment
  provider = ENV['DOGE_LLM_PROVIDER']&.to_sym || :openai
  model    = ENV['DOGE_LLM_MODEL'] || 'gpt-4o'

  puts "CLI: Creating DogeVSM Service with provider=#{provider}, model=#{model}"

  begin
    service = DogeVSMService.new(provider: provider, model: model)
    service.start
  rescue => e
    puts "CLI: Fatal error occurred: #{e.class}: #{e.message}"
    puts "CLI: Backtrace:"
    e.backtrace.each { |line| puts "  #{line}" }
    exit(1)
  end
end

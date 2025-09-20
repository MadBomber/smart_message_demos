# messages/department_analysis_request_message.rb
# Message to request DOGE analysis of city departments

require 'smart_message'

module Messages
  class DepartmentAnalysisRequestMessage < SmartMessage::Base
    version 1

    description <<~DESC
      Request message to trigger Department of Government Efficiency (DOGE)
      analysis of city departments, can be sent by City Council or other
      authorized entities to initiate efficiency review
    DESC

    transport SmartMessage::Transport::RedisTransport.new

    VALID_ANALYSIS_TYPES = %w[full_review consolidation_scan termination_review periodic_audit emergency_review]
    VALID_REQUESTORS = %w[city_council mayor citizen_petition emergency_dispatch_center system_admin]

    property :request_id,
      default: -> { SecureRandom.uuid },
      description: "Unique identifier for this analysis request"

    property :analysis_type, required: true,
      validate: ->(v) { VALID_ANALYSIS_TYPES.include?(v) },
      validation_message: "Analysis type must be one of: #{VALID_ANALYSIS_TYPES.join(', ')}",
      description: "Type of analysis requested"

    property :requested_by, required: true,
      validate: ->(v) { VALID_REQUESTORS.include?(v) },
      validation_message: "Requestor must be one of: #{VALID_REQUESTORS.join(', ')}",
      description: "Entity requesting the analysis"

    property :target_departments,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |d| d.is_a?(String) } },
      description: "Specific departments to analyze (empty array means analyze all)"

    property :focus_areas,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |a| a.is_a?(String) } },
      description: "Specific areas to focus on (e.g., 'cost_reduction', 'service_overlap', 'utilization')"

    property :similarity_threshold,
      default: 0.15,
      validate: ->(v) { v.is_a?(Numeric) && v >= 0 && v <= 1.0 },
      validation_message: "Similarity threshold must be between 0 and 1.0",
      description: "Minimum similarity score for consolidation consideration (0.0 to 1.0)"

    property :include_cost_analysis,
      default: true,
      validate: ->(v) { [true, false].include?(v) },
      description: "Whether to include cost savings analysis"

    property :include_usage_metrics,
      default: true,
      validate: ->(v) { [true, false].include?(v) },
      description: "Whether to analyze department usage patterns"

    property :urgency,
      default: 'normal',
      validate: ->(v) { %w[low normal high critical].include?(v) },
      validation_message: "Urgency must be one of: low, normal, high, critical",
      description: "Urgency level of the analysis request"

    property :reason,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.length >= 10 && v.length <= 500) },
      validation_message: "Reason must be 10-500 characters",
      description: "Reason for requesting the analysis"

    property :deadline,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{2}:\d{2}|Z)\z/)) },
      validation_message: "Deadline must be in ISO8601 format",
      description: "Deadline for completing the analysis"

    property :report_format,
      default: 'detailed',
      validate: ->(v) { %w[summary detailed full].include?(v) },
      validation_message: "Report format must be one of: summary, detailed, full",
      description: "Desired format for the analysis report"

    property :notify_channels,
      default: ['city_council'],
      validate: ->(v) { v.is_a?(Array) && v.all? { |c| c.is_a?(String) } },
      description: "Channels to notify when analysis is complete"

    property :request_timestamp,
      default: -> { Time.now.iso8601 },
      description: "Timestamp when the analysis was requested"
  end
end
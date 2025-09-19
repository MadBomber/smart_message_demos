# messages/termination_recommendation_message.rb
# Message for DOGE to recommend department termination to City Council

require 'smart_message'

module Messages
  class TerminationRecommendationMessage < SmartMessage::Base
    version 1

    description <<~DESC
      Termination recommendation from the Department of Government Efficiency (DOGE)
      to the City Council, proposing that a department be terminated due to redundancy,
      obsolescence, or lack of citizen usage
    DESC

    transport SmartMessage::Transport::RedisTransport.new

    VALID_REASONS = %w[redundant obsolete unused inefficient duplicate_services budget_constraints]

    property :recommendation_id,
      default: -> { SecureRandom.uuid },
      description: "Unique identifier for this termination recommendation"

    property :department_name, required: true,
      validate: ->(v) { v.is_a?(String) && v.length >= 3 && v.length <= 100 },
      validation_message: "Department name must be 3-100 characters",
      description: "Name of the department recommended for termination"

    property :termination_reason, required: true,
      validate: ->(v) { VALID_REASONS.include?(v) },
      validation_message: "Reason must be one of: #{VALID_REASONS.join(', ')}",
      description: "Primary reason for termination recommendation"

    property :detailed_rationale,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.length >= 20 && v.length <= 1000) },
      validation_message: "Detailed rationale must be 20-1000 characters",
      description: "Comprehensive explanation of why termination is recommended"

    property :services_to_reassign,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |s| s.is_a?(Hash) && s[:service] && s[:reassign_to] } },
      description: "List of services to reassign to other departments [{service: 'name', reassign_to: 'dept'}]"

    property :annual_cost,
      validate: ->(v) { v.nil? || (v.is_a?(Numeric) && v >= 0) },
      description: "Current annual operating cost of the department in dollars"

    property :usage_statistics,
      default: {},
      validate: ->(v) { v.is_a?(Hash) },
      description: "Usage statistics showing lack of utilization"

    property :alternative_solutions,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |a| a.is_a?(String) } },
      description: "Alternative solutions for services currently provided"

    property :impact_assessment,
      default: {},
      validate: ->(v) { v.is_a?(Hash) },
      description: "Assessment of citizen impact from termination"

    property :phase_out_timeline,
      validate: ->(v) { v.nil? || v.is_a?(String) },
      description: "Proposed timeline for phasing out the department"

    property :employee_count,
      validate: ->(v) { v.nil? || (v.is_a?(Integer) && v >= 0) },
      description: "Number of employees affected by termination"

    property :priority,
      default: 'normal',
      validate: ->(v) { %w[low normal high critical].include?(v) },
      validation_message: "Priority must be one of: low, normal, high, critical",
      description: "Priority level of this termination recommendation"

    property :analysis_timestamp,
      default: -> { Time.now.iso8601 },
      description: "Timestamp when the analysis was performed"

    property :analyzed_by,
      default: 'doge',
      description: "System that performed the analysis (typically 'doge' or 'doge_vsm')"
  end
end
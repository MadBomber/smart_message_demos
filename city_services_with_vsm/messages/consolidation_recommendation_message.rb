# messages/consolidation_recommendation_message.rb
# Message for DOGE to recommend department consolidations to City Council

require 'smart_message'

module Messages
  class ConsolidationRecommendationMessage < SmartMessage::Base
    version 1

    description <<~DESC
      Consolidation recommendation from the Department of Government Efficiency (DOGE)
      to the City Council, proposing that multiple departments be merged into a single
      consolidated department to improve efficiency and reduce redundancy
    DESC

    transport SmartMessage::Transport::RedisTransport.new

    property :recommendation_id,
      default: -> { SecureRandom.uuid },
      description: "Unique identifier for this consolidation recommendation"

    property :proposed_name, required: true,
      validate: ->(v) { v.is_a?(String) && v.length >= 3 && v.length <= 100 },
      validation_message: "Proposed name must be 3-100 characters",
      description: "Proposed name for the consolidated department"

    property :departments_to_merge, required: true,
      validate: ->(v) { v.is_a?(Array) && v.length >= 2 && v.all? { |d| d.is_a?(String) } },
      validation_message: "Must provide at least 2 departments to merge",
      description: "List of department names to be consolidated"

    property :similarity_score,
      validate: ->(v) { v.nil? || (v.is_a?(Numeric) && v >= 0 && v <= 100) },
      validation_message: "Similarity score must be between 0 and 100",
      description: "Percentage similarity score between departments (0-100)"

    property :overlapping_functions,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |f| f.is_a?(String) } },
      description: "List of overlapping functions or capabilities identified"

    property :estimated_annual_savings,
      validate: ->(v) { v.nil? || (v.is_a?(Numeric) && v >= 0) },
      description: "Estimated annual cost savings in dollars from consolidation"

    property :benefits,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |b| b.is_a?(String) } },
      description: "List of expected benefits from consolidation"

    property :implementation_timeline,
      validate: ->(v) { v.nil? || v.is_a?(String) },
      description: "Proposed timeline for implementing the consolidation"

    property :unified_capabilities,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |c| c.is_a?(String) } },
      description: "Combined capabilities of the consolidated department"

    property :rationale,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.length <= 1000) },
      validation_message: "Rationale must be under 1000 characters",
      description: "Detailed explanation of why consolidation is recommended"

    property :priority,
      default: 'normal',
      validate: ->(v) { %w[low normal high critical].include?(v) },
      validation_message: "Priority must be one of: low, normal, high, critical",
      description: "Priority level of this consolidation recommendation"

    property :analysis_timestamp,
      default: -> { Time.now.iso8601 },
      description: "Timestamp when the analysis was performed"

    property :analyzed_by,
      default: 'doge',
      description: "System that performed the analysis (typically 'doge' or 'doge_vsm')"
  end
end
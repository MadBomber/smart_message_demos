# messages/council_decision_message.rb
# Message for City Council to respond to DOGE recommendations

require 'smart_message'

module Messages
  class CouncilDecisionMessage < SmartMessage::Base
    version 1

    description <<~DESC
      Decision message from City Council in response to DOGE recommendations
      for department consolidation or termination, including approval status
      and implementation instructions
    DESC

    transport SmartMessage::Transport::RedisTransport.new

    VALID_DECISIONS = %w[approved rejected deferred pending_review modified]
    VALID_RECOMMENDATION_TYPES = %w[consolidation termination]

    property :decision_id,
      default: -> { SecureRandom.uuid },
      description: "Unique identifier for this council decision"

    property :recommendation_id, required: true,
      validate: ->(v) { v.is_a?(String) && v.length == 36 },
      validation_message: "Recommendation ID must be a valid UUID",
      description: "ID of the DOGE recommendation being responded to"

    property :recommendation_type, required: true,
      validate: ->(v) { VALID_RECOMMENDATION_TYPES.include?(v) },
      validation_message: "Type must be one of: #{VALID_RECOMMENDATION_TYPES.join(', ')}",
      description: "Type of recommendation being decided upon"

    property :decision, required: true,
      validate: ->(v) { VALID_DECISIONS.include?(v) },
      validation_message: "Decision must be one of: #{VALID_DECISIONS.join(', ')}",
      description: "Council's decision on the recommendation"

    property :decision_rationale,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.length >= 10 && v.length <= 1000) },
      validation_message: "Rationale must be 10-1000 characters",
      description: "Explanation of the council's decision"

    property :modifications,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |m| m.is_a?(String) } },
      description: "List of modifications to the original recommendation (if decision is 'modified')"

    property :implementation_instructions,
      default: {},
      validate: ->(v) { v.is_a?(Hash) },
      description: "Specific instructions for implementing the decision"

    property :effective_date,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.match?(/\A\d{4}-\d{2}-\d{2}\z/)) },
      validation_message: "Effective date must be in YYYY-MM-DD format",
      description: "Date when the decision becomes effective"

    property :budget_allocation,
      validate: ->(v) { v.nil? || (v.is_a?(Numeric) && v >= 0) },
      description: "Budget allocated for implementation (if applicable)"

    property :responsible_parties,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |p| p.is_a?(String) } },
      description: "List of departments or individuals responsible for implementation"

    property :success_criteria,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |c| c.is_a?(String) } },
      description: "Criteria for measuring success of the implementation"

    property :review_deadline,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.match?(/\A\d{4}-\d{2}-\d{2}\z/)) },
      validation_message: "Review deadline must be in YYYY-MM-DD format",
      description: "Deadline for reviewing implementation progress"

    property :council_vote,
      default: {},
      validate: ->(v) { v.is_a?(Hash) },
      description: "Voting record {for: N, against: N, abstain: N}"

    property :decided_by,
      default: 'city_council',
      description: "Entity making the decision"

    property :decision_timestamp,
      default: -> { Time.now.iso8601 },
      description: "Timestamp when the decision was made"
  end
end
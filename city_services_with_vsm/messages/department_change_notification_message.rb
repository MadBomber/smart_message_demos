# messages/department_change_notification_message.rb
# Message for notifying services (especially 911 dispatch) about department changes

require 'smart_message'

module Messages
  class DepartmentChangeNotificationMessage < SmartMessage::Base
    version 1

    description <<~DESC
      Notification message sent when departments are consolidated, terminated, or created.
      Critical for services like 911 dispatch that need to update their routing tables
      and emergency response protocols based on available departments.
    DESC

    transport SmartMessage::Transport::RedisTransport.new

    VALID_CHANGE_TYPES = %w[consolidated terminated created renamed]
    VALID_SOURCES = %w[city_council doge doge_vsm system_admin]

    property :change_id,
      default: -> { SecureRandom.uuid },
      description: "Unique identifier for this change notification"

    property :change_type, required: true,
      validate: ->(v) { VALID_CHANGE_TYPES.include?(v) },
      validation_message: "Change type must be one of: #{VALID_CHANGE_TYPES.join(', ')}",
      description: "Type of department change"

    property :affected_departments, required: true,
      validate: ->(v) { v.is_a?(Array) && v.length >= 1 && v.all? { |d| d.is_a?(String) } },
      validation_message: "Must provide at least one affected department",
      description: "List of department names affected by this change"

    property :new_department,
      validate: ->(v) { v.nil? || v.is_a?(String) },
      description: "Name of new/replacement department (for consolidations or renames)"

    property :routing_changes, required: true,
      validate: ->(v) { v.is_a?(Hash) },
      description: "Mapping of old department names to new routing destinations"

    property :capabilities_mapping,
      default: {},
      validate: ->(v) { v.is_a?(Hash) },
      description: "Mapping of capabilities from old to new departments"

    property :emergency_types_affected,
      default: [],
      validate: ->(v) { v.is_a?(Array) && v.all? { |t| t.is_a?(String) } },
      description: "List of emergency types that need routing updates"

    property :effective_immediately,
      default: true,
      validate: ->(v) { [true, false].include?(v) },
      description: "Whether this change is effective immediately"

    property :effective_date,
      validate: ->(v) { v.nil? || (v.is_a?(String) && v.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{2}:\d{2}|Z)\z/)) },
      validation_message: "Effective date must be in ISO8601 format",
      description: "When the change becomes effective (if not immediate)"

    property :fallback_department,
      validate: ->(v) { v.nil? || v.is_a?(String) },
      description: "Department to route to if primary routing fails"

    property :priority_override,
      default: false,
      validate: ->(v) { [true, false].include?(v) },
      description: "Whether this change should override any pending changes"

    property :additional_instructions,
      validate: ->(v) { v.nil? || v.is_a?(String) },
      description: "Special instructions for handling this change"

    property :initiated_by,
      default: 'city_council',
      validate: ->(v) { VALID_SOURCES.include?(v) },
      validation_message: "Initiated by must be one of: #{VALID_SOURCES.join(', ')}",
      description: "System or entity that initiated this change"

    property :change_timestamp,
      default: -> { Time.now.iso8601 },
      description: "Timestamp when the change was initiated"

    property :rollback_available,
      default: false,
      validate: ->(v) { [true, false].include?(v) },
      description: "Whether this change can be rolled back"

    property :rollback_instructions,
      validate: ->(v) { v.nil? || v.is_a?(Hash) },
      description: "Instructions for rolling back this change if needed"
  end
end
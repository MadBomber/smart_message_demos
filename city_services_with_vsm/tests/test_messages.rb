#!/usr/bin/env ruby  
# test_messages.rb - Formal tests for SmartMessage message classes

require_relative 'test_helper'

class TestMessages < CityServicesTestCase
  def setup
    super
    @original_dir = Dir.pwd
    Dir.chdir(File.dirname(__dir__))
  end

  def teardown
    Dir.chdir(@original_dir)
    super
  end

  def test_all_message_classes_defined
    expected_messages = %w[
      Emergency911Message
      ServiceRequestMessage
      FireDispatchMessage
      PoliceDispatchMessage
      SilentAlarmMessage
      FireEmergencyMessage
      HealthCheckMessage
      HealthStatusMessage
      EmergencyResolvedMessage
      DepartmentAnnouncementMessage
    ]

    expected_messages.each do |msg_class|
      full_class_name = "Messages::#{msg_class}"
      assert Object.const_defined?(full_class_name), "#{full_class_name} should be defined"
      puts "   ✅ #{msg_class} defined"
    end
  end

  def test_message_transport_configuration
    message_classes = [
      Messages::Emergency911Message,
      Messages::ServiceRequestMessage,
      Messages::HealthCheckMessage
    ]

    message_classes.each do |klass|
      refute_nil klass.transport, "#{klass} should have transport configured"
      puts "   #{klass} has transport: #{klass.transport.class}"
    end
  end

  def test_emergency_911_message_creation
    message = Messages::Emergency911Message.new(
      caller_name: "Test Caller",
      caller_location: "123 Test Street", 
      emergency_type: "fire",
      description: "Test emergency call",
      call_id: "test-#{SecureRandom.hex(4)}"
    )

    assert_equal "Test Caller", message.caller_name
    assert_equal "fire", message.emergency_type
    assert_includes Messages::Emergency911Message::VALID_EMERGENCY_TYPES, "fire"
    
    puts "   Created Emergency911Message successfully"
  end

  def test_service_request_message_creation  
    message = Messages::ServiceRequestMessage.new(
      requesting_service: "test-service",
      emergency_type: "infrastructure", 
      description: "Test service request",
      urgency: "medium"
    )

    assert_equal "test-service", message.requesting_service
    assert_equal "infrastructure", message.emergency_type
    
    puts "   Created ServiceRequestMessage successfully"
  end

  def test_health_check_message_creation
    message = Messages::HealthCheckMessage.new(
      from: "health_department",
      check_type: "routine"
    )

    assert_equal "health_department", message.from
    assert_equal "routine", message.check_type
    
    puts "   Created HealthCheckMessage successfully"
  end

  def test_fire_dispatch_message_creation
    message = Messages::FireDispatchMessage.new(
      incident_id: "fire-#{SecureRandom.hex(4)}",
      location: "123 Fire Test St",
      fire_type: "structure",
      severity: "high",
      units_requested: 3
    )

    assert_equal "structure", message.fire_type  
    assert_equal "high", message.severity
    assert_equal 3, message.units_requested
    
    puts "   Created FireDispatchMessage successfully"
  end

  def test_police_dispatch_message_creation
    message = Messages::PoliceDispatchMessage.new(
      incident_id: "police-#{SecureRandom.hex(4)}",
      location: "456 Police Test Ave",
      incident_type: "theft",
      priority: "medium", 
      units_requested: 2
    )

    assert_equal "theft", message.incident_type
    assert_equal "medium", message.priority
    assert_equal 2, message.units_requested
    
    puts "   Created PoliceDispatchMessage successfully"
  end

  def test_message_serialization_removed
    # Verify that messages no longer have serializer (transport handles it now)
    message = Messages::Emergency911Message.new(
      caller_location: "Test Location",
      emergency_type: "medical", 
      description: "Test"
    )

    # Should not have serializer method/attribute  
    refute_respond_to message.class, :serializer, 
                      "Messages should not have serializer (transport handles it)"
    
    puts "   Messages correctly updated to remove serializer"
  end

  def test_message_validation
    # Test that messages validate required fields
    assert_raises do
      Messages::Emergency911Message.new({})
    end

    # Test valid message
    valid_message = Messages::Emergency911Message.new(
      caller_location: "Required Location",
      emergency_type: "fire",
      description: "Required description"  
    )
    
    assert valid_message.valid?, "Valid message should pass validation"
    puts "   Message validation works correctly"
  end

  def test_message_constants_exist
    # Test that message classes define their constants
    assert defined?(Messages::Emergency911Message::VALID_EMERGENCY_TYPES),
           "Emergency911Message should define VALID_EMERGENCY_TYPES"
    
    assert defined?(Messages::Emergency911Message::VALID_SEVERITY),
           "Emergency911Message should define VALID_SEVERITY"
           
    assert Messages::Emergency911Message::VALID_EMERGENCY_TYPES.is_a?(Array),
           "VALID_EMERGENCY_TYPES should be an array"
    
    puts "   Message constants properly defined"
  end
end
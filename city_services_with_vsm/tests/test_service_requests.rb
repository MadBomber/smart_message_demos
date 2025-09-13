#!/usr/bin/env ruby
# test_service_requests.rb - Formal tests for service request messaging

require_relative 'test_helper'

class TestServiceRequests < CityServicesTestCase
  def setup
    super
    @original_dir = Dir.pwd
    Dir.chdir(File.dirname(__dir__))
  end

  def teardown
    Dir.chdir(@original_dir)
    super
  end

  def test_service_request_message_creation
    message = create_test_service_request(
      emergency_type: "Sanitation Emergency",
      description: "Need sanitation department to handle overflowing sewers",
      requesting_service: "sanitation_department"
    )

    assert_instance_of Messages::ServiceRequestMessage, message
    assert_equal "Sanitation Emergency", message.emergency_type
    assert_equal "sanitation_department", message.requesting_service
    assert_match(/overflowing sewers/, message.description)
    
    puts "   Created service request: #{message.emergency_type}"
  end

  def test_water_department_request_creation
    message = create_test_service_request(
      emergency_type: "infrastructure",
      description: "Water main break flooding downtown streets - need water management department", 
      urgency: "critical",
      details: {
        location: "Main Street & 5th Avenue",
        caller: "Downtown Business Owner",
        emergency_details: "Major water main break, streets flooding, businesses affected"
      }
    )

    assert_equal "infrastructure", message.emergency_type
    assert_equal "critical", message.urgency
    assert_includes message.description, "water management department"
    
    puts "   Created water emergency request: #{message.urgency} priority"
  end

  def test_service_request_message_headers
    message = create_test_service_request
    
    # Test SmartMessage header setup
    message._sm_header.from = "test_client"
    message._sm_header.to = "city_council"

    assert_equal "test_client", message._sm_header.from
    assert_equal "city_council", message._sm_header.to
    
    puts "   Message headers configured correctly"
  end

  def test_service_request_validation
    # Test required fields
    assert_raises do
      Messages::ServiceRequestMessage.new({})
    end

    # Test valid message
    message = create_test_service_request
    assert message.valid?, "Service request should be valid with required fields"
    
    puts "   Service request validation works"
  end

  def test_multiple_service_request_types
    test_cases = [
      {
        emergency_type: "sanitation",
        description: "Overflowing sewers citywide",
        requested_service: "sanitation_department"
      },
      {
        emergency_type: "infrastructure", 
        description: "Water main break on Main Street",
        requested_service: "water_management_department"
      },
      {
        emergency_type: "environmental",
        description: "Chemical spill in downtown area", 
        requested_service: "environmental_response_department"
      }
    ]

    test_cases.each do |test_case|
      message = create_test_service_request(test_case)
      assert_instance_of Messages::ServiceRequestMessage, message
      assert_equal test_case[:emergency_type], message.emergency_type
      puts "   Created #{test_case[:emergency_type]} service request"
    end
  end

  def test_service_request_transport_configuration
    message = create_test_service_request
    
    # Verify transport is configured (should be Redis)
    refute_nil message.class.transport, "ServiceRequestMessage should have transport configured"
    
    puts "   Transport configured for service requests"
  end
end
#!/usr/bin/env ruby
# test_helper.rb - Common test setup and utilities for minitest

require 'minitest/autorun'
require 'minitest/spec'
require 'timeout'
require 'yaml'
require 'securerandom'
require 'fileutils'

# Configure minitest reporter (optional)
begin
  require 'minitest/reporters'
  Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(color: true)]
rescue LoadError
  # minitest-reporters not available, use default output
  puts "ℹ️  minitest-reporters not available, using default output"
end

# Add project root to load path
project_root = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(project_root, 'lib')) if File.directory?(File.join(project_root, 'lib'))

# Require project dependencies
begin
  require_relative '../smart_message/lib/smart_message'
rescue LoadError
  begin
    require 'smart_message'
  rescue LoadError => e
    puts "⚠️  SmartMessage not found: #{e.message}"
  end
end

begin
  require 'vsm'
rescue LoadError => e
  puts "ℹ️  VSM not available: #{e.message}"
end

# Load all message types
messages_dir = File.join(File.dirname(__FILE__), '..', 'messages')
Dir[File.join(messages_dir, '*.rb')].each { |file| require file }

# Test utilities and helpers
module TestHelpers
  # Test data directory
  def test_data_dir
    File.join(__dir__, 'fixtures')
  end

  # Create test service request message
  def create_test_service_request(params = {})
    defaults = {
      from: "test-dispatcher",
      to: "city_council", 
      request_id: SecureRandom.uuid,
      requesting_service: "test-service",
      emergency_type: "test",
      description: "Test service request",
      urgency: "medium",
      original_call_id: "test-#{SecureRandom.hex(4)}"
    }
    
    Messages::ServiceRequestMessage.new(defaults.merge(params))
  end

  # Mock Redis for testing
  def with_mock_transport
    original_transport = SmartMessage::Transport::RedisTransport.new
    # Setup mock or memory transport for testing
    yield
  ensure
    # Cleanup
  end

  # Timeout helper for async operations  
  def wait_for_condition(timeout: 5, &block)
    Timeout.timeout(timeout) do
      loop do
        break if block.call
        sleep 0.1
      end
    end
  rescue Timeout::Error
    flunk "Condition not met within #{timeout} seconds"
  end

  # File existence assertion
  def assert_file_exists(path, message = nil)
    assert File.exist?(path), message || "Expected file #{path} to exist"
  end

  # Directory existence assertion  
  def assert_directory_exists(path, message = nil)
    assert File.directory?(path), message || "Expected directory #{path} to exist"
  end

  # Capture stdout helper
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end

# Base test class with common setup
class CityServicesTestCase < Minitest::Test
  include TestHelpers

  def setup
    @test_start_time = Time.now
    puts "\n🧪 #{self.class.name}##{name}"
  end

  def teardown
    duration = Time.now - @test_start_time
    puts "✅ Completed in #{duration.round(3)}s"
  end
end
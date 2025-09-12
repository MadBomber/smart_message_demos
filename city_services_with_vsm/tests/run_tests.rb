#!/usr/bin/env ruby
# run_tests.rb - Main test runner for city services tests

require_relative 'test_helper'

puts "🧪 City Services Test Suite"
puts "=" * 50

# Check dependencies
begin
  require 'smart_message'
  puts "✅ SmartMessage library available"
rescue LoadError
  puts "❌ SmartMessage library not found"
  exit 1
end

begin  
  require 'vsm'
  puts "✅ VSM library available"
rescue LoadError
  puts "⚠️  VSM library not available (some tests will be skipped)"
end

puts "\n🚀 Running all tests..."
puts "=" * 50

# Load all test files
test_files = Dir[File.join(__dir__, 'test_*.rb')].reject do |file|
  file.include?('test_helper.rb') || file.include?('run_tests.rb')
end

if test_files.empty?
  puts "❌ No test files found!"
  exit 1
end

puts "\nTest files found:"
test_files.each { |file| puts "  - #{File.basename(file)}" }

# Run tests
test_files.each { |file| require file }

puts "\n" + "=" * 50
puts "🏁 Test run completed"
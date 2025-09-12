# frozen_string_literal: true

# Information and utility tasks
desc 'Show test suite information'
task :test_info do
  puts '🧪 City Services Test Suite'
  puts '=' * 50
  puts 'Available test tasks:'
  puts '  rake test              - Run all tests'
  puts '  rake test:discovery    - Department discovery tests'
  puts '  rake test:messages     - SmartMessage tests'
  puts '  rake test:requests     - Service request tests'
  puts '  rake test:doge         - DOGE VSM tools tests'
  puts '  rake test:department   - Generic department tests'
  puts '  rake test:verbose      - Run all tests with detailed output'
  puts ''
  puts 'Test files:'
  Dir['tests/test_*.rb'].reject { |f| f.include?('test_helper') }.sort.each do |file|
    puts "  - #{File.basename(file)}"
  end
  puts ''
  puts 'Dependencies:'
  puts '  - minitest (testing framework)'
  puts '  - minitest-reporters (enhanced output)'
  puts '  - smart_message (messaging library)'
  puts '  - vsm (viable systems model library)'
end

desc 'Check test environment and dependencies'
task :test_env do
  puts '🔍 Checking test environment...'
  
  # Check Ruby version
  puts "Ruby version: #{RUBY_VERSION}"
  
  # Check required gems
  required_gems = %w[minitest smart_message]
  optional_gems = %w[vsm minitest-reporters]
  
  required_gems.each do |gem_name|
    begin
      require gem_name
      puts "✅ #{gem_name} - available"
    rescue LoadError
      puts "❌ #{gem_name} - missing (required)"
    end
  end
  
  optional_gems.each do |gem_name|
    begin
      require gem_name
      puts "✅ #{gem_name} - available"
    rescue LoadError
      puts "⚠️  #{gem_name} - missing (optional)"
    end
  end
  
  # Check test files
  test_files = Dir['tests/test_*.rb'].reject { |f| f.include?('test_helper') }
  puts "\nTest files found: #{test_files.size}"
  
  # Check for Redis (if needed)
  begin
    require 'redis'
    redis = Redis.new
    redis.ping
    puts '✅ Redis - connected'
  rescue => e
    puts "⚠️  Redis - not available (#{e.message})"
  end
end

desc 'Show available rake tasks'
task :help do
  puts '🏛️  City Services with VSM - Available Tasks'
  puts '=' * 60
  system('rake -T')
end
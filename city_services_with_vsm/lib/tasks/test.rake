# frozen_string_literal: true

require 'rake/testtask'

# Main test task - runs all tests
Rake::TestTask.new(:test) do |t|
  t.libs << 'tests'
  # Only include our new formal test files, exclude old informal ones and helper
  t.test_files = FileList['tests/test_*.rb'].exclude(
    'tests/test_helper.rb',
    'tests/test_department_creation.rb',    # Old informal test
    'tests/test_department_unit.rb',        # Old informal test
    'tests/test_tools_directly.rb',         # Old informal test
    'tests/test_water_request.rb'           # Old informal test
  )
  t.verbose = true
  t.warning = false
  t.description = 'Run all city services tests'
end

# Individual test suites
namespace :test do
  desc 'Run department discovery tests'
  Rake::TestTask.new(:discovery) do |t|
    t.libs << 'tests'
    t.test_files = ['tests/test_department_discovery.rb']
    t.verbose = true
  end

  desc 'Run SmartMessage message tests'
  Rake::TestTask.new(:messages) do |t|
    t.libs << 'tests'
    t.test_files = ['tests/test_messages.rb']
    t.verbose = true
  end

  desc 'Run service request tests'
  Rake::TestTask.new(:requests) do |t|
    t.libs << 'tests'
    t.test_files = ['tests/test_service_requests.rb']
    t.verbose = true
  end

  desc 'Run DOGE VSM tools tests'
  Rake::TestTask.new(:doge) do |t|
    t.libs << 'tests'
    t.test_files = ['tests/test_doge_vsm_tools.rb']
    t.verbose = true
  end

  desc 'Run generic department tests'
  Rake::TestTask.new(:department) do |t|
    t.libs << 'tests'
    t.test_files = ['tests/test_generic_department.rb']
    t.verbose = true
  end

  desc 'Run all tests with detailed output'
  task :verbose do
    ENV['VERBOSE'] = 'true'
    Rake::Task[:test].invoke
  end
end
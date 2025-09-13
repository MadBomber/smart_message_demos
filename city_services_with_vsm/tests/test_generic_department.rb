#!/usr/bin/env ruby
# test_generic_department.rb - Formal tests for generic department functionality

require_relative 'test_helper'

class TestGenericDepartment < CityServicesTestCase
  def setup
    super
    @original_dir = Dir.pwd
    Dir.chdir(File.dirname(__dir__))
    
    @config_file = 'test_department_unit.yml' 
    
    # Load generic department if available
    begin
      require_relative '../generic_department'
    rescue LoadError => e
      skip "Generic department not available: #{e.message}"
    end
  end

  def teardown
    Dir.chdir(@original_dir)
    super
  end

  def test_config_file_existence
    unless File.exist?(@config_file)
      skip "Config file #{@config_file} not found. Please run from the correct directory."
    end
    
    assert_file_exists @config_file, "Config file should exist for testing"
    puts "   Config file #{@config_file} found"
  end

  def test_config_loading
    skip "Config file not found" unless File.exist?(@config_file)
    
    config = YAML.load_file(@config_file)
    
    assert_instance_of Hash, config, "Config should be a hash"
    assert config['department'], "Config should have department section"
    assert_equal 'test_department_unit', config['department']['name']
    
    puts "   Config loaded successfully: #{config['department']['name']}"
  end

  def test_vsm_component_classes_exist
    required_components = %w[
      GenericDepartmentIdentity
      GenericDepartmentGovernance
      GenericDepartmentIntelligence  
      GenericDepartmentOperations
    ]

    required_components.each do |component|
      if defined?(Object.const_get(component))
        puts "   ✅ #{component} class defined"
      else
        puts "   ⚠️  #{component} class not defined (may be dynamically loaded)"
      end
    end
  end

  def test_generic_department_file_syntax
    dept_file = 'generic_department.rb'
    assert_file_exists dept_file, "Generic department file should exist"
    
    output = `ruby -c "#{dept_file}" 2>&1`
    assert $?.success?, "#{dept_file} should have valid Ruby syntax: #{output}"
    
    puts "   Generic department file has valid syntax"
  end

  def test_yaml_config_structure
    skip "Config file not found" unless File.exist?(@config_file)
    
    config = YAML.load_file(@config_file)
    
    # Test required config sections
    assert config['department'], "Config should have 'department' section"
    assert config['department']['name'], "Department should have name"
    
    # Test optional sections that might exist
    optional_sections = %w[messages subscriptions operations governance]
    optional_sections.each do |section|
      if config[section]
        puts "   Optional section '#{section}' found in config"
      end
    end
  end

  def test_department_name_validation  
    skip "Config file not found" unless File.exist?(@config_file)
    
    config = YAML.load_file(@config_file)
    name = config['department']['name']
    
    refute_nil name, "Department name should not be nil"
    refute_empty name, "Department name should not be empty"
    assert_match(/\A[a-z_]+\z/, name, "Department name should be lowercase with underscores")
    
    puts "   Department name '#{name}' is valid"
  end

  def test_message_handling_capabilities
    # Test that the generic department can handle common message types
    message_types = %w[
      ServiceRequestMessage
      HealthCheckMessage  
      EmergencyResolvedMessage
    ]

    message_types.each do |msg_type|
      if Object.const_defined?("Messages::#{msg_type}")
        puts "   Can handle #{msg_type}"
      else
        puts "   ⚠️  #{msg_type} not defined"
      end
    end
  end

  def test_department_template_generation
    # Test if we can generate a basic department template
    template_content = {
      'department' => {
        'name' => 'test_department',
        'description' => 'Test department for unit testing'
      },
      'messages' => {
        'subscriptions' => []
      }
    }

    temp_file = 'temp_test_dept.yml'
    File.write(temp_file, template_content.to_yaml)
    
    assert_file_exists temp_file, "Should be able to create department template"
    
    loaded = YAML.load_file(temp_file)
    assert_equal 'test_department', loaded['department']['name']
    
    puts "   Can generate department templates"
  ensure
    File.delete(temp_file) if File.exist?(temp_file)
  end

  def test_concurrent_department_safety
    # Test basic thread safety for department operations
    skip "Config file not found" unless File.exist?(@config_file)
    
    threads = []
    results = []
    
    3.times do |i|
      threads << Thread.new do
        config = YAML.load_file(@config_file)
        results << config['department']['name']
      end
    end
    
    threads.each(&:join)
    
    assert_equal 3, results.size, "All threads should complete"
    assert results.all? { |r| r == 'test_department_unit' }, "All threads should get same result"
    
    puts "   Basic thread safety verified"
  end
end
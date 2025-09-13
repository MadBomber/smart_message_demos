#!/usr/bin/env ruby
# test_department_discovery.rb - Formal tests for department discovery logic

require_relative 'test_helper'

class TestDepartmentDiscovery < CityServicesTestCase
  def setup
    super
    @original_dir = Dir.pwd
    # Change to project root for department discovery
    Dir.chdir(File.dirname(__dir__))
  end

  def teardown
    Dir.chdir(@original_dir)
    super
  end

  def test_ruby_department_discovery
    ruby_departments = Dir.glob("*_department.rb").map do |file|
      File.basename(file, ".rb")
    end

    refute_empty ruby_departments, "Should find Ruby-based departments"
    
    # Verify expected departments exist
    expected_departments = %w[fire_department police_department health_department]
    expected_departments.each do |dept|
      assert_includes ruby_departments, dept, "Should find #{dept}"
    end

    puts "   Found #{ruby_departments.size} Ruby departments: #{ruby_departments.join(', ')}"
  end

  def test_yaml_department_discovery
    yaml_departments = Dir.glob("*_department.yml").map do |file|
      File.basename(file, ".yml")
    end

    puts "   Found #{yaml_departments.size} YAML departments: #{yaml_departments.join(', ')}"
    # YAML departments are optional, so we don't assert they exist
  end

  def test_combined_department_discovery
    # Test the same logic as in city_council/base.rb
    ruby_departments = Dir.glob("*_department.rb").map do |file|
      File.basename(file, ".rb")
    end

    yaml_departments = Dir.glob("*_department.yml").map do |file|
      File.basename(file, ".yml")  
    end

    departments = (ruby_departments + yaml_departments).sort.uniq

    refute_empty departments, "Should discover at least some departments"
    assert departments.size >= 3, "Should find at least 3 departments (fire, police, health)"

    puts "   Total unique departments discovered: #{departments.size}"
    puts "   Departments: #{departments.join(', ')}"
  end

  def test_department_uniqueness
    ruby_departments = Dir.glob("*_department.rb").map { |f| File.basename(f, ".rb") }
    yaml_departments = Dir.glob("*_department.yml").map { |f| File.basename(f, ".yml") }
    
    all_departments = ruby_departments + yaml_departments
    unique_departments = all_departments.uniq

    assert_equal unique_departments.size, all_departments.size,
                 "Should not have duplicate departments between Ruby and YAML"
  end

  def test_department_file_existence
    ruby_departments = Dir.glob("*_department.rb")
    
    ruby_departments.each do |dept_file|
      assert_file_exists dept_file, "Department file #{dept_file} should exist"
      
      # Basic syntax check
      output = `ruby -c "#{dept_file}" 2>&1`
      assert $?.success?, "#{dept_file} should have valid Ruby syntax: #{output}"
    end
  end
end
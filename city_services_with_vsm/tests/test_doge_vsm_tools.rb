#!/usr/bin/env ruby
# test_doge_vsm_tools.rb - Formal tests for DOGE VSM tools functionality

require_relative 'test_helper'

class TestDogeVSMTools < CityServicesTestCase
  def setup
    super
    @original_dir = Dir.pwd
    Dir.chdir(File.dirname(__dir__))
    
    # Load DOGE VSM tools
    require_relative '../doge_vsm/operations/load_departments_tool'
    require_relative '../doge_vsm/operations/similarity_calculator_tool' 
    require_relative '../doge_vsm/operations/recommendation_generator_tool'
  rescue LoadError => e
    skip "DOGE VSM tools not available: #{e.message}"
  end

  def teardown
    Dir.chdir(@original_dir)
    super
  end

  def test_load_departments_tool_exists
    assert defined?(DogeVSM::Operations::LoadDepartmentsTool), 
           "LoadDepartmentsTool should be defined"
    
    tool = DogeVSM::Operations::LoadDepartmentsTool.new
    assert_respond_to tool, :run, "LoadDepartmentsTool should respond to run"
    
    puts "   LoadDepartmentsTool class available"
  end

  def test_load_departments_tool_execution
    tool = DogeVSM::Operations::LoadDepartmentsTool.new
    result = tool.run({})

    assert_instance_of Hash, result, "LoadDepartmentsTool should return a hash"
    assert result.key?(:count), "Result should include :count"
    assert result.key?(:departments), "Result should include :departments"
    assert result[:count] > 0, "Should load at least one department"
    
    puts "   Loaded #{result[:count]} departments successfully"
  end

  def test_similarity_calculator_tool_exists  
    assert defined?(DogeVSM::Operations::SimilarityCalculatorTool),
           "SimilarityCalculatorTool should be defined"
    
    tool = DogeVSM::Operations::SimilarityCalculatorTool.new
    assert_respond_to tool, :run, "SimilarityCalculatorTool should respond to run"
    
    puts "   SimilarityCalculatorTool class available"
  end

  def test_similarity_calculator_tool_execution
    # First load departments
    load_tool = DogeVSM::Operations::LoadDepartmentsTool.new
    load_result = load_tool.run({})
    
    # Then calculate similarities
    calc_tool = DogeVSM::Operations::SimilarityCalculatorTool.new
    calc_result = calc_tool.run({ departments: load_result[:departments] })

    assert_instance_of Hash, calc_result, "SimilarityCalculatorTool should return a hash"
    assert calc_result.key?(:combinations_found), "Result should include :combinations_found"
    assert calc_result.key?(:combinations), "Result should include :combinations"
    
    puts "   Found #{calc_result[:combinations_found]} department combinations"
  end

  def test_recommendation_generator_tool_exists
    assert defined?(DogeVSM::Operations::RecommendationGeneratorTool),
           "RecommendationGeneratorTool should be defined"
    
    tool = DogeVSM::Operations::RecommendationGeneratorTool.new
    assert_respond_to tool, :run, "RecommendationGeneratorTool should respond to run"
    
    puts "   RecommendationGeneratorTool class available"
  end

  def test_recommendation_generator_tool_execution
    # Load departments
    load_tool = DogeVSM::Operations::LoadDepartmentsTool.new
    load_result = load_tool.run({})
    
    # Calculate similarities  
    calc_tool = DogeVSM::Operations::SimilarityCalculatorTool.new
    calc_result = calc_tool.run({ departments: load_result[:departments] })
    
    # Generate recommendations
    rec_tool = DogeVSM::Operations::RecommendationGeneratorTool.new
    rec_result = rec_tool.run({ combinations: calc_result[:combinations] })

    assert_instance_of Hash, rec_result, "RecommendationGeneratorTool should return a hash"
    
    # Handle case where no combinations found (empty list)
    if calc_result[:combinations].empty?
      assert rec_result.key?(:error), "Should return error when no combinations provided"
      puts "   No combinations found - returned error as expected"
    else
      assert rec_result.key?(:total_recommendations), "Result should include :total_recommendations"
      puts "   Generated #{rec_result[:total_recommendations]} recommendations"
    end
  end

  def test_full_doge_workflow
    # Test the complete DOGE analysis workflow
    puts "   Testing complete DOGE workflow..."
    
    # Step 1: Load departments
    load_tool = DogeVSM::Operations::LoadDepartmentsTool.new
    load_result = load_tool.run({})
    assert load_result[:count] > 0, "Should load departments"
    
    # Step 2: Calculate similarities
    calc_tool = DogeVSM::Operations::SimilarityCalculatorTool.new
    calc_result = calc_tool.run({ departments: load_result[:departments] })
    
    # Step 3: Generate recommendations  
    rec_tool = DogeVSM::Operations::RecommendationGeneratorTool.new
    rec_result = rec_tool.run({ combinations: calc_result[:combinations] })
    
    # Verify workflow completion
    assert load_result[:count] > 0, "Workflow should load departments"
    assert calc_result[:combinations_found] >= 0, "Workflow should calculate combinations"
    
    # Handle both successful recommendations and empty combinations case
    if calc_result[:combinations].empty?
      assert rec_result.key?(:error), "Should return error when no combinations found"
      rec_count = 0
    else  
      assert rec_result[:total_recommendations] >= 0, "Workflow should generate recommendations"
      rec_count = rec_result[:total_recommendations]
    end
    
    puts "   Complete DOGE workflow executed successfully"
    puts "     - Departments loaded: #{load_result[:count]}"
    puts "     - Combinations found: #{calc_result[:combinations_found]}"
    puts "     - Recommendations: #{rec_count}"
  end

  def test_doge_tools_error_handling
    # Test tools with invalid input
    calc_tool = DogeVSM::Operations::SimilarityCalculatorTool.new
    
    # Should handle empty/nil departments gracefully
    result = calc_tool.run({ departments: [] })
    
    # The tool returns an error hash for empty departments
    if result.key?(:error)
      assert_equal "No departments provided", result[:error], "Should return appropriate error message"
      puts "   DOGE tools handle empty departments with error message"
    else
      assert_equal 0, result[:combinations_found], "Should handle empty departments list"
      puts "   DOGE tools handle empty departments gracefully"
    end
  end
end
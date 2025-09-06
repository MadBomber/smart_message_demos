# doge_vsm/operations/recommendation_generator_tool.rb

module DogeVSM
  class Operations < VSM::Operations
    class RecommendationGeneratorTool < VSM::ToolCapsule
      tool_name 'generate_recommendations'
      tool_description 'Generate detailed consolidation recommendations from similarity analysis'
      tool_schema({
        type: 'object',
        properties: {
          combinations: { 
            type: 'array', 
            description: 'Array of department combination objects identified by AI analysis',
            items: {
              type: 'object',
              properties: {
                dept1: { type: 'object', description: 'First department to consolidate' },
                dept2: { type: 'object', description: 'Second department to consolidate' },
                score: { type: 'number', description: 'Similarity/consolidation score (0.0-1.0)' },
                reasons: { type: 'array', items: { type: 'string' }, description: 'Reasons for consolidation' }
              }
            }
          }
        },
        required: ['combinations']
      })

      def run(args)
        # Handle both direct array and wrapped format from SimilarityCalculatorTool
        # Handle both symbol and string keys from different AI models  
        combinations_data = args[:combinations] || args["combinations"]
        if combinations_data.is_a?(Hash) && combinations_data[:combinations]
          combinations = combinations_data[:combinations]
        elsif combinations_data.is_a?(Array)
          combinations = combinations_data
        else
          return { error: "Invalid combinations data format: #{combinations_data.class}" }
        end

        return { error: "No combinations provided" } if combinations.nil? || combinations.empty?
        
        recommendations = []

        combinations.each do |combo|
          recommendation = build_recommendation(combo)
          if recommendation[:error]
            # Log error but continue processing other combinations
            puts "ERROR in build_recommendation: #{recommendation[:error]}"
            puts "Combo keys: #{recommendation[:combo_keys]}"
            next
          end
          recommendations << recommendation
        end

        {
          total_recommendations: recommendations.length,
          recommendations: recommendations,
          summary: generate_summary(recommendations)
        }
      end

      private

      def build_recommendation(combo)
        dept1 = combo[:dept1] || combo["dept1"]
        dept2 = combo[:dept2] || combo["dept2"]
        score = combo[:score] || combo["score"] || 0.0
        reasons = combo[:reasons] || combo["reasons"] || []

        # Validate that we have valid department objects
        if dept1.nil? || dept2.nil?
          return {
            error: "Invalid department data - missing dept1 or dept2",
            combo_keys: combo.keys,
            dept1_present: !dept1.nil?,
            dept2_present: !dept2.nil?
          }
        end

        # Ensure departments have required fields with defaults
        dept1_caps = dept1[:capabilities] || dept1["capabilities"] || []
        dept2_caps = dept2[:capabilities] || dept2["capabilities"] || []
        
        combined_name = generate_combined_name(dept1, dept2)
        all_capabilities = (dept1_caps + dept2_caps).uniq
        duplicates_eliminated = dept1_caps.length + dept2_caps.length - all_capabilities.length

        {
          similarity_score: (score * 100).round(1),
          departments: [
            { 
              name: dept1[:display_name] || dept1["display_name"] || "Unknown Department", 
              file: dept1[:file] || dept1["file"] || "unknown.yml" 
            },
            { 
              name: dept2[:display_name] || dept2["display_name"] || "Unknown Department", 
              file: dept2[:file] || dept2["file"] || "unknown.yml" 
            }
          ],
          proposed_name: combined_name,
          rationale: reasons,
          capabilities: {
            total: all_capabilities.length,
            duplicates_eliminated: duplicates_eliminated,
            combined_list: all_capabilities
          },
          benefits: [
            "Eliminate #{duplicates_eliminated} duplicate capabilities",
            'Consolidate similar infrastructure management',
            'Improve coordination between related services',
            'Reduce operational overhead',
            'Streamline citizen service delivery'
          ],
          implementation: {
            files_to_merge: [
              dept1[:file] || dept1["file"] || "unknown1.yml", 
              dept2[:file] || dept2["file"] || "unknown2.yml"
            ],
            new_config_file: "#{combined_name.downcase.gsub(' ', '_')}.yml",
            estimated_savings: calculate_estimated_savings(dept1, dept2)
          }
        }
      end

      def generate_combined_name(dept1, dept2)
        name1 = dept1[:display_name] || dept1["display_name"] || "Unknown"
        name2 = dept2[:display_name] || dept2["display_name"] || "Unknown"
        
        name1_words = name1.downcase.split
        name2_words = name2.downcase.split

        # Look for common infrastructure themes
        if (name1_words + name2_words).any? { |word| word.match?(/water|waste|sewer|utility/) }
          'Water & Utilities Management'
        elsif (name1_words + name2_words).any? { |word| word.match?(/transport|traffic|transit/) }
          'Transportation & Transit Management'
        elsif (name1_words + name2_words).any? { |word| word.match?(/environment|health|safety/) }
          'Environmental Health & Safety'
        elsif (name1_words + name2_words).any? { |word| word.match?(/public|works|infrastructure/) }
          'Public Works & Infrastructure'
        else
          # Fallback: combine unique words
          all_words = (name1_words + name2_words).uniq
          key_words = all_words.reject { |word| %w[and department management].include?(word) }
          "#{key_words.map(&:capitalize).join(' ')} Department"
        end
      end

      def calculate_estimated_savings(dept1, dept2)
        # Simple heuristic based on capability overlap
        base_cost = 100_000  # Assumed annual cost per department
        
        dept1_caps = dept1[:capabilities] || dept1["capabilities"] || []
        dept2_caps = dept2[:capabilities] || dept2["capabilities"] || []
        
        return { estimated_annual_savings: 0, methodology: 'No capability data available' } if dept1_caps.empty? || dept2_caps.empty?
        
        overlap_ratio = (dept1_caps & dept2_caps).length.to_f /
                       [dept1_caps.length, dept2_caps.length].max

        savings = (base_cost * overlap_ratio * 0.6).round

        {
          estimated_annual_savings: savings,
          methodology: 'Based on capability overlap and assumed operational costs'
        }
      end

      def generate_summary(recommendations)
        total_departments = recommendations.map { |r| r[:departments] }.flatten.uniq { |d| d[:name] }.length
        total_capabilities_eliminated = recommendations.sum { |r| r[:capabilities][:duplicates_eliminated] }
        total_estimated_savings = recommendations.sum { |r| r[:implementation][:estimated_savings][:estimated_annual_savings] }

        {
          departments_analyzed: total_departments,
          total_consolidation_opportunities: recommendations.length,
          total_duplicate_capabilities_eliminated: total_capabilities_eliminated,
          total_estimated_annual_savings: total_estimated_savings,
          top_consolidation_themes: identify_consolidation_themes(recommendations)
        }
      end

      def identify_consolidation_themes(recommendations)
        themes = Hash.new(0)

        recommendations.each do |rec|
          case rec[:proposed_name]
          when /Water|Utilities/
            themes['Water & Utilities Management'] += 1
          when /Transportation|Transit/
            themes['Transportation Management'] += 1
          when /Environmental|Health|Safety/
            themes['Environmental Health & Safety'] += 1
          when /Public Works|Infrastructure/
            themes['Infrastructure Management'] += 1
          else
            themes['Other Consolidations'] += 1
          end
        end

        themes.sort_by { |_, count| -count }.to_h
      end
    end
  end
end
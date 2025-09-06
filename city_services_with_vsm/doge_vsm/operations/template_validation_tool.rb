# doge_vsm/operations/template_validation_tool.rb

module DogeVSM
  class Operations < VSM::Operations
    class TemplateValidationTool < VSM::ToolCapsule
      tool_name 'validate_department_template'
      tool_description 'Validate department YAML files against the generic template structure and identify missing or malformed sections'
      tool_schema({
        type: 'object',
        properties: {
          file_path: { type: 'string', description: 'Path to department YAML file to validate' },
          template_path: { type: 'string', description: 'Path to template file (default: generic_department_sample.yml)' }
        },
        required: ['file_path']
      })

      def run(args)
        file_path = args[:file_path]
        template_path = args[:template_path] || 'generic_department_sample.yml'
        
        unless File.exist?(file_path)
          return { valid: false, error: "File not found: #{file_path}" }
        end

        unless File.exist?(template_path)
          return { valid: false, error: "Template file not found: #{template_path}" }
        end

        begin
          config = YAML.load_file(file_path)
          template_structure = load_template_structure(template_path)
          
          validation_result = validate_structure(config, template_structure, file_path)
          
          {
            valid: validation_result[:errors].empty?,
            file: file_path,
            errors: validation_result[:errors],
            warnings: validation_result[:warnings],
            completeness_score: calculate_completeness_score(config, template_structure),
            missing_sections: validation_result[:missing_sections],
            extra_sections: validation_result[:extra_sections]
          }
        rescue => e
          {
            valid: false,
            error: "Failed to parse YAML: #{e.message}",
            file: file_path
          }
        end
      end

      private

      def load_template_structure(template_path)
        template = YAML.load_file(template_path)
        
        # Define required structure based on template
        {
          required_sections: %w[department capabilities message_types routing_rules message_actions action_configs logging],
          optional_sections: %w[ai_analysis resources integrations custom_settings],
          department_required: %w[name display_name description invariants],
          message_types_required: %w[subscribes_to publishes],
          action_configs_required: %w[handle_emergency respond_health_check],
          logging_required: %w[level statistics_interval]
        }
      end

      def validate_structure(config, template_structure, file_path)
        errors = []
        warnings = []
        missing_sections = []
        extra_sections = []

        # Check top-level structure
        template_structure[:required_sections].each do |section|
          unless config.key?(section)
            errors << "Missing required section: #{section}"
            missing_sections << section
          end
        end

        # Check department section
        if config['department']
          template_structure[:department_required].each do |field|
            unless config['department'].key?(field)
              errors << "Missing required department field: #{field}"
            end
          end
        else
          errors << "Missing required 'department' section"
        end

        # Check message_types structure
        if config['message_types']
          template_structure[:message_types_required].each do |field|
            unless config['message_types'].key?(field)
              errors << "Missing required message_types field: #{field}"
            end
          end
        end

        # Check action_configs has minimum required actions
        if config['action_configs']
          template_structure[:action_configs_required].each do |action|
            unless config['action_configs'].key?(action)
              warnings << "Missing standard action config: #{action}"
            end
          end
        end

        # Check logging section
        if config['logging']
          template_structure[:logging_required].each do |field|
            unless config['logging'].key?(field)
              errors << "Missing required logging field: #{field}"
            end
          end
        end

        # Check for extra sections (not necessarily errors)
        all_known_sections = template_structure[:required_sections] + template_structure[:optional_sections]
        config.keys.each do |section|
          unless all_known_sections.include?(section)
            extra_sections << section
            warnings << "Unknown section (may be department-specific): #{section}"
          end
        end

        # Validate routing rules structure
        if config['routing_rules']
          config['routing_rules'].each do |message_type, rules|
            Array(rules).each_with_index do |rule, index|
              unless rule.is_a?(Hash) && rule.key?('condition')
                errors << "Invalid routing rule structure in #{message_type}[#{index}]: missing 'condition'"
              end
            end
          end
        end

        {
          errors: errors,
          warnings: warnings,
          missing_sections: missing_sections,
          extra_sections: extra_sections
        }
      end

      def calculate_completeness_score(config, template_structure)
        total_sections = template_structure[:required_sections].length + template_structure[:optional_sections].length
        present_sections = (template_structure[:required_sections] + template_structure[:optional_sections]).count { |section| config.key?(section) }
        
        # Calculate percentage completeness
        (present_sections.to_f / total_sections * 100).round(1)
      end
    end
  end
end
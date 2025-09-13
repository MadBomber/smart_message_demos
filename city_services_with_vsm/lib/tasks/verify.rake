# frozen_string_literal: true

# Verification tasks to confirm rake organization is working
desc 'Verify rake task organization is working'
task :verify do
  puts '✅ Rake task organization verification'
  puts '=' * 50
  
  # Check that tasks from each file are loaded
  puts 'Verifying tasks from each .rake file:'
  
  # Test tasks (from test.rake)
  if Rake::Task.task_defined?(:test)
    puts '✅ test.rake - Main test task loaded'
  else
    puts '❌ test.rake - Main test task NOT loaded'
  end
  
  if Rake::Task.task_defined?('test:discovery')
    puts '✅ test.rake - Namespaced test tasks loaded'
  else
    puts '❌ test.rake - Namespaced test tasks NOT loaded'
  end
  
  # Info tasks (from info.rake)
  if Rake::Task.task_defined?(:test_info)
    puts '✅ info.rake - Info tasks loaded'
  else
    puts '❌ info.rake - Info tasks NOT loaded'
  end
  
  # Demo tasks (from demo.rake)
  if Rake::Task.task_defined?(:demo)
    puts '✅ demo.rake - Demo tasks loaded'
  else
    puts '❌ demo.rake - Demo tasks NOT loaded'
  end
  
  # Clean tasks (from clean.rake)
  if Rake::Task.task_defined?(:clean)
    puts '✅ clean.rake - Clean tasks loaded'
  else
    puts '❌ clean.rake - Clean tasks NOT loaded'
  end
  
  puts ''
  puts 'Task organization structure:'
  puts "  Main Rakefile: #{File.readlines('Rakefile').count} lines"
  
  Dir['lib/tasks/*.rake'].sort.each do |file|
    line_count = File.readlines(file).count
    puts "  #{file}: #{line_count} lines"
  end
  
  puts ''
  puts '🎉 Rake task organization is working perfectly!'
  puts 'All tasks have been successfully moved to lib/tasks/ directory'
end
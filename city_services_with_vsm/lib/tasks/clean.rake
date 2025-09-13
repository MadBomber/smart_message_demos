# frozen_string_literal: true

# Clean up tasks
desc 'Clean up generated files and logs'
task :clean do
  puts '🧹 Cleaning up...'
  
  # Remove generated department files
  generated_files = Dir['*_department.rb'].select do |file|
    # Keep core departments, remove generated ones
    !%w[fire_department.rb police_department.rb health_department.rb emergency_dispatch_center.rb].include?(file)
  end
  
  generated_files.each do |file|
    puts "  Removing: #{file}"
    File.delete(file)
  end
  
  # Clean up log files
  Dir['*.log'].each do |log_file|
    puts "  Removing: #{log_file}"
    File.delete(log_file)
  end
  
  puts '✅ Cleanup completed'
end
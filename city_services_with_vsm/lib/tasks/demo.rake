# frozen_string_literal: true

# Demo and simulation tasks
desc 'Start the city services simulation'
task :demo do
  if File.exist?('start_demo.sh')
    puts '🚀 Starting city services demo...'
    system('./start_demo.sh')
  else
    puts '❌ start_demo.sh not found'
  end
end

desc 'Stop the city services simulation'
task :stop do
  if File.exist?('stop_demo.sh')
    puts '🛑 Stopping city services demo...'
    system('./stop_demo.sh')
  else
    puts '❌ stop_demo.sh not found'
  end
end
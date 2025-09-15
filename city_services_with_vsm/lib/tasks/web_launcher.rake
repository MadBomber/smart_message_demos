# frozen_string_literal: true

desc 'Start the web-based service launcher'
task :web do
  puts '🌐 Starting web-based service launcher...'
  puts '   Access at: http://localhost:4567'
  puts '   Press Ctrl+C to stop'
  puts ''
  system('ruby web_service_launcher.rb')
end

desc 'Start web launcher and open browser'
task :web_open => :web do
  sleep 2
  system('open http://localhost:4567')
end
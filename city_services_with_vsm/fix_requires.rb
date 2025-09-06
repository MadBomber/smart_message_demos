#!/usr/bin/env ruby

files_to_fix = %w[
  citizen.rb
  doge_vsm.rb
  emergency_dispatch_center.rb
  fire_department.rb
  generic_department.rb
  health_department.rb
  house.rb
  local_bank.rb
  police_department.rb
  tip_line.rb
  visitor.rb
  smart_message_ai_agent.rb
  redis_monitor.rb
]

files_to_fix.each do |file|
  next unless File.exist?(file)
  
  content = File.read(file)
  
  # Fix smart_message paths
  content.gsub!(/require_relative\s+['\"]smart_message\/lib\/smart_message['\"]/, "require 'smart_message'")
  
  # Fix vsm paths
  content.gsub!(/require_relative\s+['\"]vsm\/lib\/vsm['\"]/, "require 'vsm'")
  
  File.write(file, content)
  puts "Fixed #{file}"
end
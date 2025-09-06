#!/usr/bin/env ruby

# Final comprehensive fix for all gem requires

files_with_issues = [
  'city_council/governance.rb',
  'city_council/cli_port.rb', 
  'city_council/operations.rb',
  'doge_vsm/intelligence.rb'
]

files_with_issues.each do |file|
  next unless File.exist?(file)
  
  content = File.read(file)
  changed = false
  
  # Fix VSM paths  
  if content.gsub!(/require_relative\s+['\"].*vsm\/lib\/vsm['\"]/, "require 'vsm'")
    changed = true
  end
  
  # Fix smart_message paths
  if content.gsub!(/require_relative\s+['\"].*smart_message\/lib\/smart_message['\"]/, "require 'smart_message'")
    changed = true
  end
  
  if changed
    File.write(file, content)
    puts "Fixed #{file}"
  end
end

puts "All remaining gem requires fixed!"
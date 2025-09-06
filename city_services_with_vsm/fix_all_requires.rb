#!/usr/bin/env ruby

# Fix all require_relative paths for smart_message and vsm

# Main directory files (need ../../ prefix)
main_files = Dir['*.rb']
main_files.each do |file|
  next unless File.exist?(file)
  
  content = File.read(file)
  changed = false
  
  # Fix smart_message paths in main directory
  if content.gsub!(/require_relative\s+['\"]smart_message\/lib\/smart_message['\"]/, "require 'smart_message'")
    changed = true
  end
  
  # Fix vsm paths in main directory  
  if content.gsub!(/require_relative\s+['\"]vsm\/lib\/vsm['\"]/, "require 'vsm'")
    changed = true
  end
  
  if changed
    File.write(file, content)
    puts "Fixed #{file}"
  end
end

# Messages directory files (need ../../../ prefix)
message_files = Dir['messages/*.rb']
message_files.each do |file|
  content = File.read(file)
  changed = false
  
  # Fix smart_message paths in messages directory
  if content.gsub!(/require_relative\s+['\"]\.\.\/smart_message\/lib\/smart_message['\"]/, "require 'smart_message'")
    changed = true
  end
  
  if changed
    File.write(file, content)
    puts "Fixed #{file}"
  end
end

# Common directory files (need ../../../ prefix if needed)
common_files = Dir['common/*.rb']
common_files.each do |file|
  content = File.read(file)
  changed = false
  
  # Fix smart_message paths in common directory  
  if content.gsub!(/require_relative\s+['\"]\.\.\/smart_message\/lib\/smart_message['\"]/, "require 'smart_message'")
    changed = true
  end
  
  if changed
    File.write(file, content)
    puts "Fixed #{file}"
  end
end

puts "All require paths fixed!"
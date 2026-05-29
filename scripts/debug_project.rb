#!/usr/bin/env ruby
require 'xcodeproj'
project = Xcodeproj::Project.open(File.expand_path('../Moblin.xcodeproj', __dir__))
puts "=== Main group children ==="
project.main_group.children.each do |c|
  puts "  name=#{c.respond_to?(:name) ? c.name.inspect : 'N/A'} | path=#{c.respond_to?(:path) ? c.path.inspect : 'N/A'} | display=#{c.display_name.inspect} | class=#{c.class}"
end
puts
puts "=== Targets ==="
project.targets.each { |t| puts "  #{t.name} (#{t.product_type})" }
puts
puts "=== Procurando arquivo Swift do Moblin pra ver onde fica ==="
moblin_target = project.targets.find { |t| t.name == 'Moblin' }
if moblin_target
  src_files = moblin_target.source_build_phase.files.first(5)
  src_files.each do |bf|
    next unless bf.file_ref
    puts "  ref name=#{bf.file_ref.name.inspect} path=#{bf.file_ref.path.inspect}"
    parent = bf.file_ref.parent
    while parent
      puts "    parent: name=#{parent.respond_to?(:name) ? parent.name.inspect : nil} path=#{parent.respond_to?(:path) ? parent.path.inspect : nil} class=#{parent.class}"
      parent = parent.respond_to?(:parent) ? parent.parent : nil
      break if parent.nil? || parent == project.main_group
    end
  end
end

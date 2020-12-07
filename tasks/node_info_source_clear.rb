#!/opt/puppetlabs/puppet/bin/ruby

require 'json'
require 'puppet'

params = JSON.parse(STDIN.read)

# Set parameters to local variables and resolve defaults if required
feed_type                           = params['feed_type'] || 'common'
key_field                           = params['key_field']
exclude_key_field                   = params['exclude_key_field'] || []
target_dir                          = params['target_dir'] || '/var/puppetlabs/data/node_info/validated'
refresh_node_info_on_removed_source = params['refresh_node_info_on_removed_source']

if feed_type && key_field
  filename = "#{target_dir}/#{key_field}~#{feed_type}.json"
elsif feed_type && key_field.nil?
  filename = "#{target_dir}/*~#{feed_type}.json"
elsif feed_type.nil? && key_field
  filename = "#{target_dir}/#{key_field}~*.json"
end

nodes_refresh = []
if target_dir && filename
  remove_files_list = Dir.glob(filename).reject { |f| exclude_key_field.include?(File.basename(f)) }
  remove_files_list.each do |f|
    if refresh_node_info_on_removed_source
      puts "Remove file and refresh node info #{f}"
    else
      puts "Remove file #{f}"
    end
    File.delete(f)
    node = f.split('~')[0]
    unless node.nil?
      nodes_refresh << File.basename(node)
      %x([[ \`ls #{node}~*.json | wc -l\` -eq 0 ]] || touch #{node}~*.json) if refresh_node_info_on_removed_source
    end
  end
end

puts 'Node info source clear completed.'
puts "\nnodes_refresh=#{nodes_refresh.join(',')}"

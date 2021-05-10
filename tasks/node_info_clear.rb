#!/opt/puppetlabs/puppet/bin/ruby
require 'rbconfig'
require 'json'

result = {}
result['exit_code'] = 0

IS_WINDOWS = (RbConfig::CONFIG['host_os'] =~ %r{mswin|mingw|cygwin})

$stdout.sync = true

node_info = if IS_WINDOWS
              'C:/ProgramData/PuppetLabs/facter/facts.d/node_info.yaml'
            else
              '/etc/puppetlabs/facter/facts.d/node_info.yaml'
            end

result['in'] = node_info

File.delete(node_info) if File.exist?(node_info)

result['out'] = 'Fact removed from this node'

puts result.to_json

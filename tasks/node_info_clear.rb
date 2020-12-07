#!/opt/puppetlabs/puppet/bin/ruby
require 'rbconfig'

IS_WINDOWS = (RbConfig::CONFIG['host_os'] =~ %r{mswin|mingw|cygwin})

$stdout.sync = true

node_info = if IS_WINDOWS
              'C:/ProgramData/PuppetLabs/facter/facts.d/node_info.yaml'
            else
              '/etc/puppetlabs/facter/facts.d/node_info.yaml'
            end

File.delete(node_info) if File.exist?(node_info)

puts 'Node_info fact removed from this node'

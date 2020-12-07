# @ node info facts
#
# @example
#   include node_info
class node_info (
  Optional[String]  $node_info_fact         = 'node_info',
  Optional[String]  $lookup_nodename_fact   = 'hostname',
) {
  # Prepare environment variable
  case $facts['kernel'] {
    'Linux', 'SunOS', 'AIX':  {
      $ensure_group = $facts['kernel']? { 'AIX' => 'system', default => 'root' }
      File {
        group  => $ensure_group,
        mode   => '0644',
      }
      $facters_dir      = ['/etc/puppetlabs/facter', '/etc/puppetlabs/facter/facts.d']
      $facters_dir.each | $f | {
        if !defined(File[$f]) {
          file { $facters_dir:
            ensure => directory,
            mode   => '0755',
          }
        }
      }
      $node_info_file = "/etc/puppetlabs/facter/facts.d/${node_info_fact}.yaml"
    }
    'windows':  {
      File {
        group  => 'Administrators',
      }
      $facters_dir = ['C:/ProgramData/PuppetLabs/facter', 'C:/ProgramData/PuppetLabs/facter/facts.d']
      $facters_dir.each | $f | {
        if !defined(File[$f]) {
          file { $f:
            ensure => directory,
          }
        }
      }
      $node_info_file = "C:/ProgramData/PuppetLabs/facter/facts.d/${node_info_fact}.yaml"
    }
    default: {
      fail('node_info: OS platform not implemented')
    }
  }

  if $facts[$node_info_fact] {
    $last_updated = $facts[$node_info_fact]['last_updated']
  } else {
    $last_updated = undef
  }
  $raw_node_info = node_info($facts[$lookup_nodename_fact].downcase, $last_updated )
  if $raw_node_info and !$raw_node_info.empty {
    $node_info = { $node_info_fact => merge($raw_node_info, {'last_updated' => Timestamp.new().strftime('%F %T %z', 'current')}) }
    file { $node_info_file:
      ensure  => file,
      content => $node_info.to_yaml,
    }
  }
}

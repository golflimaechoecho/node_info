# @summary load node_info from csv file
plan node_info::load_csv (
  Stdlib::Absolutepath  $csv_filename                     = '/var/puppetlabs/data/node_info/in/common_data.csv',
  Stdlib::Absolutepath  $target_dir                       = '/var/puppetlabs/data/node_info/validated',
  String                $feed_type                        = 'common',
  String                $key_field                        = 'hostname',
  Boolean               $basename                         = true,
  Boolean               $multiple                         = false,
  Boolean               $remove_existing_source_feed_type = false,
  Boolean               $post_puppet_run                  = false,
  String                $facts_lookup_field               = 'hostname',
  Integer               $puppetdb_query_limit             = 2000,
  Array[String]         $skipped_field                    = [],
  Boolean               $debug                            = false,
) {
  $nodes = puppetdb_query('inventory[facts.puppet_server] { facts.pe_build is not null limit 1}')[0]['facts.puppet_server']
  without_default_logging() || { run_plan('puppetdb_fact', 'targets' => $nodes) }

  out::message("Parameters: csv_filename = ${csv_filename}
                feed_type = ${feed_type}
                key_field = ${key_field}
                basename  = ${basename}
                multiple  = ${multiple}
                skipped_field = ${skipped_field}
                post_puppet_run = ${post_puppet_run}
                facts_lookup_field = ${facts_lookup_field}
                puppetdb_query_limit = ${puppetdb_query_limit}
                remove_existing_source_feed_type = ${remove_existing_source_feed_type}
                debug = ${debug}")

  if $remove_existing_source_feed_type {
    run_plan('node_info::source_clear',
              'feed_type'                  => $feed_type,
              'puppet_run_refreshed_nodes' => $post_puppet_run,
              'debug'                      => $debug
    )
  }

  $load_r = run_task('node_info::csv_handler', $nodes,
              'csv_filename'  => $csv_filename,
              'feed_type'     => $feed_type,
              'key_field'     => $key_field,
              'target_dir'    => $target_dir,
              'basename'      => $basename,
              'multiple'      => $multiple,
              'skipped_field' => $skipped_field,
              _catch_errors   => true
            )
  $message = pick(($load_r.find($nodes).value)['out'], '')

  if $debug { out::message('node_info: update node_info_source fact') }
  if $load_r.ok {
    # Trigger post puppet run on generated source_clear
    if $post_puppet_run {
      $nodes_refresh = pick(($load_r.find($nodes).value)['data']['generated'], [])
      if $debug { out::message("nodes_refresh yaml: ${nodes_refresh}") }
      unless $nodes_refresh.empty {
        $pdb = "facts[certname] { name = \"${facts_lookup_field}\" and
                                  value ~ \"(?i)${nodes_refresh.map |$k| { "${k}$" }.join('|')}\"
                                  limit ${$puppetdb_query_limit} }"
        if $debug { out::message("pdb: ${pdb}") }
        $certname_refresh = puppetdb_query($pdb).map |$k| { $k['certname'] }
        unless $certname_refresh.empty {
          run_task('node_info::ensure_job_run', $nodes,
                    'ensure'         => 'present',
                    'description'    => 'load_csv - post puppet run',
                    'scope'          => { 'nodes' => $certname_refresh },
                    'expected_state' => [ 'finished', 'failed' ],
                    'connected_only' => true,
                    'puppet_master'  => $nodes,
                  )
        }
      }
    }

    apply($nodes) {
      $today = Timestamp.new()

      $facters_dir = ['/etc/puppetlabs/facter', '/etc/puppetlabs/facter/facts.d']
      $facters_dir.each | $f | {
        if !defined(File[$f]) {
          file { $facters_dir:
            ensure => directory,
            mode   => '0755',
          }
        }
      }
      file { $target_dir:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0644'
      }

      $node_info_source_defaults = {
        $feed_type => {
          updated      => "${today.strftime('%F %T %z', 'current')}",
          target_dir   => $target_dir,
          csv_filename => $csv_filename,
          key_field    => $key_field,
          multiple     => $multiple,
          load_result  => $message,
        }
      }
      if $facts['node_info_source'] {
        $raw_node_info_source = $facts['node_info_source'] - $feed_type
        $node_info_source_data = { 'node_info_source' => $raw_node_info_source + $node_info_source_defaults }
      } else {
        $node_info_source_data = { 'node_info_source' => $node_info_source_defaults }
      }
      file { '/etc/puppetlabs/facter/facts.d/node_info_source.yaml':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => $node_info_source_data.to_yaml
      }
    }
  }

  return "Run succeeded: ${message}"
}

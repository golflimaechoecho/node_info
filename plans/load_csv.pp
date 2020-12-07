# plan load csv file
plan node_info::load_csv (
  Optional[Stdlib::Absolutepath]  $csv_filename                         = '/var/puppetlabs/data/node_info/in/common_data.csv',
  Optional[Stdlib::Absolutepath]  $target_dir                           = '/var/puppetlabs/data/node_info/validated',
  Optional[String]                $feed_type                            = 'common',
  Optional[String]                $key_field                            = 'hostname',
  Optional[Boolean]               $basename                             = true,
  Optional[Boolean]               $multiple                             = false,
  Optional[Boolean]               $remove_existing_source_feed_type     = false,
  Optional[Boolean]               $post_puppet_run                      = false,
  Optional[String]                $facts_lookup_field                   = 'hostname',
  Optional[Integer]               $puppetdb_query_limit                 = 2000,
  Optional[Array[String]]         $skipped_field                        = [],
  Optional[Boolean]               $debug                                = false,
) {
  $nodes = puppetdb_query('inventory[facts.puppet_server] { facts.pe_build is not null limit 1}')[0]['facts.puppet_server']
  #without_default_logging() || { run_plan('facts', 'targets' => $nodes) }
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
                      remove_existing_source_feed_type = ${remove_existing_source_feed_type}")

  if $remove_existing_source_feed_type {
    run_plan('node_info::source_clear','feed_type' => $feed_type )
  }

  if $debug { out::message('node_info: trigger csv_handler task') }
  $load_r = run_task  (
              'node_info::csv_handler',
              $nodes,
              'csv_filename'                        => $csv_filename,
              'feed_type'                           => $feed_type,
              'key_field'                           => $key_field,
              'target_dir'                          => $target_dir,
              'basename'                            => $basename,
              'multiple'                            => $multiple,
              'skipped_field'                       => $skipped_field,
              _catch_errors                         => true
            )
  $outs_result = $load_r.find($nodes).message()

  if $debug { out::message('node_info: update node_info_source fact') }
  if $load_r.ok {

    # Trigger post puppet run on generated source_clear
    if $post_puppet_run == true {
      $nodes_refresh_data = $load_r.find($nodes).message().split('\n').filter |$n| { $n =~ /Generated keyfield:/ }
      if $nodes_refresh_data.size > 0 and $nodes_refresh_data[0].split(':').size > 1 {
        $nodes_refresh = regsubst($nodes_refresh_data[0].split(':')[1], '[\[\] "]', '','G').split(',')
        unless $nodes_refresh.empty {
          $pdb = "facts[certname] { name = \"${facts_lookup_field}\" and 
                                    value in ${nodes_refresh.map |$k| { "\"${k}\"" }} 
                                    limit ${$puppetdb_query_limit} }"
          $certname_refresh = puppetdb_query($pdb).map |$k| { $k['certname'] }
          if $debug { out::message("job_run: ${certname_refresh}") }
          unless $certname_refresh.empty {
            $load_r1 = run_task  (
                        'node_info::ensure_job_run', $nodes,
                        'ensure'        => 'present',
                        'description'   => 'load_csv - post puppet run',
                        'scope'         => { 'nodes' => $certname_refresh },
                        'puppet_master' => $nodes,
                      )
          }
        }
      }
    }

    apply($nodes) {
      $today = Timestamp.new()

      $facters_dir      = ['/etc/puppetlabs/facter', '/etc/puppetlabs/facter/facts.d']
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

      if $facts['node_info_source'] {
        $raw_node_info_source = $facts['node_info_source'] - $feed_type
        $node_info_source_data = { 'node_info_source' => $raw_node_info_source + { $feed_type => {
                                    updated       => "${today.strftime('%F %T %z', 'current')}",
                                    target_dir    => $target_dir,
                                    csv_filename  => $csv_filename,
                                    key_field     => $key_field,
                                    multiple      => $multiple,
                                    load_result   => $outs_result
                                  } } }
      } else {
        $node_info_source_data = { 'node_info_source' => { $feed_type => {
                                    updated       => "${today.strftime('%F %T %z', 'current')}",
                                    target_dir    => $target_dir,
                                    csv_filename  => $csv_filename,
                                    key_field     => $key_field,
                                    multiple      => $multiple,
                                    load_result   => $outs_result
                                  } } }
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

  return $outs_result
}

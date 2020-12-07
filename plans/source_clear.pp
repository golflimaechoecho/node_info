# plan export csv file
plan node_info::source_clear (
  Optional[String]                $feed_type                            = 'common',
  Optional[String]                $key_field                            = undef,
  Optional[Array[String]]         $exclude_key_field                    = [],
  Optional[Stdlib::Absolutepath]  $target_dir                           = '/var/puppetlabs/data/node_info/validated',
  Optional[Boolean]               $refresh_node_info_on_removed_source  = true,
  Optional[Boolean]               $puppet_run_refreshed_nodes           = true,
  Optional[String]                $facts_lookup_field                   = 'hostname',
  Optional[Integer]               $puppetdb_query_limit                 = 2000,
  Optional[Boolean]               $debug                                = false,
) {
  $nodes = puppetdb_query('inventory[facts.puppet_server] { facts.pe_build is not null limit 1}')[0]['facts.puppet_server']

  out::message("Parameters: feed_type = ${feed_type}
                      key_field = ${key_field}
                      exclude_key_field  = ${exclude_key_field}
                      target_dir  = ${target_dir}
                      refresh_node_info_on_removed_source = ${refresh_node_info_on_removed_source}}")

  if $debug { out::message('source_clear: node_info_source_clear task') }
  $load_r = run_task  (
              'node_info::node_info_source_clear', $nodes,
              'feed_type'                           => $feed_type,
              'key_field'                           => $key_field,
              'exclude_key_field'                   => $exclude_key_field,
              'target_dir'                          => $target_dir,
              'refresh_node_info_on_removed_source' => $refresh_node_info_on_removed_source,
            )
  if $load_r.ok and $puppet_run_refreshed_nodes {
    $nodes_refresh_data = $load_r.find($nodes).message().split('\n').filter |$n| { $n =~ /nodes_refresh=/ }
    if $nodes_refresh_data.size > 0 and $nodes_refresh_data[0].split('=').size > 1 {
      $nodes_refresh = ($nodes_refresh_data[0].split('=')[1]).split(',')
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
                      'description'   => 'source_clear - node info refresh run',
                      'scope'         => { 'nodes' => $certname_refresh },
                      'puppet_master' => $nodes,
                    )
        }
      }
    }
  }
  return $load_r.find($nodes).message()
}

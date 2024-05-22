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

  $load_r = run_task  (
              'node_info::node_info_source_clear', $nodes,
              'feed_type'                           => $feed_type,
              'key_field'                           => $key_field,
              'exclude_key_field'                   => $exclude_key_field,
              'target_dir'                          => $target_dir,
              'refresh_node_info_on_removed_source' => $refresh_node_info_on_removed_source,
            )
  if $load_r.ok and $puppet_run_refreshed_nodes {
    if $debug { out::message("tasks resultset: ${load_r.find($nodes)}") }
    $nodes_refresh = pick(($load_r.find($nodes).value)['data']['nodes_refresh'], [])
    if $debug { out::message("nodes_refresh yaml: ${nodes_refresh}") }

    unless $nodes_refresh.empty {
      $pdb = "facts[certname] { name = \"${facts_lookup_field}\" and 
                                value ~ \"(?i)${nodes_refresh.map |$k| { "${k}$" }.join('|')}\"
                                limit ${$puppetdb_query_limit} }"
      out::message($pdb)
      $refresh_test = catch_errors() || {
        $certname_refresh = puppetdb_query($pdb).map |$k| { $k['certname'] }
      }
      out::message($refresh_test)
      fail_plan('stop here for now')
      if $debug { out::message("job_run: ${certname_refresh}") }
      unless $certname_refresh.empty {
        $load_r1 = run_task  (
                    'node_info::ensure_job_run', $nodes,
                    'ensure'        => 'present',
                    'description'   => 'source_clear - node info refresh run',
                    'scope'         => { 'nodes' => $certname_refresh },
                    'expected_state'  => [ 'finished', 'failed' ],
                    'puppet_master' => $nodes,
                  )
      }
    }
  }

  return "Run succeeded: ${pick(($load_r.find($nodes).value)['out'],'')}"
}

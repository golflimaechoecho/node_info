# plan export csv file
plan node_info::export_csv (
  Array[String]                   $facts_list           = ['facts.node_info.cmdb'],
  Optional[Stdlib::Absolutepath]  $target_dir           = '/var/puppetlabs/data/node_info/out',
  Optional[Integer]               $puppetdb_query_limit = 2000,
  Optional[Boolean]               $debug                = true,
) {
  $nodes = puppetdb_query('inventory[facts.puppet_server] { facts.pe_build is not null limit 1}')[0]['facts.puppet_server']

  $facts_list.each |$k| {
    if $debug { out::message("node_info: retreive fact nodes ${k}") }
    $nodes_fact =
      puppetdb_query( "inventory[
                        certname,
                        ${k}
                      ] { ${k} is not null limit ${$puppetdb_query_limit} }"
                    )

    if $nodes_fact.empty {
      out::message("node_info: no ${k} records")
    } else {
      out::message("node_info: ${k} - ${nodes_fact.size} founds")
      apply($nodes) {
        file { $target_dir:
          ensure => directory,
          owner  => 'root',
          group  => 'root',
          mode   => '0644'
        }
        file { "${target_dir}/${k}.csv":
          ensure   => file,
          owner    => 'root',
          group    => 'root',
          mode     => '0644',
          loglevel => 'debug',
          content  => epp('node_info/hash_to_csv.epp', { 'data'  => $nodes_fact, 'key' => $k }  )
        }
      }
    }
  }
}

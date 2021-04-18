# plan export csv file
plan node_info::export_csv (
  Array[String]                   $facts_list           = ['node_info.cmdb'],
  Optional[Stdlib::Absolutepath]  $target_dir           = '/var/puppetlabs/data/node_info/out',
  Optional[Integer]               $puppetdb_query_limit = 2000,
  Optional[Boolean]               $debug                = false,
) {
  $nodes = puppetdb_query('inventory[facts.puppet_server] { facts.pe_build is not null limit 1}')[0]['facts.puppet_server']

  out::message("Parameters: facts_list = ${facts_list}
                            target_dir = ${target_dir}
                            puppetdb_query_limit = ${puppetdb_query_limit}
                            debug = ${debug}")

  $facts_list.each |$k| {
    $nodes_fact = puppetdb_query( "inventory[certname, facts.${k}] { facts.${k} is not null limit ${$puppetdb_query_limit} }" )
    unless $nodes_fact.empty {
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
          content  => epp('node_info/hash_to_csv.epp', { 'data'  => $nodes_fact, 'key' => "facts.${k}" }  )
        }
      }
      out::message("exported: ${target_dir}/${k}.csv - ${nodes_fact.size} records")
    } else {
      out::message("fact: ${k} no record found")
    }
  }
}

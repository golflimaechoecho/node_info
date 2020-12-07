# node_info

A node information publisher to prepared node facts.

## Table of Contents

1. [Description](#description)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module publish node fact from a data directory on Puppet Server. You can load multiple sources/files of information like CMDB, AWS tags, patching schedule, backup/snapshot and etc, limited to your data type that relavent to your usage/implementation. Currently only handle CSV file format.

The sources feed require to contain a key field that associate with an existing fact string, facts like certname, hostname, ipaddress. defaulted to hostname.

Declaring node_info class will prepare a node_info.yaml file on following directory, only when lookup fact matches master source datas. node_info fact only refresh when there is changes on master sources based on last modified dated.

UNIX:

```text
/etc/puppetlabs/facter/facts.d/<node_info_fact>.yaml
```

Windows:

```text
C:\ProgramData\PuppetLabs\puppet\cache\facts.d\<<node_info_fact>.yaml
```

## Usage

1. Configure a unique fact name, default 'node_info'
1. Update the lookup name to query the data source, default hostname

```yaml
node_info::node_info_fact: abcbank_info
node_info::lookup_nodename_fact: hostname
```

### Load CSV

1. Upload CSV file to Puppet server, default folder `/var/puppetlabs/data/node_info/in`
1. Trigger plan `node_info::load_csv`, you can specify following optional parameters:

* csv_filename [Stdlib::Absolutepath], CSV absolute path with filename, Default: `/var/puppetlabs/data/node_info/in/cmdb_data.csv`
* feed_type [String], Free text feed type, Default: `cmdb`
* key_field [String], Source key field column, Default: `servername`
* target_dir [Stdlib::Absolutepath], Validated directory, Default: `/var/puppetlabs/data/node_info/validated`
* basename [Boolean], Select basename on key_field, Default: true
* multiple [Boolean], Allow multiple recoards on same key_field and handle it as Hash of Array
* log_feed [Boolean], Logging feed name that being loaded

Verify plan result output, each successful validated data entry represented with a single dot. Ensure key_field param was specified correctly. Successful validated information will stored under default folder `/var/puppetlabs/data/node_info/validate`. Exmaple output,

```text
Parsed CSV data count: 395
header entry: [:running_no, :asset_no, :localtion, :station, :tire, :hypervisor, :aplication_name, :server_environment, :machine_type, :serverhostname, :status, :domain, :hardening, :ou_policy, :cricitical_system, :ma_warranty, :application_owner_1, :application_owner_2, :remark]
...................................................................................................................................................
```

### Node info source summary

For each source feed loaded, a summary will created `node_info_source`

```text
```

## Development

Just fork and raise a PR.

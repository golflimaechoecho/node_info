# node_info

A node information publisher to prepared node facts.

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
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

## Setup

Declare `node_info` class and update node_info Hiera.

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
* feed_type [String], Free text feed type, Default: `common`
* key_field [String], Source key field column, Default: `hostname`
* facts_lookup_field [String], fact name lookup matched key_field, Default: `hostname`
* target_dir [Stdlib::Absolutepath], Validated directory, Default: `/var/puppetlabs/data/node_info/validated`
* basename [Boolean], Select basename on key_field, Default: true
* multiple [Boolean], Allow multiple recoards on same key_field and handle it as Hash of Array
* log_feed [Boolean], Logging feed name that being loaded
* post_puppet_run[Boolean], trigger Puppet run after loading successfully, for key_field matched facts_lookup_field with certname. Limitted to orchestrator target nodes size
* puppetdb_query_limit[Integer], limiter on nodes loader
* remove_existing_source_feed_type[Boolean], Remove existing soure feed type before loading new sets of data.
* debug[Boolean], enable additional logging message, Default: false

Verify plan result output, Ensure key_field param was specified correctly. Successful validated information will stored under default folder `/var/puppetlabs/data/node_info/validate`. Exmaple output,

```text
Parse data count: 3
CSV Header: ["hostname", "patch_scheduled_date", "notify_recipient_email", "reboot_scheduled_date"]

Unchanged: 0
Changed: 3
Duplicate: 0
Error: 0
New: 0

Generated keyfield: ["tst01", "tst02", "tst01-win2016"]

Changed keyfield: ["tst01", "tst02", "tst01-win2016"]
```

### Node info source summary

For each source feed loaded, a summary will created `node_info_source`

```text
{
  "cmdb" : {
    "csv_filename" : "/var/puppetlabs/data/node_info/in/cmdb_data.csv",
    "key_field" : "server_name",
    "load_result" : [ {
      "_output" : "Data count: 4\nHeader: [:server_name, :role, :business_criticality, :environment, :datacenter, :location, :status, :application_name, :application_owner_1, :application_owner_2, :remark]\nPrepare feed type 'cmdb' on 'server_name' :mom gitlab tst01 tst01-win2016 \n"
    } ],
    "multiple" : true,
    "target_dir" : "/var/puppetlabs/data/node_info/validated",
    "updated" : "2020-11-11 14:43:56 +0800"
  },
  "patching" : {
    "csv_filename" : "/var/puppetlabs/data/node_info/in/patching.csv",
    "key_field" : "hostname",
    "load_result" : "\nParse data count: 3\nCSV Header: [\"hostname\", \"patch_scheduled_date\", \"notify_recipient_email\", \"reboot_scheduled_date\"]\n\nUnchanged: 0\nChanged: 3\nDuplicate: 0\nError: 0\nNew: 0\n\nGenerated keyfield: [\"tst01\", \"tst02\", \"tst01-win2016\"]\n\nChanged keyfield: [\"tst01\", \"tst02\", \"tst01-win2016\"]\n",
    "multiple" : false,
    "target_dir" : "/var/puppetlabs/data/node_info/validated",
    "updated" : "2021-03-08 08:33:20 +0800"
  },
  "snapshot" : {
    "csv_filename" : "/var/puppetlabs/data/node_info/in/nutanix_snapshot_nutanixcvm.csv",
    "key_field" : "hostname",
    "load_result" : "\nParse data count: 2\nCSV Header: [\"vm\", \"vm_uuid\", \"name\", \"description\", \"created\", \"deleted\", \"hostname\"]\n\nUnchanged: 1\nChanged: 0\nMultiple: 1\nError: 0\nNew: 0\n\nGenerated keyfield: [\"tst03\"]\n\nChanged keyfield: []\nMultiple keyfield: [\"tst03\"]\n",
    "multiple" : true,
    "target_dir" : "/var/puppetlabs/data/node_info/validated",
    "updated" : "2020-12-26 17:23:11 +0800"
  }
}
```

## Development

Just fork and raise a PR.

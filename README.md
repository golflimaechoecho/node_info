# node_info

A node information publisher to prepared node facts.

## Table of Contents

1. [Description](#description)
1. [Setup](#setup)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module prepare facts from a Puppet Server directory. You can load multiple sources `feed_type` of information, cmdb, tags, schedules, backup/snapshot thru a CSV flat files. The CSV file require a identifier `key_field` to associate with Puppet agent fact using `lookup_nodename_fact` default to `hostname`, You can uses other fact `certname`, `ipaddress` and limited to one agent fact.

## Setup

Declare `node_info` class, will prepare a node_info.yaml when there any relevant data found that belong to the agents. node_info only refreshed when there was changes on sources.

UNIX: `/etc/puppetlabs/facter/facts.d/node_info.yaml`
Windows: `C:\ProgramData\PuppetLabs\puppet\cache\facts.d\node_info.yaml`

### Parameters

This module uses local module hiera in data/common.yaml. Bring custom parameter into your own control repositories or classification configuration.

1. Pick a name or uses the default `node_info` in `node_info_fact`
1. Update `lookup_nodename_fact` to associate with the `key_field` from data sources, default uses `hostname`.

```yaml
node_info::node_info_fact: node_info
node_info::lookup_nodename_fact: hostname
```

### Load data

You can prepare multiples CSV files with unique `feed_type`, The CSV file need to be visible on Puppet server.

1. Upload CSV file to Puppet server's default folder `/var/puppetlabs/data/node_info/in`.
2. Trigger plan `node_info::load_csv`, you can specify following optional parameters:

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

Example, prepare plan param file load_csv_cmdb.json and trigger using `puppet plan run node_info::load_csv --params @load_csv_cmdb.json`,

```json
{
  "csv_filename": "/var/puppetlabs/data/node_info/in/cmdb_data.csv",
  "feed_type": "cmdb",
  "key_field": "server_name",
  "post_puppet_run": true,
  "skipped_field": ["server_name","vm"]  
}
```

Verify plan result for any error or duplicate CSV entry, ensure `key_field` param was specified correctly. Valid data stored under `/var/puppetlabs/data/node_info/validate` and invalid data will store under `/var/puppetlabs/data/node_info/out`.

```text
Run succeeded: {csv_header => [server_name, role, business_criticality, environment, datacenter, location, status, application_name, application_owner_1, application_owner_2, remark], total_size => 4, unchanged => 3, changed => 0, duplicate => 0, error => 0, new => 1}
```

For each data sources loaded a record will created under `node_info_source` fact on Puppet server.

```json
{
  "cmdb" : {
    "csv_filename" : "/var/puppetlabs/data/node_info/in/cmdb_data.csv",
    "key_field" : "server_name",
    "load_result" : {
      "changed" : 0,
      "csv_header" : [ "server_name", "role", "business_criticality", "environment", "datacenter", "location", "status", "application_name", "application_owner_1", "application_owner_2", "remark" ],
      "duplicate" : 0,
      "error" : 0,
      "new" : 0,
      "total_size" : 4,
      "unchanged" : 4
    },
    "multiple" : false,
    "target_dir" : "/var/puppetlabs/data/node_info/validated",
    "updated" : "2021-04-18 18:37:14 +0800"
  }
}
```

### Node info fact

On agent, following example node_info contain 2 `feed_type` cmdb and snapshot.

```json
{
  "cmdb" : {
    "application_name" : "Test base - RHEL family",
    "business_criticality" : "1-Negligible",
    "datacenter" : "VM01",
    "environment" : "UAT",
    "location" : "Singapore",
    "role" : "tst-base",
    "status" : "Live"
  },
  "last_updated" : "2021-04-18 16:14:33 +0800",
  "snapshot" : {
    "created" : "8/1/2019 4:53:35 PM",
    "description" : "Security Finding",
    "hostname" : "tst01",
    "iscurrent" : "True",
    "name" : "SNAPSHOT BEFORE HARDEN",
    "powerstate" : "PoweredOn",
    "sizemb" : 75732.1372499466,
    "vm" : "tst01"
  }
}
```

## Limitation

* Only support one `lookup_nodename_fact`
* On Puppet compiler, File_sync `validated` folder require from Puppet Master.

## Development

Just fork and raise a PR.

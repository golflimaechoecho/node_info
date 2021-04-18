# Changelog

All notable changes to this project will be documented in this file.

## 2021-03-02 Release 0.2.2

### Features 0.2.2

- Improve deploy puppet job run, now tasks can wait until jobs reach expected states, example `finished`, `failed` or tasks will timeout in `state_wait_timeout` cycle with `state_wait_sleep` in seconds.

### Bugfix 0.2.2

- Serialize tasks result.

## 2021-03-02 Release 0.2.1

### Features 0.2.1

- covert to PDK 2

### Bugfix 0.2.1

- Update module metadata and README doc

## 2020-12-08 Release 0.2.0

### Bugfix 0.2.0

- Improve node_info function warning logging
- change case insensitve on key_field for post_run and source_clear

## 2020-10-19 Release 0.1.0

### Features - 0.1.0

- Initial release

***Known Issues**

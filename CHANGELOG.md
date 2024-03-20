# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- input experimental datasets can be specified as multiple vcfs with the same identifier on multiple rows.
  the corresponding vcfs will be concatenated and sorted before use. the intended use case of this functionality
  is on-the-fly combination of single-sample single-chromosome vcfs.

### Changed

- user configuration is fairly heavily refactored to be more legible/less susceptible to typos
- rule resources refactored to expose to userspace configuration

### Fixed

- lazy ftp access of stratification regions is changed to much better per-file tracking
  of regions and access by https

## [0.1.0]

### Added

- comparisons using hap.py with vcfeval engine
- NIST stratification sets
- customizable confidence regions
- markdown reports containing customizable subsets of stratifications

[//]: # [Unreleased]

[//]: # (- Added)
[//]: # (- Changed)
[//]: # (- Deprecated)
[//]: # (- Removed)
[//]: # (- Fixed)
[//]: # (- Security)

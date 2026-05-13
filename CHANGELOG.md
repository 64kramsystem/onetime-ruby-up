# Changelog

## [Unreleased]

### Fixed

- Update library callers to API v2 response shapes (`record.receipt`, `record.secret`, reveal `record.secret_value`)
- Restore `apiversion` path handling for callers that pass an API version explicitly
- Add safer CLI response handling for changed or partial API responses
- Accept secret URLs from root and regional onetimesecret.com hosts

## [0.6.0] - 2026-01-18

### Added

Major/breaking changes:

- Upgrade to API v2
- Rename command "metadata" to "receipt"
- Change the default API host from the root service to the EU region (`https://eu.onetimesecret.com/api`)

Other changes:

- Add opt-in official API contract validation for v2 endpoint shapes
- Remove Rakefile, signing data and Jeweler references
- Simplified and modernized gemspec (set minimum Ruby to 3.2)
- Add Gemfile
- Remove json gem dependency
- Api: Deduplicate any number of consecutive slashes
- Add RSpec and test suites
- Upgrade dependencies
- Update gem metadata and README following project rename
- Upgrade version, and simplify its handling

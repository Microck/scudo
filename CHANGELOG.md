# CHANGELOG

All notable changes to scudo are documented here.

## [0.2.0] - 2026-04-03

### Added
- **WPF GUI surface** - New graphical hardening console with dedicated detail panel and clearer control hierarchy
- **Transcript-backed hardening UX** - CLI now uses transcript recording for audit trails
- **One-line bootstrap** - `irm ... | iex` pattern for instant setup
- **Windows 11 IoT detection** - Improved device detection for IoT editions
- **Browser state persistence** - Saves/restores browser configuration state

### Changed
- **Refined hardening flows** - Improved automation for control application
- **Updated branding assets** - New banner and logo assets

### Fixed
- **Windows brush conversion** - Fixed GUI launch issue on some configurations

## [0.1.0] - 2026-04-01

### Added
- Initial release
- CLI and menu interface
- 27 security controls across 8 sections
- Baseline and strict presets
- Rollback snapshots
- Markdown and JSON export
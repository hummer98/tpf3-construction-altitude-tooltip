# Changelog

All notable changes to Construction Altitude Tooltip are recorded here. The
format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
the mod uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html). The
mod's `revision` in `mod.json` is MAJOR * 10000 + MINOR * 100 + PATCH.

## [Unreleased]

### Changed
- The mod's name in the game's mod list and on mod.io is now English only:
  "Construction Altitude Tooltip". The Japanese name (建設時の標高表示)
  stays in the description and the README, and the summary keeps its
  Japanese half.

## [1.0.0] - 2026-11-18

Published on mod.io and GitHub as revision 1, before the mod had version
numbers; versioned releases start with 1.0.1 (revision 10001).

### Added
- First public release. While you place a building (stations, depots and
  other constructions, templates included), the cursor tooltip shows the
  altitude of the placement point below the cost, with one decimal in the
  game's own altitude format.
- The value follows the toolbar **Height** slider.
- For a template with several buildings, the position of one of them is
  used. Roads, tracks, terrain and the other tools are not changed.
- The tooltip label in the game's 13 languages.
- GUI only: safe to add to and remove from a running save.

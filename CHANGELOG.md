# Changelog

All notable changes to MyToken. Format: [Keep a Changelog](https://keepachangelog.com/).

## [1.0.0] — 2026-10-19

### Added
- ERC-20 token (`MyToken` / `MTK`) with 1000 initial supply
- `ERC20Capped` — 2000 MTK hard ceiling
- `Ownable` — mint and pause restricted to owner
- `ERC20Burnable` — holders can burn tokens
- `ERC20Pausable` — owner can halt balance changes
- Foundry deploy script and 15 passing tests with exact custom-error assertions
- GitHub Actions CI (`forge fmt --check`, `forge build`, `forge test`)

### Design notes
- `_update` override resolves `ERC20Capped` and `ERC20Pausable` in that order:
  pause check → cap check → balance accounting. Pause-first ensures a paused
  token rejects every balance change uniformly.
- Tests assert exact custom error selectors and arguments, not just that
  the call reverted, so any future change to a guard's behavior fails loudly.

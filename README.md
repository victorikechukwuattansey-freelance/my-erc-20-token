# MyToken (MTK)

A production-shaped ERC-20 token built with [Foundry](https://book.getfoundry.sh/)
and [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) 5.x.

- **Name:** MyToken
- **Symbol:** MTK
- **Decimals:** 18
- **Initial Supply:** 1000 MTK (minted to deployer at construction)
- **Cap:** 2000 MTK (hard ceiling, enforced by `ERC20Capped`)

## Extensions

`MyToken` composes five OpenZeppelin building blocks:

| Extension | Purpose |
| :--- | :--- |
| `ERC20` | Base token standard — balances, transfers, approvals |
| `ERC20Capped` | Enforces a hard supply ceiling on every mint |
| `Ownable` | Restricts `mint`, `pause`, `unpause` to the owner |
| `ERC20Burnable` | Holders can destroy their own tokens |
| `ERC20Pausable` | Owner can halt all balance changes |
| `ERC20Permit` | EIP-2612 signature-based approvals (gasless `approve`) |

## Design

All balance changes — transfer, mint, burn — funnel through the virtual
`_update` function. `ERC20Capped` and `ERC20Pausable` both override it,
so `MyToken` declares the resolution order explicitly:

```solidity
function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Capped, ERC20Pausable)
{
    super._update(from, to, value);
}
```

At runtime the call chain is:

```
MyToken._update
  → ERC20Pausable._update   (EnforcedPause if paused)
  → ERC20Capped._update     (ERC20ExceededCap if mint exceeds cap)
  → ERC20._update           (balance accounting + emit Transfer)
```

**Pause-first is intentional.** A paused token should reject every
balance change with a single, unambiguous `EnforcedPause` error — not
surface a cap error for the subset of calls that happen to be mints.

`ERC20Permit` does **not** override `_update`. It adds `permit()` as a
new entry point that routes through `_approve`, so it isn't part of the
override list. Same for `ERC20Burnable` — it adds `burn()` and
`burnFrom()` as new entry points that call `_burn` (which itself calls
`_update`).

## Test coverage

`test/MyToken.t.sol` — 19 tests, all passing under `forge test`:

| Test | What it verifies |
| :--- | :--- |
| `test_InitialSupply` | 1000 MTK minted to the deployer at construction |
| `test_Transfer` | `transfer` moves tokens and updates both balances |
| `test_RevertWhen_TransferToZeroAddress` | `transfer` to `address(0)` reverts |
| `test_RevertWhen_InsufficientBalance` | `transfer` beyond balance reverts |
| `test_Approve` | `approve` sets an allowance |
| `test_TransferFrom` | `transferFrom` moves tokens and decrements allowance |
| `test_RevertWhen_InsufficientAllowance` | `transferFrom` with no allowance reverts |
| `test_MintUpToCap` | Minting below the cap increases supply |
| `test_RevertWhen_MintExceedsCap` | Minting above the cap reverts with `ERC20ExceededCap(attempted, cap)` |
| `test_RevertWhen_NonOwnerMints` | Non-owners revert with `OwnableUnauthorizedAccount` on `mint` |
| `test_BurnReducesSupplyAndBalance` | `burn` reduces both caller balance and `totalSupply` |
| `test_RevertWhen_BurnExceedsBalance` | `burn` beyond balance reverts with `ERC20InsufficientBalance` |
| `test_RevertWhen_TransferWhilePaused` | `transfer` reverts with `EnforcedPause` while paused |
| `test_TransferAfterUnpause` | `unpause` restores transfers |
| `test_RevertWhen_NonOwnerPauses` | Non-owners revert with `OwnableUnauthorizedAccount` on `pause` |
| `test_PermitSetsAllowance` | Valid signature sets allowance and increments nonce |
| `test_RevertWhen_PermitReplayed` | Reused signature reverts (nonce consumed) |
| `test_RevertWhen_PermitExpired` | Expired deadline reverts |
| `test_RevertWhen_PermitWrongSigner` | Signature from wrong key reverts |

Revert-mode tests assert the **exact custom error selector and arguments**,
not just that the call reverted. For example, `test_RevertWhen_MintExceedsCap`
asserts `ERC20ExceededCap(2500e18, 2000e18)` — the same two values returned
by a live `cast send` against a local Anvil node.

## Deployed addresses

| Network | Address | Verified |
| :--- | :--- | :--- |
| Sepolia | `0xBdD7E89be61dA8fe4f66388fdd4dDFac77933d61` | [Etherscan](https://sepolia.etherscan.io/address/0xBdD7E89be61dA8fe4f66388fdd4dDFac77933d61) |

### Deployment notes

`forge create` undercounts gas for contract creation on Sepolia. The
bytecode size (~12KB) requires roughly 20M gas to deploy; the default
estimate is ~2.7M, and a 10M limit still hit `OutOfGas`. Use:

    forge create src/MyToken.sol:MyToken \
      --rpc-url sepolia \
      --account deployer \
      --broadcast \
      --gas-limit 20000000 \
      --constructor-args 1000000000000000000000 2000000000000000000000

`forge script` fails on Sepolia for the same reason — its simulation
reverts with `OutOfGas` before broadcasting, and `--gas-limit` does not
override the simulated transaction's limit.

## Usage

```bash
forge build         # compile
forge test -vv      # run tests (with traces)
forge fmt --check   # verify formatting (same check CI runs)
```

### Deploy to a local Anvil node

```bash
# Terminal 1 — start a local chain
anvil

# Terminal 2 — deploy
forge script script/DeployMyToken.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast

# Query it
export TOKEN=<deployed address>
export RPC=http://localhost:8545
cast call $TOKEN "totalSupply()(uint256)" --rpc-url $RPC
cast call $TOKEN "cap()(uint256)"         --rpc-url $RPC
```

### Deploy to Sepolia

```bash
# Fund a fresh wallet from a Sepolia faucet, then:
cast wallet import deployer --interactive

export SEPOLIA_RPC=https://ethereum-sepolia.publicnode.com
export ETHERSCAN_API_KEY=<key from etherscan.io/myapikey>

forge script script/DeployMyToken.s.sol \
  --account deployer \
  --broadcast \
  --rpc-url $SEPOLIA_RPC \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Engineering process

This repo was built as a first-principles exercise: start from the ERC-20
spec, implement the minimal token, then extend it deliberately. The git
history reads as the process narrative:

- Baseline token: minimal `ERC20` with a constructor mint, 7 tests
- Sabotage `_update` and watch a single invariant fail (debugging tests)
- Extend with `ERC20Capped` via Red → Green → Refactor TDD
- Tighten the cap test to assert the exact custom error selector
- Add a deploy script and exercise the cap against Anvil
- Add `Ownable` to close the "anyone can mint" vulnerability
- Add `ERC20Burnable` — the symmetric counterpart to mint in `_update`
- Add `ERC20Pausable` — reason through multi-parent override ordering
- Add `ERC20Permit` — EIP-2612 gasless approvals
- Merge `leverage-lab` into `main` as a single unit
- Tag `v1.0.0`, then `v1.1.0` after Permit + Sepolia

The commit messages on `main` and the merge commit graph preserve the
reasoning, not just the code.

## Known limitations

- No fee-on-transfer, no reflection, no governance/voting — this is a
  plain ERC-20 with standard safety extensions, not a DeFi primitive.
- No `ERC20Votes` / `ERC20FlashMint`. Both are available in
  OpenZeppelin and follow the same extension pattern if needed.

## CI

Every push runs `forge fmt --check`, `forge build`, and `forge test` via
`.github/workflows/test.yml`.

## License

MIT

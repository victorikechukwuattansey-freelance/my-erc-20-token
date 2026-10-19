# MyToken (MTK)

A capped ERC-20 token built with [Foundry](https://book.getfoundry.sh/) and
[OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/) 5.x.

- **Name:** MyToken
- **Symbol:** MTK
- **Decimals:** 18
- **Initial Supply:** 1000 MTK (minted to deployer at construction)
- **Cap:** 2000 MTK (hard ceiling, enforced by `ERC20Capped`)

## Design

`MyToken` is composed from two OpenZeppelin building blocks:

- `ERC20` — the base token standard
- `ERC20Capped` — enforces a hard supply ceiling on every mint

All balance changes (transfer, mint, burn) funnel through the virtual
`_update` function. Because both `ERC20` and `ERC20Capped` override it,
`MyToken` declares the resolution order explicitly:

```solidity
function _update(address from, address to, uint256 value)
    internal
    override(ERC20, ERC20Capped)
{
    super._update(from, to, value);
}
```

At runtime the call chain is:

```
MyToken._update → ERC20Capped._update (cap check) → ERC20._update (accounting + event)
```

## Test coverage

`test/MyToken.t.sol` — 9 tests, all passing under `forge test`:

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
| `test_RevertWhen_MintExceedsCap` | Minting above the cap reverts with the exact `ERC20ExceededCap(attempted, cap)` error |
| `test_RevertWhen_NonOwnerMints` | Only the owner can mint; non-owners revert with `OwnableUnauthorizedAccount` |

The last test asserts the custom error selector and its arguments — the
same `(2500e18, 2000e18)` values returned by a live `cast send` against
a local Anvil node.

## Usage

```bash
forge build         # compile
forge test -vv      # run tests (with traces)
forge fmt --check   # verify formatting (the same check CI runs)
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

## Engineering process

This repo was built as a first-principles exercise: start from the
ERC-20 spec, implement the minimal token, then extend it deliberately.
The git log on this branch reads as the process narrative:

- Sabotage `_update` and watch a single invariant fail
- Extend with `ERC20Capped` via Red → Green → Refactor TDD
- Tighten the cap test to assert the exact custom error selector
- Add a deploy script and exercise the cap on Anvil
- (next) Add `Ownable` access control to `mint`

## Known limitations

- `mint` is restricted to the owner (`Ownable`). Ownership is assigned to
  the deployer at construction; transfer via `transferOwnership`.
- No burn, no pause, no permit (EIP-2612).

## CI

Every push runs `forge fmt --check`, `forge build`, and `forge test` via
`.github/workflows/test.yml`.

## License

MIT

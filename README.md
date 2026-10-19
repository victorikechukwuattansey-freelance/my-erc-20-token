# MyToken (MTK)

A minimal ERC-20 token built with [Foundry](https://book.getfoundry.sh/)
and [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/).

- **Name:** MyToken
- **Symbol:** MTK
- **Decimals:** 18
- **Initial Supply:** 1000 MTK (minted to deployer)

## Design

Composition over reinvention: `MyToken` inherits the audited
`ERC20` implementation from OpenZeppelin 5.x and adds only a
constructor that mints the initial supply to `msg.sender`.

## Test coverage

`test/MyToken.t.sol` proves the 7 core behaviours of the standard:

1. Initial supply is minted to the deployer
2. `transfer` moves tokens and updates balances
3. `transfer` to the zero address reverts
4. `transfer` with insufficient balance reverts
5. `approve` sets an allowance
6. `transferFrom` moves tokens and decrements the allowance
7. `transferFrom` with insufficient allowance reverts

## Usage

```bash
forge build      # compile
forge test -vv   # run tests
forge fmt --check # verify formatting (same as CI)

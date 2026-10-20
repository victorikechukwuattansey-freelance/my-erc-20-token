// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    constructor(bytes32 _domainSeparator) {
        DOMAIN_SEPARATOR = _domainSeparator;
    }

    function getStructHash(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));
    }

    function getTypedDataHash(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    function getDigest(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        external
        view
        returns (bytes32)
    {
        return getTypedDataHash(getStructHash(owner, spender, value, nonce, deadline));
    }
}

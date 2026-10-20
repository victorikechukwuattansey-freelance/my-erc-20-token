// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SigUtils} from "./utils/SigUtils.sol"; // you'll create this helper

contract MyTokenTest is Test {
    MyToken token;
    address deployer;
    address user1;
    address user2;
    uint256 initialSupply = 1000 ether; // 1000 * 10^18
    uint256 cap = 2000 ether;

    function setUp() public {
        deployer = address(this); // The test contract itself deploys
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        token = new MyToken(initialSupply, cap);
    }

    // 1. Initial State
    function test_InitialSupply() public view {
        assertEq(token.totalSupply(), initialSupply);
        assertEq(token.balanceOf(deployer), initialSupply);
    }

    // 2. Successful Transfer
    function test_Transfer() public {
        token.transfer(user1, 100 ether);
        assertEq(token.balanceOf(user1), 100 ether);
        assertEq(token.balanceOf(deployer), initialSupply - 100 ether);
    }

    // 3. Transfer to Zero Address Fails
    function test_RevertWhen_TransferToZeroAddress() public {
        vm.expectRevert();
        token.transfer(address(0), 1 ether);
    }

    // 4. Insufficient Balance Fails
    function test_RevertWhen_InsufficientBalance() public {
        vm.prank(user1); // Impersonate user1 who has 0 tokens
        vm.expectRevert();
        token.transfer(user2, 1 ether);
    }

    // 5. Approve and Allowance
    function test_Approve() public {
        token.approve(user1, 50 ether);
        assertEq(token.allowance(deployer, user1), 50 ether);
    }

    // 6. Successful transferFrom
    function test_TransferFrom() public {
        token.approve(user1, 50 ether);
        vm.prank(user1); // user1 acts as the spender
        token.transferFrom(deployer, user2, 20 ether);

        assertEq(token.balanceOf(user2), 20 ether);
        assertEq(token.allowance(deployer, user1), 30 ether); // Allowance reduced
        assertEq(token.balanceOf(deployer), initialSupply - 20 ether);
    }

    // 7. transferFrom Fails with Insufficient Allowance
    function test_RevertWhen_InsufficientAllowance() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transferFrom(deployer, user2, 1 ether); // No allowance was set
    }

    // 8.  Happy path: minting up to the cap works
    function test_MintUpToCap() public {
        token.mint(user1, 500 ether); // 1000 + 500 = 1500 < 2000
        assertEq(token.balanceOf(user1), 500 ether);
        assertEq(token.totalSupply(), initialSupply + 500 ether);
    }

    // 9. Cap invariant: minting past the cap reverts
    function test_RevertWhen_MintExceedsCap() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20Capped.ERC20ExceededCap.selector,
                initialSupply + 1500 ether, // attempted total
                cap // cap
            )
        );
        token.mint(user1, 1500 ether);
    }

    // Only the owner should be able to mint.
    function test_RevertWhen_NonOwnerMints() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        token.mint(user1, 1 ether);
    }

    // Happy path: burning reduces both the caller's balance and total supply
    function test_BurnReducesSupplyAndBalance() public {
        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(deployer);

        token.burn(100 ether);

        assertEq(token.totalSupply(), supplyBefore - 100 ether);
        assertEq(token.balanceOf(deployer), balanceBefore - 100 ether);
    }

    // Invariant: you can't burn tokens you don't have
    function test_RevertWhen_BurnExceedsBalance() public {
        vm.prank(user1); // user1 has 0 MTK
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                user1,
                0, // balance
                1 ether // needed
            )
        );
        token.burn(1 ether);
    }

    // When paused, transfers revert
    function test_RevertWhen_TransferWhilePaused() public {
        token.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        token.transfer(user1, 1 ether);
    }

    // Unpausing restores transfers
    function test_TransferAfterUnpause() public {
        token.pause();
        token.unpause();
        token.transfer(user1, 1 ether);
        assertEq(token.balanceOf(user1), 1 ether);
    }

    // Only the owner can pause
    function test_RevertWhen_NonOwnerPauses() public {
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
        token.pause();
    }

    // 1. Happy path: a valid signature sets the allowance
    function test_PermitSetsAllowance() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(owner);

        SigUtils sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        bytes32 digest = sigUtils.getDigest(owner, user1, value, nonce, deadline);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        token.permit(owner, user1, value, deadline, v, r, s);

        assertEq(token.allowance(owner, user1), value);
        assertEq(token.nonces(owner), nonce + 1);
    }

    // 2. Replay: the same signature must fail the second time (nonce changed)
    function test_RevertWhen_PermitReplayed() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(owner);

        SigUtils sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        bytes32 digest = sigUtils.getDigest(owner, user1, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        token.permit(owner, user1, value, deadline, v, r, s);

        vm.expectRevert(); // nonce mismatch: ERC20InvalidNonce
        token.permit(owner, user1, value, deadline, v, r, s);
    }

    // 3. Deadline: an expired signature must fail
    function test_RevertWhen_PermitExpired() public {
        uint256 privateKey = 0xA11CE;
        address owner = vm.addr(privateKey);
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp - 1; // already expired
        uint256 nonce = token.nonces(owner);

        SigUtils sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        bytes32 digest = sigUtils.getDigest(owner, user1, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert(); // ERC2612ExpiredSignature
        token.permit(owner, user1, value, deadline, v, r, s);
    }

    // 4. Wrong signer: a signature from someone else must fail
    function test_RevertWhen_PermitWrongSigner() public {
        uint256 attackerKey = 0xBAD;
        uint256 victimKey = 0xA11CE;
        address victim = vm.addr(victimKey);
        uint256 value = 100 ether;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(victim);

        SigUtils sigUtils = new SigUtils(token.DOMAIN_SEPARATOR());
        // Attacker signs a permit for the victim's tokens
        bytes32 digest = sigUtils.getDigest(victim, user1, value, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attackerKey, digest);

        vm.expectRevert(); // ERC20InvalidSignature
        token.permit(victim, user1, value, deadline, v, r, s);
    }
}

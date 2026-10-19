// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import {ERC20Capped} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

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
}

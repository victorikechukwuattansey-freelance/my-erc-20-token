// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MyToken} from "../src/MyToken.sol";

contract DeployMyToken is Script {
    function run() external returns (MyToken token) {
        uint256 initialSupply = 1000 ether;
        uint256 cap = 2000 ether;

        vm.startBroadcast();
        token = new MyToken(initialSupply, cap);
        vm.stopBroadcast();

        console.log("MyToken deployed at:", address(token));
        console.log("Total supply (wei): ", token.totalSupply());
        console.log("Cap (wei):          ", token.cap());
    }
}

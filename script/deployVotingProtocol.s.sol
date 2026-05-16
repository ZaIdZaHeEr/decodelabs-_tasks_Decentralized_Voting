// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VotingProtocol} from "../src/votingProtocol.sol";
import {Script} from "lib/forge-std/src/Script.sol";

contract DeployVotingProtocol is Script {
    function run() external {
        vm.startBroadcast();
        new VotingProtocol();
        vm.stopBroadcast();
    }
}

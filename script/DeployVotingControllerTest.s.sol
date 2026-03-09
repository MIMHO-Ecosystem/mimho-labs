// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/votingcontroller.sol";

contract DeployVotingControllerTest is Script {
    function run() external {
        vm.startBroadcast();
        MIMHOInjectLiquidityVotingController vc =
            new MIMHOInjectLiquidityVotingController(
                0xd6cc966b41476cF4884396d4d7b996A4168327d5
            );
        vm.stopBroadcast();

        console2.log("VOTING_CONTROLLER_TEST:", address(vc));
    }
}

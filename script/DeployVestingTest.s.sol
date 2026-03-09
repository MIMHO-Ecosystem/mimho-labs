// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/vesting.sol";

contract DeployVestingTest is Script {
    function run() external {
        address token = 0x546BEFB543F1438828B293f9AC8a22298A76f31F;
        address registry = 0xd6cc966b41476cF4884396d4d7b996A4168327d5;

        vm.startBroadcast();
        MIMHOVesting vesting = new MIMHOVesting(token, registry);
        vm.stopBroadcast();

        console2.log("VESTING_TEST:", address(vesting));
    }
}

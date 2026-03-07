// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/presale_test.sol";

contract DeployPresaleTest is Script {
    function run() external {
        address registry = 0xd6cc966b41476cF4884396d4d7b996A4168327d5;

        vm.startBroadcast();
        MIMHOPresaleTest presale = new MIMHOPresaleTest(registry);
        vm.stopBroadcast();

        console2.log("PRESALE_TEST:", address(presale));
    }
}

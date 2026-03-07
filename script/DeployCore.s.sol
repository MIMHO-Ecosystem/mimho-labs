// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import * as REG from "../src/registry.sol";
import * as HUB from "../src/eventshub.sol";
import * as TOK from "../src/token.sol";

contract DeployCore is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
address deployer = vm.addr(pk);

vm.startBroadcast(pk);

        REG.MIMHORegistry registry = new REG.MIMHORegistry(deployer);
        console2.log("Registry:", address(registry));

        HUB.MIMHOEventsHub hub = new HUB.MIMHOEventsHub(deployer, address(registry));
        console2.log("EventsHub:", address(hub));

        registry.setEventsHub(address(hub));

        TOK.MIMHO token = new TOK.MIMHO();
        console2.log("Token:", address(token));

        token.setRegistry(address(registry));
        registry.setMIMHOToken(address(token));

        vm.stopBroadcast();
    }
}

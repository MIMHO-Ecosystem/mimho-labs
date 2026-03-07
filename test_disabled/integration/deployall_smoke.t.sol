// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import "../../src/registry.sol";
import "../../src/eventshub.sol";
import "../../src/token.sol";

contract DeployAllSmokeTest is Test {
    function test_smoke_registry_hub_token() external {
        address deployer = address(this);

        MIMHORegistry registry = new MIMHORegistry(deployer);
        MIMHOEventsHub hub = new MIMHOEventsHub(deployer, address(registry));
        registry.setEventsHub(address(hub));

        MIMHO token = new MIMHO();
        token.setRegistry(address(registry));
        registry.setMIMHOToken(address(token));

        // checks
        assertEq(token.getRegistry(), address(registry));
        // se no Registry tiver getter do events hub:
        // assertEq(registry.eventsHub(), address(hub));

        // hub status não deve reverter
        hub.hubStatus();
    }
}

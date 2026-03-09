// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/liquiditybootstrapper_short_test.sol";

contract DeployBootstrapperFinalTest is Script {
    function run() external {
        address registry = 0xd6cc966b41476cF4884396d4d7b996A4168327d5;
        address mimhoToken = 0x546BEFB543F1438828B293f9AC8a22298A76f31F;
        address router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        address presale = vm.envAddress("PRESALE_TEST");
        address burn = 0x000000000000000000000000000000000000dEaD;
        uint256 presalePrice = 1500000000;

        vm.startBroadcast();
        MIMHOLiquidityBootstrapperShortTest boot = new MIMHOLiquidityBootstrapperShortTest(
            registry,
            mimhoToken,
            router,
            presale,
            burn,
            presalePrice
        );
        vm.stopBroadcast();

        console2.log("BOOTSTRAPPER_FINAL_TEST:", address(boot));
    }
}

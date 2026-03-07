// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/liquiditybootstrapper.sol";

contract DeployBootstrapperTest is Script {
    function run() external {
        address registry = 0xd6cc966b41476cF4884396d4d7b996A4168327d5;
        address mimhoToken = 0x546BEFB543F1438828B293f9AC8a22298A76f31F;
        address router = 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        address presale = 0xAc6123dBA63f32cB0243C758B68B40b7138b0D37;
        address lpBurn = 0x000000000000000000000000000000000000dEaD;
        uint256 presalePrice = 1500000000;

        vm.startBroadcast();
        MIMHOLiquidityBootstrapper lb = new MIMHOLiquidityBootstrapper(
            registry,
            mimhoToken,
            router,
            presale,
            lpBurn,
            presalePrice
        );
        vm.stopBroadcast();

        console2.log("BOOTSTRAPPER_TEST:", address(lb));
    }
}

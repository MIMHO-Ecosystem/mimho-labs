// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/registry.sol";

contract DeployRegistry is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        // No Anvil/Testnet: use deployer como "founderSafeOwner"
        // (em mainnet você usaria o Safe como owner)
        MIMHORegistry registry = new MIMHORegistry(deployer);

        vm.stopBroadcast();

        console2.log("MIMHORegistry:", address(registry));
    }
}

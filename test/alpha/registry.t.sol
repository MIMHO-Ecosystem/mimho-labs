// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHORegistry} from "src/registry.sol";

contract RegistryAlphaTest is Test {

    MIMHORegistry registry;

    address founder = address(0xF0);
    address dao = address(0xD0);
    address someContract = address(0x1234);

    function setUp() public {
        registry = new MIMHORegistry(founder);
    }

    function test_SetToken_UsesOfficialKey() public {
    vm.prank(founder);
    registry.setMIMHOToken(someContract);

    // Confere storage direto
    assertEq(registry.mimhoToken(), someContract);

    // Confere resolver via KEY
    bytes32 key = registry.KEY_MIMHO_TOKEN();
    assertEq(registry.getContract(key), someContract);
}

    function test_ActivateDAO() public {
        vm.startPrank(founder);
        registry.setDAO(dao);
        registry.activateDAO();
        vm.stopPrank();

        assertTrue(registry.daoActivated());
    }

    function test_Pause_Unpause() public {
        vm.prank(founder);
        registry.pauseEmergencial();

        assertTrue(registry.paused());

        vm.prank(founder);
        registry.unpause();

        assertFalse(registry.paused());
    }

    function test_Revert_NonOwner_SetDAO() public {
        vm.expectRevert();
        registry.setDAO(dao);
    }

}

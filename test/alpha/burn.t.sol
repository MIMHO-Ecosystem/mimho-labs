// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/burn.sol";

/* ------------------------------------------------------------
   Minimal Mock Registry
   - Returns 0 for Events Hub, so Burn's _emitHubEvent() becomes a no-op.
   - Only the functions Burn calls are implemented.
------------------------------------------------------------ */
contract MockRegistryBurn {
    bytes32 internal constant K_EVENTS = keccak256("MIMHO_EVENTS_HUB");

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) {
        return K_EVENTS;
    }

    function getContract(bytes32) external pure returns (address) {
        return address(0);
    }
}

contract BurnAlphaTest is Test {
    MIMHOBurnGovernanceVault internal burn;
    MockRegistryBurn internal reg;

    address internal dao = address(0xB0b);

    function setUp() public {
        reg = new MockRegistryBurn();

        // ✅ correct: pass a CONTRACT address as registry
        burn = new MIMHOBurnGovernanceVault(address(reg));

        burn.setDAO(dao);
        burn.activateDAO();
    }

    function test_Deploy_Works() public {
        assertTrue(address(burn) != address(0));
    }

    function test_PauseBlocks_WhenPaused() public {
        burn.pauseEmergencial();

        // Calling pause again should revert because it's already paused
        vm.expectRevert(bytes("Pausable: paused"));
        burn.pauseEmergencial();

        // Unpause and pause again should work
        burn.unpause();
        burn.pauseEmergencial();
    }
}

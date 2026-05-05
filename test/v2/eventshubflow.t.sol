// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/v2/eventshub.sol";

contract MockEventsRegistry {
    mapping(address => bool) public ecosystem;

    function setEcosystem(address a, bool status) external {
        ecosystem[a] = status;
    }

    function isEcosystemContract(address a) external view returns (bool) {
        return ecosystem[a];
    }

    function callEmitEvent(
        MIMHOEventsHub hub,
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external {
        hub.emitEvent(module, action, caller, value, data);
    }
}

contract MockEmitter {
    MIMHOEventsHub public hub;

    constructor(MIMHOEventsHub hub_) {
        hub = hub_;
    }

    function emitToHub(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external {
        hub.emitEvent(module, action, caller, value, data);
    }
}

contract EventsHubFlowTest is Test {
    MIMHOEventsHub hub;
    MockEventsRegistry registry;
    MockEmitter emitter;

    address owner = address(this);
    address dao = address(0xDA0);
    address alice = address(0xA11CE);

    bytes32 moduleId = keccak256("TEST_MODULE");
    bytes32 actionId = keccak256("TEST_ACTION");

    event HubEvent(
        uint256 indexed timestamp,
        uint256 indexed chainId,
        bytes32 indexed module,
        bytes32 action,
        address origin,
        address caller,
        uint256 value,
        bytes data
    );

    event PayloadTruncated(
        uint256 indexed timestamp,
        uint256 indexed chainId,
        bytes32 indexed module,
        bytes32 action,
        address origin,
        address caller,
        uint256 value,
        uint256 originalLength,
        uint256 keptLength
    );

    function setUp() public {
        registry = new MockEventsRegistry();
        hub = new MIMHOEventsHub(owner, address(registry));
        emitter = new MockEmitter(hub);

        registry.setEcosystem(address(emitter), true);
    }

    // =====================================================
    // CONSTRUCTOR / METADATA
    // =====================================================

    function test_Constructor() public {
        assertEq(hub.owner(), owner);
        assertEq(address(hub.registry()), address(registry));
        assertFalse(hub.daoActivated());
        assertFalse(hub.paused());
        assertEq(hub.deployedAt(), block.timestamp);
    }

    function test_Revert_ConstructorZeroOwner() public {
        vm.expectRevert(bytes("MIMHO: zero owner"));
        new MIMHOEventsHub(address(0), address(registry));
    }

    function test_Revert_ConstructorZeroRegistry() public {
        vm.expectRevert(bytes("MIMHO: zero registry"));
        new MIMHOEventsHub(owner, address(0));
    }

    function test_Metadata() public {
        assertEq(hub.contractName(), "MIMHO Events Hub");
        assertEq(hub.contractType(), hub.CONTRACT_TYPE());
        assertEq(hub.version(), "1.0.0");
        assertTrue(hub.isObservable());
        assertEq(hub.getActionType(), hub.ACTION_TYPE());
        assertEq(hub.getRiskLevel(), 1);
        assertFalse(hub.isFinalized());
    }

    function test_ProtocolNeutralViews() public {
        (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue) = hub.getFinancialImpact(alice);

        assertEq(volumeIn, 0);
        assertEq(volumeOut, 0);
        assertEq(lockedValue, 0);
        assertEq(hub.getBoostValue(alice), 0);

        hub.onExternalAction(alice, keccak256("TEST"));
    }

    // =====================================================
    // EMISSION
    // =====================================================

    function test_EcosystemEmitterCanEmit() public {
        bytes memory data = abi.encode("hello");

        vm.expectEmit(true, true, true, true, address(hub));
        emit HubEvent(
            block.timestamp,
            block.chainid,
            moduleId,
            actionId,
            address(emitter),
            alice,
            123,
            data
        );

        emitter.emitToHub(moduleId, actionId, alice, 123, data);
    }

    function test_RegistryItselfCanEmit() public {
        bytes memory data = abi.encode("registry");

        vm.expectEmit(true, true, true, true, address(hub));
        emit HubEvent(
            block.timestamp,
            block.chainid,
            moduleId,
            actionId,
            address(registry),
            alice,
            456,
            data
        );

        registry.callEmitEvent(hub, moduleId, actionId, alice, 456, data);
    }

    function test_Revert_EOACannotEmit() public {
        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: EOA blocked"));
        hub.emitEvent(moduleId, actionId, alice, 1, "");
    }

    function test_Revert_NonEcosystemContractCannotEmit() public {
        MockEmitter outsider = new MockEmitter(hub);

        vm.expectRevert(bytes("MIMHO: NOT_ECOSYSTEM"));
        outsider.emitToHub(moduleId, actionId, alice, 1, "");
    }

    function test_Revert_EmitterBlacklisted() public {
        hub.blacklistEmitter(address(emitter), true);

        vm.expectRevert(bytes("MIMHO: emitter blacklisted"));
        emitter.emitToHub(moduleId, actionId, alice, 1, "");
    }

    function test_Revert_InvalidModule() public {
        vm.expectRevert(bytes("MIMHO: invalid module"));
        emitter.emitToHub(bytes32(0), actionId, alice, 1, "");
    }

    function test_Revert_InvalidAction() public {
        vm.expectRevert(bytes("MIMHO: invalid action"));
        emitter.emitToHub(moduleId, bytes32(0), alice, 1, "");
    }

    function test_Revert_InvalidCaller() public {
        vm.expectRevert(bytes("MIMHO: invalid caller"));
        emitter.emitToHub(moduleId, actionId, address(0), 1, "");
    }

    function test_PayloadIsTruncatedWhenTooLarge() public {
        bytes memory bigData = new bytes(1200);

        vm.expectEmit(true, true, true, true, address(hub));
        emit PayloadTruncated(
            block.timestamp,
            block.chainid,
            moduleId,
            actionId,
            address(emitter),
            alice,
            777,
            1200,
            hub.MAX_EVENT_DATA_BYTES()
        );

        emitter.emitToHub(moduleId, actionId, alice, 777, bigData);
    }

    // =====================================================
    // CAN EMIT
    // =====================================================

    function test_CanEmit() public {
        assertTrue(hub.canEmit(address(emitter)));
        assertTrue(hub.canEmit(address(registry)));
        assertFalse(hub.canEmit(alice));
    }

    function test_CanEmitFalseWhenBlacklisted() public {
        hub.blacklistEmitter(address(emitter), true);

        assertFalse(hub.canEmit(address(emitter)));
    }

    function test_CanEmitFalseWhenPaused() public {
        hub.pauseEmergencial();

        assertFalse(hub.canEmit(address(emitter)));
    }

    // =====================================================
    // GOVERNANCE
    // =====================================================

    function test_SetDAOAndActivateDAO() public {
        hub.setDAO(dao);
        assertEq(hub.dao(), dao);
        assertFalse(hub.daoActivated());

        hub.activateDAO();
        assertTrue(hub.daoActivated());
    }

    function test_Revert_SetDAOZero() public {
        vm.expectRevert(bytes("MIMHO: zero dao"));
        hub.setDAO(address(0));
    }

    function test_Revert_SetDAOTwice() public {
        hub.setDAO(dao);

        vm.expectRevert(bytes("MIMHO: dao already set"));
        hub.setDAO(address(0xBEEF));
    }

    function test_Revert_ActivateDAOWithoutDAO() public {
        vm.expectRevert(bytes("MIMHO: dao not set"));
        hub.activateDAO();
    }

    function test_Revert_ActivateDAOTwice() public {
        hub.setDAO(dao);
        hub.activateDAO();

        vm.expectRevert(bytes("MIMHO: dao already active"));
        vm.prank(dao);
        hub.activateDAO();
    }

    function test_DAOCannotOperateBeforeActivation() public {
        hub.setDAO(dao);

        vm.prank(dao);
        vm.expectRevert(bytes("MIMHO: owner only"));
        hub.pauseEmergencial();
    }

    function test_DAOCanOperateAfterActivation() public {
        hub.setDAO(dao);
        hub.activateDAO();

        vm.prank(dao);
        hub.pauseEmergencial();

        assertTrue(hub.paused());
    }

    function test_OwnerCannotOperateAfterDAOActivation() public {
        hub.setDAO(dao);
        hub.activateDAO();

        vm.expectRevert(bytes("MIMHO: DAO only"));
        hub.pauseEmergencial();
    }

    function test_PauseBlocksEmit() public {
        hub.pauseEmergencial();

        vm.expectRevert(bytes("MIMHO: paused"));
        emitter.emitToHub(moduleId, actionId, alice, 1, "");
    }

    function test_UnpauseRestoresEmit() public {
        hub.pauseEmergencial();
        hub.unpause();

        emitter.emitToHub(moduleId, actionId, alice, 1, "");
    }

    function test_UpdateRegistry() public {
        MockEventsRegistry newRegistry = new MockEventsRegistry();
        newRegistry.setEcosystem(address(emitter), true);

        hub.updateRegistry(address(newRegistry));

        assertEq(address(hub.registry()), address(newRegistry));
        assertTrue(hub.canEmit(address(emitter)));
    }

    function test_Revert_UpdateRegistryZero() public {
        vm.expectRevert(bytes("MIMHO: zero registry"));
        hub.updateRegistry(address(0));
    }

    function test_Revert_BlacklistZeroEmitter() public {
        vm.expectRevert(bytes("MIMHO: zero emitter"));
        hub.blacklistEmitter(address(0), true);
    }

    function test_HubStatus() public view {
        // Smoke test: hubStatus must be callable without reverting.
        // Direct getters below validate the critical state without depending
        // on the exact tuple order/types returned by hubStatus().
        hub.hubStatus();

        assertEq(hub.owner(), owner);
        assertEq(hub.dao(), address(0));
        assertFalse(hub.daoActivated());
        assertEq(address(hub.registry()), address(registry));
        assertFalse(hub.paused());
        assertEq(hub.MAX_EVENT_DATA_BYTES(), 1024);
    }
}

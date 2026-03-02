// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import { MIMHOEventsHub } from "../../src/eventshub.sol";

contract MockRegistry {
    mapping(address => bool) public eco;

    function setEco(address a, bool v) external { eco[a] = v; }

    function isEcosystemContract(address a) external view returns (bool) {
        return eco[a];
    }
}

contract MockEmitter {
    function emitToHub(
        address hub,
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external {
        MIMHOEventsHub(hub).emitEvent(module, action, caller, value, data);
    }
}

contract EventsHubAlphaTest is Test {
    MIMHOEventsHub internal hub;
    MockRegistry internal reg;

    address internal OWNER = address(0xBEEF);
    address internal DAO   = address(0xD00D);

    MockEmitter internal emitter;

    function setUp() public {
        reg = new MockRegistry();
        hub = new MIMHOEventsHub(OWNER, address(reg));
        emitter = new MockEmitter();
    }

    function test_Deploy_Works() public {
        (address ownerAddress,,,,,,, string memory ver) = hub.hubStatus();
        assertEq(ownerAddress, OWNER);
        assertEq(keccak256(bytes(ver)), keccak256(bytes("1.0.0")));
    }

    function test_EOA_Block() public {
    vm.prank(OWNER);
    hub.setDAO(DAO);
    vm.prank(OWNER);
    hub.activateDAO();

    // Agora sim: uma EOA chamando direto o hub
    address eoa = address(0xEA01);

    vm.prank(eoa);
    vm.expectRevert(bytes("MIMHO: EOA blocked"));
    hub.emitEvent(keccak256("X"), keccak256("Y"), address(0x123), 1, bytes("hi"));
}

    function test_OnlyEcosystemEmitter_AllowsWhitelistedContract() public {
        // whitelist emitter no registry mock
        reg.setEco(address(emitter), true);

        bytes32 module = keccak256("M");
        bytes32 action = keccak256("A");
        address caller = address(0xCA11);
        uint256 value = 123;

        vm.expectEmit(true, true, true, true);
        emit MIMHOEventsHub.HubEvent(
            block.timestamp,
            block.chainid,
            module,
            action,
            address(emitter),
            caller,
            value,
            bytes("ok")
        );

        emitter.emitToHub(address(hub), module, action, caller, value, bytes("ok"));
    }

    function test_Payload_Truncates_OverLimit() public {
        reg.setEco(address(emitter), true);

        bytes memory big = new bytes(2000);
        for (uint256 i = 0; i < big.length; i++) big[i] = bytes1(uint8(i));

        bytes32 module = keccak256("M");
        bytes32 action = keccak256("A");
        address caller = address(0xCA11);

        vm.expectEmit(true, true, true, true);
        emit MIMHOEventsHub.PayloadTruncated(
            block.timestamp,
            block.chainid,
            module,
            action,
            address(emitter),
            caller,
            0,
            2000,
            1024
        );

        emitter.emitToHub(address(hub), module, action, caller, 0, big);
    }

    function test_Pause_Blocks() public {
        // pause precisa ser chamado pelo OWNER antes da ativação DAO
        vm.prank(OWNER);
        hub.pauseEmergencial();

        reg.setEco(address(emitter), true);

        vm.expectRevert(bytes("MIMHO: paused"));
        emitter.emitToHub(address(hub), keccak256("M"), keccak256("A"), address(0xCA11), 0, bytes("x"));
    }

    function test_CanEmit_View() public {
        assertEq(hub.canEmit(address(emitter)), false);
        reg.setEco(address(emitter), true);
        assertEq(hub.canEmit(address(emitter)), true);

        vm.prank(OWNER);
        hub.pauseEmergencial();
        assertEq(hub.canEmit(address(emitter)), false);
    }
}

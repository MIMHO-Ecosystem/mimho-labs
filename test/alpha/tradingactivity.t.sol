// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/tradingactivity.sol";

/* ============================================================
   MOCKS
   ============================================================ */

contract MockEventsHub is IMIMHOEventsHub {
    event HubEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes data);

    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external {
        emit HubEvent(module, action, caller, value, data);
    }
}

contract MockRegistry is IMIMHORegistry {
    mapping(bytes32 => address) public addrs;
    mapping(address => bool) public eco;

    bytes32 private constant _KEY_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 private constant _KEY_DAO = keccak256("MIMHO_DAO");

    function set(bytes32 key, address a) external { addrs[key] = a; }
    function setEco(address a, bool ok) external { eco[a] = ok; }

    function getContract(bytes32 key) external view returns (address) { return addrs[key]; }
    function isEcosystemContract(address a) external view returns (bool) { return eco[a]; }

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32) { return _KEY_HUB; }
    function KEY_MIMHO_DAO() external view returns (bytes32) { return _KEY_DAO; }
}

/* ============================================================
   TESTS
   ============================================================ */

contract MIMHOTradingActivityAlphaTest is Test {
    MockRegistry registry;
    MockEventsHub hub;
    MIMHOTradingActivity ta;

    address owner = address(0xA11CE);
    address dao   = address(0xDA0);
    address ecoReporter = address(0xE1);
    address user = address(0xB0B);

    function _cfg() internal pure returns (MIMHOTradingActivity.CycleConfig memory c) {
        c = MIMHOTradingActivity.CycleConfig({
            minTradeValueBNB: 5e16,        // 0.05 BNB
            minIntervalSec: 180,           // 3 min
            circularWindowSec: 120,        // 2 min
            circularBpsTolerance: 1000,    // 10%
            maxSnapshotBatch: 100
        });
    }

    function setUp() public {
        vm.startPrank(owner);

        registry = new MockRegistry();
        hub = new MockEventsHub();

        registry.set(keccak256("MIMHO_EVENTS_HUB"), address(hub));
        registry.set(keccak256("MIMHO_DAO"), dao);
        registry.setEco(ecoReporter, true);

        ta = new MIMHOTradingActivity(address(registry));

        vm.stopPrank();
    }

    function test_AnnounceCycle_SetsDeterministicTimeline() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());

        MIMHOTradingActivity.CycleMeta memory cur = ta.getCurrent();
        assertEq(cur.cycleId, 1);
        assertEq(cur.startsAt, cur.announcedAt + ta.ANNOUNCE_DELAY());
        assertEq(cur.endsAt, cur.startsAt + ta.ACTIVE_DURATION());

        assertEq(uint256(ta.state()), uint256(MIMHOTradingActivity.CycleState.ANNOUNCED));
    }

    function test_EmitStarted_OnlyOnce_WhenActive() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());

        // jump to ACTIVE
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());
        assertEq(uint256(ta.state()), uint256(MIMHOTradingActivity.CycleState.ACTIVE));

        vm.prank(user);
        ta.emitStarted();

        // second call should revert (guard using snapshot counters)
        vm.prank(user);
        vm.expectRevert(bytes("ALREADY_SIGNALED"));
        ta.emitStarted();
    }

    function test_ReportTrade_OnlyActive_AndOnlyReporter() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());

        // not active yet
        vm.prank(ecoReporter);
        vm.expectRevert(bytes("NOT_ACTIVE"));
        ta.reportTrade(user, 1e17, true);

        // jump to ACTIVE
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());

        // non reporter should fail
        vm.prank(address(0x999));
        vm.expectRevert(bytes("NOT_ECOSYSTEM_REPORTER"));
        ta.reportTrade(user, 1e17, true);

        // ecosystem reporter ok
        vm.prank(ecoReporter);
        ta.reportTrade(user, 1e17, true);

        (uint256 s, uint256 v, uint256 t,,) = ta.getParticipant(1, user);
        assertEq(t, 1);
        assertEq(v, 1e17);
        assertEq(s, 1e17);
    }

    function test_AntiAbuse_SameBlockSpamIgnored() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());

        vm.startPrank(ecoReporter);
        ta.reportTrade(user, 1e17, true);

        // same block second report => ignored
        ta.reportTrade(user, 1e17, true);
        vm.stopPrank();

        (uint256 s, uint256 v, uint256 t,,) = ta.getParticipant(1, user);
        assertEq(t, 1);
        assertEq(v, 1e17);
        assertEq(s, 1e17);
    }

    function test_AntiAbuse_MinIntervalBetweenCountedTrades() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());

        vm.prank(ecoReporter);
        ta.reportTrade(user, 1e17, true);

        // move to next block but not enough time
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 60);

        vm.prank(ecoReporter);
        ta.reportTrade(user, 1e17, true);

        // still 1 counted
        (uint256 s, uint256 v, uint256 t,,) = ta.getParticipant(1, user);
        assertEq(t, 1);
        assertEq(v, 1e17);
        assertEq(s, 1e17);

        // now pass interval
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 180);

        vm.prank(ecoReporter);
        ta.reportTrade(user, 1e17, true);

        (s, v, t,,) = ta.getParticipant(1, user);
        assertEq(t, 2);
        assertEq(v, 2e17);
        assertEq(s, 2e17);
    }

    function test_AntiAbuse_CircularToggleIgnoredWithinWindow() public {
    MIMHOTradingActivity.CycleConfig memory c = _cfg();
    c.minIntervalSec = 0; // allow quick second counted trade inside circular window

    vm.prank(owner);
    ta.announceCycle(c);
    vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());

    // First counted buy
    vm.prank(ecoReporter);
    ta.reportTrade(user, 1e17, true);

    // next block, within circularWindow
    vm.roll(block.number + 1);
    vm.warp(block.timestamp + 60);

    // Toggle side with similar size (within tolerance) => should be ignored
    vm.prank(ecoReporter);
    ta.reportTrade(user, 95e15, false); // 0.095 BNB, diff=5% <= 10% tolerance

    (uint256 s, uint256 v, uint256 t,,) = ta.getParticipant(1, user);
    assertEq(t, 1);
    assertEq(v, 1e17);
    assertEq(s, 1e17);
}

    function test_Snapshot_RateLimitDuringActive() public {
        // announce with minInterval=0 to simplify other tests
        MIMHOTradingActivity.CycleConfig memory c = _cfg();
        c.minIntervalSec = 0;

        vm.prank(owner);
        ta.announceCycle(c);
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());

        // Need at least 1 participant in list
        address[] memory ps = new address[](1);
        ps[0] = user;

        vm.prank(user);
        ta.emitSnapshot(ps);

        // too soon
        vm.prank(user);
        vm.expectRevert(bytes("SNAPSHOT_TOO_SOON"));
        ta.emitSnapshot(ps);

        // after interval ok
        vm.warp(block.timestamp + ta.MIN_SNAPSHOT_INTERVAL());
        vm.prank(user);
        ta.emitSnapshot(ps);
    }

    function test_Finalize_OnlyAfterEnded() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());

        // before end
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY() + 1);
        vm.prank(user);
        vm.expectRevert(bytes("NOT_ENDED"));
        ta.finalize();

        // after end
        vm.warp(block.timestamp + ta.ACTIVE_DURATION());
        assertEq(uint256(ta.state()), uint256(MIMHOTradingActivity.CycleState.ENDED));

        vm.prank(user);
        ta.finalize();

        assertEq(uint256(ta.state()), uint256(MIMHOTradingActivity.CycleState.FINALIZED));
    }

    function test_PauseBlockedDuringActive() public {
        vm.prank(owner);
        ta.announceCycle(_cfg());
        vm.warp(block.timestamp + ta.ANNOUNCE_DELAY());

        vm.prank(owner);
        vm.expectRevert(bytes("CANNOT_PAUSE_ACTIVE"));
        ta.pauseEmergencial();
    }

    function test_ActivateDAO_ReadsRegistryDAO() public {
        // activateDAO reads DAO from registry.KEY_MIMHO_DAO()
        vm.prank(owner);
        ta.activateDAO();

        assertTrue(ta.daoActivated());
        assertEq(ta.DAO_CONTRACT(), dao);
    }
}

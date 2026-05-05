// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/v2/vesting.sol";

contract MockVestingToken {
    mapping(address => uint256) public balanceOf;

    bool public failTransfer;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function setFailTransfer(bool status) external {
        failTransfer = status;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (failTransfer) return false;
        require(balanceOf[msg.sender] >= amount, "MOCK_BALANCE_LOW");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract MockVestingRegistry {
    bytes32 public constant KEY_MIMHO_EVENTS_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant KEY_MIMHO_DAO = keccak256("MIMHO_DAO");

    mapping(bytes32 => address) public contractsByKey;

    function set(bytes32 key, address value) external {
        contractsByKey[key] = value;
    }

    function getContract(bytes32 key) external view returns (address) {
        return contractsByKey[key];
    }
}

contract MockVestingEventsHub {
    uint256 public calls;

    bytes32 public lastModule;
    bytes32 public lastAction;
    address public lastCaller;
    uint256 public lastValue;
    bytes public lastData;

    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external {
        calls++;
        lastModule = module;
        lastAction = action;
        lastCaller = caller;
        lastValue = value;
        lastData = data;
    }
}

contract MockBrokenVestingEventsHub {
    function emitEvent(
        bytes32,
        bytes32,
        address,
        uint256,
        bytes calldata
    ) external pure {
        revert("BROKEN_HUB");
    }
}

contract VestingFlowTest is Test {
    MockVestingToken token;
    MockVestingRegistry registry;
    MockVestingEventsHub hub;
    MIMHOVesting vesting;

    address owner = address(this);
    address dao = address(0xDA0);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address ecosystemReceiver = address(0xEC0);
    address foreignTokenReceiver = address(0xF012);

    uint256 constant ONE_THOUSAND = 1_000 ether;

    function setUp() public {
        token = new MockVestingToken();
        registry = new MockVestingRegistry();
        hub = new MockVestingEventsHub();

        registry.set(registry.KEY_MIMHO_DAO(), dao);
        registry.set(registry.KEY_MIMHO_EVENTS_HUB(), address(hub));

        vesting = new MIMHOVesting(address(token), address(registry));

        token.mint(address(vesting), 1_000_000_000_000 ether);
    }

    // =====================================================
    // CONSTRUCTOR / STATUS
    // =====================================================

    function test_ConstructorSetsTokenRegistryAndFounderSchedule() public {
        assertEq(address(vesting.MIMHO()), address(token));
        assertEq(address(vesting.registry()), address(registry));
        assertEq(vesting.owner(), owner);
        assertFalse(vesting.paused());
        assertFalse(vesting.finalized());

        (
            string memory v,
            bool isPaused,
            bool isFinalized,
            address tokenAddr,
            address regAddr,
            address daoAddr,
            bool daoActive,
            address ecoReceiver
        ) = vesting.contractStatus();

        assertEq(v, "1.0.0");
        assertFalse(isPaused);
        assertFalse(isFinalized);
        assertEq(tokenAddr, address(token));
        assertEq(regAddr, address(registry));
        assertEq(daoAddr, address(0));
        assertFalse(daoActive);
        assertEq(ecoReceiver, address(0));

        (
            uint64 cliffEnd,
            uint64 monthlyStart,
            uint256 totalAllocated,
            uint256 totalClaimed,
            bool initialized
        ) = vesting.founder();

        assertEq(cliffEnd, uint64(block.timestamp + uint256(vesting.THREE_MONTHS())));
        assertEq(monthlyStart, cliffEnd);
        assertEq(totalAllocated, 0);
        assertEq(totalClaimed, 0);
        assertFalse(initialized);

        assertEq(vesting.founderNextClaimTime(), 0);
    }

    function test_Revert_ConstructorZeroToken() public {
        vm.expectRevert(bytes("ZERO_ADDR"));
        new MIMHOVesting(address(0), address(registry));
    }

    function test_Revert_ConstructorZeroRegistry() public {
        vm.expectRevert(bytes("ZERO_ADDR"));
        new MIMHOVesting(address(token), address(0));
    }

    function test_BalancesView() public {
        (uint256 mimhoBalance, uint256 founderClaimable, uint256 ecosystemClaimable) = vesting.balances();

        assertEq(mimhoBalance, token.balanceOf(address(vesting)));
        assertEq(founderClaimable, 0);
        assertEq(ecosystemClaimable, 0);
    }

    // =====================================================
    // PAUSE / DAO / CONFIG
    // =====================================================

    function test_PauseAndUnpause() public {
        vesting.pauseEmergencial();
        assertTrue(vesting.paused());

        vesting.unpause();
        assertFalse(vesting.paused());
    }

    function test_RefreshDAOAndActivateDAO() public {
        vesting.refreshDAOFromRegistry();

        assertEq(vesting.dao(), dao);
        assertFalse(vesting.daoActivated());

        vesting.activateDAO();

        assertTrue(vesting.daoActivated());
    }

    function test_Revert_ActivateDAOWithoutRefresh() public {
        vm.expectRevert(bytes("DAO_NOT_SET"));
        vesting.activateDAO();
    }

    function test_DAOCanOperateAfterActivation() public {
        vesting.refreshDAOFromRegistry();
        vesting.activateDAO();

        vm.prank(dao);
        vesting.pauseEmergencial();

        assertTrue(vesting.paused());
    }

    function test_DAOCannotOperateBeforeActivation() public {
        vesting.refreshDAOFromRegistry();

        vm.prank(dao);
        vm.expectRevert(bytes("ONLY_DAO_OR_OWNER"));
        vesting.pauseEmergencial();
    }

    function test_OwnerCannotOperateAfterDAOActivation() public {
        vesting.refreshDAOFromRegistry();
        vesting.activateDAO();

        vm.expectRevert(bytes("ONLY_DAO_OR_OWNER"));
        vesting.pauseEmergencial();
    }

    function test_SetEcosystemReceiver() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        assertEq(vesting.ecosystemReceiver(), ecosystemReceiver);
    }

    function test_Revert_SetEcosystemReceiverZero() public {
        vm.expectRevert(bytes("ZERO_ADDR"));
        vesting.setEcosystemReceiver(address(0));
    }

    function test_FinalizeBlocksConfigSetters() public {
        vesting.finalize();
        assertTrue(vesting.finalized());

        vm.expectRevert(bytes("FINALIZED"));
        vesting.setEcosystemReceiver(ecosystemReceiver);

        vm.expectRevert(bytes("FINALIZED"));
        vesting.initEcosystem(uint64(block.timestamp + 1 days));
    }

    function test_BrokenEventsHubDoesNotBreakSetters() public {
        MockBrokenVestingEventsHub brokenHub = new MockBrokenVestingEventsHub();

        registry.set(registry.KEY_MIMHO_EVENTS_HUB(), address(brokenHub));

        vesting.setEcosystemReceiver(ecosystemReceiver);

        assertEq(vesting.ecosystemReceiver(), ecosystemReceiver);
    }

    // =====================================================
    // FOUNDER VESTING
    // =====================================================

    function test_InitFounderAllocation() public {
        vesting.initFounderAllocation();

        (
            uint64 cliffEnd,
            uint64 monthlyStart,
            uint256 totalAllocated,
            uint256 totalClaimed,
            bool initialized
        ) = vesting.founder();

        assertEq(cliffEnd, uint64(block.timestamp + uint256(vesting.THREE_MONTHS())));
        assertEq(monthlyStart, cliffEnd);
        assertEq(totalAllocated, vesting.FOUNDER_TOTAL());
        assertEq(totalClaimed, 0);
        assertTrue(initialized);
    }

    function test_Revert_InitFounderAllocationTwice() public {
        vesting.initFounderAllocation();

        vm.expectRevert(bytes("FOUNDER_ALREADY_INIT"));
        vesting.initFounderAllocation();
    }

    function test_FounderClaimAfterOneMonthFromCliff() public {
        vesting.initFounderAllocation();

        vm.warp(block.timestamp + uint256(vesting.THREE_MONTHS()) + uint256(vesting.MONTH()));

        uint256 claimable = vesting.founderClaimableNow();
        assertEq(claimable, vesting.FOUNDER_MONTHLY_RELEASE());

        vesting.claimFounder();

        assertEq(token.balanceOf(vesting.FOUNDER_SAFE()), vesting.FOUNDER_MONTHLY_RELEASE());
    }

    function test_FounderClaimFullAfterTenMonths() public {
        vesting.initFounderAllocation();

        vm.warp(
            block.timestamp +
            uint256(vesting.THREE_MONTHS()) +
            (uint256(vesting.MONTH()) * vesting.FOUNDER_MONTHS())
        );

        vesting.claimFounder();

        assertEq(token.balanceOf(vesting.FOUNDER_SAFE()), vesting.FOUNDER_TOTAL());
    }

    function test_Revert_FounderClaimBeforeCliff() public {
        vesting.initFounderAllocation();

        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        vesting.claimFounder();
    }

    function test_Revert_FounderClaimWhenPaused() public {
        vesting.initFounderAllocation();
        vesting.pauseEmergencial();

        vm.warp(block.timestamp + uint256(vesting.THREE_MONTHS()) + uint256(vesting.MONTH()));

        vm.expectRevert(bytes("PAUSED"));
        vesting.claimFounder();
    }

    // =====================================================
    // MARKETING VESTING
    // =====================================================

    function test_RegisterMarketingVesting() public {
        uint64 start = uint64(block.timestamp + 1);

        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);

        (
            uint256 totalAllocated,
            uint256 totalClaimed,
            uint64 startTimestamp,
            uint64 lastClaimTimestamp
        ) = vesting.getMarketingInfo(alice);

        assertEq(totalAllocated, ONE_THOUSAND);
        assertEq(totalClaimed, 0);
        assertEq(startTimestamp, start);
        assertEq(lastClaimTimestamp, start);
    }

    function test_Revert_RegisterMarketingBadParams() public {
        uint64 start = uint64(block.timestamp + 1);

        vm.expectRevert(bytes("ZERO_ADDR"));
        vesting.registerMarketingVesting(address(0), ONE_THOUSAND, start);

        vm.expectRevert(bytes("ZERO_AMOUNT"));
        vesting.registerMarketingVesting(alice, 0, start);

        vm.expectRevert(bytes("BAD_START"));
        vesting.registerMarketingVesting(alice, ONE_THOUSAND, 0);
    }

    function test_Revert_RegisterMarketingTwice() public {
        uint64 start = uint64(block.timestamp + 1);

        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);

        vm.expectRevert(bytes("ALREADY_REGISTERED"));
        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);
    }

    function test_MarketingClaimAtStartGetsTge() public {
        uint64 start = uint64(block.timestamp + 1);

        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);

        vm.warp(start);

        vm.prank(alice);
        vesting.claimMarketing();

        assertEq(token.balanceOf(alice), 200 ether);
    }

    function test_MarketingClaimAfterOneWeekGetsThirtyPercent() public {
        uint64 start = uint64(block.timestamp + 1);

        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);

        vm.warp(start + vesting.WEEK());

        vm.prank(alice);
        vesting.claimMarketing();

        assertEq(token.balanceOf(alice), 300 ether);
    }

    function test_Revert_MarketingClaimWithoutPosition() public {
        vm.prank(alice);
        vm.expectRevert(bytes("NO_POSITION"));
        vesting.claimMarketing();
    }

    function test_Revert_MarketingClaimBeforeStart() public {
        uint64 start = uint64(block.timestamp + 1 days);

        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);

        vm.prank(alice);
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        vesting.claimMarketing();
    }

    // =====================================================
    // ECOSYSTEM VESTING
    // =====================================================

    function test_InitEcosystem() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        uint64 start = uint64(block.timestamp + 1 days);

        vesting.initEcosystem(start);

        (
            bool initialized,
            uint64 startTimestamp,
            uint256 totalAllocated,
            uint256 totalClaimed
        ) = vesting.ecosystem();

        assertTrue(initialized);
        assertEq(startTimestamp, start);
        assertEq(totalAllocated, vesting.ECOSYSTEM_TOTAL());
        assertEq(totalClaimed, 0);
    }

    function test_Revert_InitEcosystemWithoutReceiver() public {
        vm.expectRevert(bytes("ECO_NO_RECEIVER"));
        vesting.initEcosystem(uint64(block.timestamp + 1 days));
    }

    function test_Revert_InitEcosystemTwice() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        uint64 start = uint64(block.timestamp + 1 days);

        vesting.initEcosystem(start);

        vm.expectRevert(bytes("ECO_ALREADY_INIT"));
        vesting.initEcosystem(start);
    }

    function test_EcosystemClaimAfterOneWeek() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        uint64 start = uint64(block.timestamp + 1);

        vesting.initEcosystem(start);

        vm.warp(start + vesting.WEEK());

        vesting.claimEcosystem();

        assertEq(token.balanceOf(ecosystemReceiver), vesting.ECOSYSTEM_WEEKLY_RELEASE());
    }

    function test_EcosystemClaimFullAfterEightyWeeks() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        uint64 start = uint64(block.timestamp + 1);

        vesting.initEcosystem(start);

        vm.warp(start + (vesting.WEEK() * vesting.ECOSYSTEM_WEEKS()));

        vesting.claimEcosystem();

        assertEq(token.balanceOf(ecosystemReceiver), vesting.ECOSYSTEM_TOTAL());
    }

    function test_Revert_EcosystemClaimBeforeInit() public {
        vm.expectRevert(bytes("ECO_NOT_INIT"));
        vesting.claimEcosystem();
    }

    function test_Revert_EcosystemClaimBeforeUnlock() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        uint64 start = uint64(block.timestamp + 1 days);

        vesting.initEcosystem(start);

        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        vesting.claimEcosystem();
    }

    // =====================================================
    // RECOVERY / TRANSFER FAIL
    // =====================================================

    function test_RecoverForeignERC20() public {
        MockVestingToken foreignToken = new MockVestingToken();

        foreignToken.mint(address(vesting), 1_000 ether);

        vesting.recoverERC20(address(foreignToken), foreignTokenReceiver, 400 ether);

        assertEq(foreignToken.balanceOf(foreignTokenReceiver), 400 ether);
        assertEq(foreignToken.balanceOf(address(vesting)), 600 ether);
    }

    function test_Revert_RecoverMIMHO() public {
        vm.expectRevert(bytes("NO_RECOVER_MIMHO"));
        vesting.recoverERC20(address(token), foreignTokenReceiver, 1 ether);
    }

    function test_Revert_RecoverZeroReceiver() public {
        MockVestingToken foreignToken = new MockVestingToken();

        vm.expectRevert(bytes("ZERO_ADDR"));
        vesting.recoverERC20(address(foreignToken), address(0), 1 ether);
    }

    function test_Revert_RecoverZeroAmount() public {
        MockVestingToken foreignToken = new MockVestingToken();

        vm.expectRevert(bytes("ZERO_AMOUNT"));
        vesting.recoverERC20(address(foreignToken), foreignTokenReceiver, 0);
    }

    function test_Revert_MarketingClaimWhenTransferFails() public {
        uint64 start = uint64(block.timestamp + 1);

        vesting.registerMarketingVesting(alice, ONE_THOUSAND, start);

        vm.warp(start);

        token.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(bytes("TRANSFER_FAIL"));
        vesting.claimMarketing();
    }

    function test_Revert_EcosystemClaimWhenTransferFails() public {
        vesting.setEcosystemReceiver(ecosystemReceiver);

        uint64 start = uint64(block.timestamp + 1);

        vesting.initEcosystem(start);

        vm.warp(start + vesting.WEEK());

        token.setFailTransfer(true);

        vm.expectRevert(bytes("TRANSFER_FAIL"));
        vesting.claimEcosystem();
    }
}

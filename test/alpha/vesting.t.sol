// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/vesting.sol";

/* =======================
   MOCKS
   ======================= */

contract MockToken is IERC20Minimal {
    mapping(address => uint256) public bal;

    function mint(address to, uint256 amount) external {
        bal[to] += amount;
    }

    function balanceOf(address a) external view returns (uint256) {
        return bal[a];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(bal[msg.sender] >= amount, "NO_BAL");
        bal[msg.sender] -= amount;
        bal[to] += amount;
        return true;
    }
}

contract MockHub is IMIMHOEventsHub {
    event HubEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes data);
    function emitEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes calldata data) external {
        emit HubEvent(module, action, caller, value, data);
    }
}

contract MockRegistry is IMIMHORegistry {
    mapping(bytes32 => address) public addrs;

    bytes32 private constant KEY_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 private constant KEY_DAO = keccak256("MIMHO_DAO");

    function set(bytes32 k, address v) external { addrs[k] = v; }

    function getContract(bytes32 key) external view returns (address) {
        return addrs[key];
    }

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32) { return KEY_HUB; }
    function KEY_MIMHO_DAO() external view returns (bytes32) { return KEY_DAO; }
}

/* =======================
   TEST
   ======================= */

contract MIMHOVestingAlphaTest is Test {
    MockToken token;
    MockHub hub;
    MockRegistry registry;
    MIMHOVesting vest;

    address owner = address(0xA11CE);
    address dao   = address(0xDA0);
    address presale = address(0xBEEF);
    address ecoReceiver = address(0xEC0);

    address user1 = address(0xB0B);
    address user2 = address(0xCAFE);

    function setUp() public {
        vm.startPrank(owner);

        token = new MockToken();
        hub = new MockHub();
        registry = new MockRegistry();

        registry.set(keccak256("MIMHO_EVENTS_HUB"), address(hub));
        registry.set(keccak256("MIMHO_DAO"), dao);

        vest = new MIMHOVesting(address(token), address(registry));

        // fund the vesting contract with plenty of tokens
        token.mint(address(vest), 500_000_000_000 ether);

        // set presale + ecosystem receiver (config mode)
        vest.setPresaleContract(presale);
        vest.setEcosystemReceiver(ecoReceiver);

        vm.stopPrank();
    }

    function test_Founder_InitAndClaim_BeforeCliff_Reverts() public {
        vm.prank(owner);
        vest.initFounderAllocation();

        // before cliff ends -> nothing claimable
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        vest.claimFounder();
    }

    function test_Founder_Claim_AfterCliff_Works() public {
        vm.prank(owner);
        vest.initFounderAllocation();

        // jump to after cliff + 30 days to unlock some amount
        uint64 cliff = vest.founderNextClaimTime(); // returns cliffEnd when before cliff
        vm.warp(uint256(cliff) + 30 days);

        uint256 beforeBal = token.bal(vest.FOUNDER_SAFE());
        vest.claimFounder();
        uint256 afterBal = token.bal(vest.FOUNDER_SAFE());

        assertGt(afterBal, beforeBal);
    }

    function test_Presale_Register_OnlyPresale() public {
        vm.prank(owner);
        vest.initFounderAllocation();

        vm.expectRevert(bytes("ONLY_PRESALE"));
        vest.registerPresaleVesting(user1, 1000 ether, 2000, 500, uint64(block.timestamp));
    }

    function test_Presale_Register_And_Claim_Weekly() public {
        uint64 start = uint64(block.timestamp);

        vm.prank(presale);
        vest.registerPresaleVesting(user1, 1000 ether, 2000, 500, start); // 20% already paid; 5% weekly

        // immediately claim should be 0 (elapsed 0)
        vm.prank(user1);
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        vest.claimPresale();

        // after 7 days -> 5% of totalPurchased = 50 tokens claimable (vesting portion)
        vm.warp(block.timestamp + 7 days);

        uint256 before = token.bal(user1);
        vm.prank(user1);
        vest.claimPresale();
        uint256 after_ = token.bal(user1);

        // 5% of 1000 = 50
        assertEq(after_ - before, 50 ether);
    }

    function test_Marketing_Register_And_Claim_TGE() public {
        uint64 start = uint64(block.timestamp);

        vm.prank(owner);
        vest.registerMarketingVesting(user2, 1000 ether, start);

        // 20% instantly unlocked
        uint256 before = token.bal(user2);
        vm.prank(user2);
        vest.claimMarketing();
        uint256 after_ = token.bal(user2);

        assertEq(after_ - before, 200 ether);
    }

    function test_Ecosystem_Init_And_Claim() public {
        uint64 start = uint64(block.timestamp);

        vm.prank(owner);
        vest.initEcosystem(start);

        // before 1 week, weeksElapsed = 0 -> claimable 0
        vm.expectRevert(bytes("NOTHING_TO_CLAIM"));
        vest.claimEcosystem();

        // after 1 week -> 2.5B
        vm.warp(block.timestamp + 7 days);

        uint256 before = token.bal(ecoReceiver);
        vest.claimEcosystem();
        uint256 after_ = token.bal(ecoReceiver);

        assertEq(after_ - before, 2_500_000_000 ether);
    }

    function test_Pause_Blocks_Claims() public {
        // pause
        vm.prank(owner);
        vest.pauseEmergencial();

        vm.expectRevert(bytes("PAUSED"));
        vest.claimEcosystem();
    }

    function test_Finalize_Blocks_Config() public {
        vm.prank(owner);
        vest.finalize();

        vm.prank(owner);
        vm.expectRevert(bytes("FINALIZED"));
        vest.setEcosystemReceiver(address(0x1234));
    }
}

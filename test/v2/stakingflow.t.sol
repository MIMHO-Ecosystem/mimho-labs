// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/v2/staking.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockRegistry.sol";
import "./mocks/MockBrokenERC20.sol";

contract StakingFlowTest is Test {
    MockERC20 token;
    MockRegistry registry;
    MIMHOStaking staking;
    StakingHandler handler;

    uint256 constant MIN_STAKE = 100_000 ether;
    uint256 constant MAX_FUZZ_STAKE = 500_000 ether;
    uint256 constant USER_INITIAL_BALANCE = 10_000_000 ether;
    uint256 constant REWARD_FUND = 10_000_000 ether;

    address alice = address(1);
    address bob   = address(2);
    address carol = address(3);

    function setUp() public {
        token = new MockERC20();
        registry = new MockRegistry(address(token));
        staking = new MIMHOStaking(address(registry));

        token.mint(alice, USER_INITIAL_BALANCE);
        token.mint(bob, USER_INITIAL_BALANCE);
        token.mint(carol, USER_INITIAL_BALANCE);

        token.mint(address(this), REWARD_FUND);
        token.approve(address(staking), REWARD_FUND);
        staking.fundRewards(REWARD_FUND);

        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);

        vm.prank(carol);
    token.approve(address(staking), type(uint256).max);

    handler = new StakingHandler(staking, token, alice, bob, carol);

    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = StakingHandler.stake.selector;
    selectors[1] = StakingHandler.unstake.selector;
    selectors[2] = StakingHandler.claim.selector;
    selectors[3] = StakingHandler.warpTime.selector;

    targetContract(address(handler));
    targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
}

    // =====================================================
    // CORE FLOW TESTS — REAL CONTRACT PATHS
    // =====================================================

    function test_Stake() public {
        vm.prank(alice);
        staking.stake(MIN_STAKE);

        (uint256 amount,,,,,,) = staking.getUser(alice);
        assertEq(amount, MIN_STAKE);
        assertEq(staking.totalStaked(), MIN_STAKE);
    }

    function test_Unstake() public {
        vm.startPrank(alice);
        staking.stake(MIN_STAKE);
        staking.unstake(40_000 ether);
        vm.stopPrank();

        (uint256 amount,,,,,,) = staking.getUser(alice);
        assertEq(amount, 60_000 ether);
        assertEq(staking.totalStaked(), 60_000 ether);
    }

    function test_Claim() public {
        vm.prank(alice);
        staking.stake(MIN_STAKE);

        vm.warp(block.timestamp + 10 days);

        vm.prank(alice);
        staking.claim();

        (,,,, uint256 accrued,,) = staking.getUser(alice);
        assertEq(accrued, 0);
    }

    function test_Revert_StakeZero() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.stake(0);
    }

    function test_Revert_UnstakeTooMuch() public {
        vm.startPrank(alice);
        staking.stake(MIN_STAKE);

        vm.expectRevert();
        staking.unstake(MIN_STAKE + 1);
        vm.stopPrank();
    }

    function test_Revert_ClaimWithoutStake() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.claim();
    }

    function test_Revert_ClaimBeforeMinHold() public {
        vm.prank(alice);
        staking.stake(MIN_STAKE);

        vm.warp(block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert();
        staking.claim();
    }

    // =====================================================
    // FUZZ — REALISTIC BOUNDING
    // =====================================================

    function testFuzz_Stake(uint256 amount) public {
        amount = bound(amount, MIN_STAKE, MAX_FUZZ_STAKE);

        vm.prank(alice);
        staking.stake(amount);

        (uint256 staked,,,,,,) = staking.getUser(alice);
        assertEq(staked, amount);
        assertEq(staking.totalStaked(), amount);
    }

    function testFuzz_Unstake(uint256 amount) public {
        amount = bound(amount, MIN_STAKE, MAX_FUZZ_STAKE);

        uint256 unstakeAmount = amount / 2;

        vm.startPrank(alice);
        staking.stake(amount);
        staking.unstake(unstakeAmount);
        vm.stopPrank();

        (uint256 staked,,,,,,) = staking.getUser(alice);
        assertEq(staked, amount - unstakeAmount);
        assertEq(staking.totalStaked(), amount - unstakeAmount);
    }

    function testFuzz_ClaimTime(uint256 amount, uint32 t) public {
        amount = bound(amount, MIN_STAKE, MAX_FUZZ_STAKE);
        t = uint32(bound(uint256(t), 7 days, 30 days));

        vm.prank(alice);
        staking.stake(amount);

        vm.warp(block.timestamp + t);

        vm.prank(alice);
        staking.claim();

        (,,,, uint256 accrued,,) = staking.getUser(alice);
        assertEq(accrued, 0);
    }

    function testFuzz_MultipleUsersStake(uint256 a, uint256 b, uint256 c) public {
        a = bound(a, MIN_STAKE, MAX_FUZZ_STAKE);
        b = bound(b, MIN_STAKE, MAX_FUZZ_STAKE);
        c = bound(c, MIN_STAKE, MAX_FUZZ_STAKE);

        vm.prank(alice);
        staking.stake(a);

        vm.prank(bob);
        staking.stake(b);

        vm.prank(carol);
        staking.stake(c);

        assertEq(staking.totalStaked(), a + b + c);

        (uint256 aliceStake,,,,,,) = staking.getUser(alice);
        (uint256 bobStake,,,,,,) = staking.getUser(bob);
        (uint256 carolStake,,,,,,) = staking.getUser(carol);

        assertEq(aliceStake, a);
        assertEq(bobStake, b);
        assertEq(carolStake, c);
    }

// =====================================================
    // ADMIN / GOVERNANCE / SAFETY FLOW TESTS
    // =====================================================

    function test_SetReinvestTrueAndFalse() public {
        vm.startPrank(alice);
        staking.stake(MIN_STAKE);

        staking.setReinvest(true);
        (,,,,, bool reinvestEnabled,) = staking.getUser(alice);
        assertEq(reinvestEnabled, true);

        staking.setReinvest(false);
        (,,,,, bool reinvestDisabled,) = staking.getUser(alice);
        assertEq(reinvestDisabled, false);

        vm.stopPrank();
    }

    function test_ReinvestClaimAddsToStake() public {
        vm.startPrank(alice);
        staking.stake(MIN_STAKE);
        staking.setReinvest(true);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.prank(alice);
        staking.claim();

        (uint256 amountAfter,,,, uint256 accruedAfter,,) = staking.getUser(alice);

        assertGt(amountAfter, MIN_STAKE);
        assertEq(accruedAfter, 0);
        assertEq(staking.totalStaked(), amountAfter);
    }

    function test_PauseBlocksStake() public {
        staking.pauseEmergency();

        vm.prank(alice);
        vm.expectRevert();
        staking.stake(MIN_STAKE);

        staking.unpause();

        vm.prank(alice);
        staking.stake(MIN_STAKE);

        (uint256 amount,,,,,,) = staking.getUser(alice);
        assertEq(amount, MIN_STAKE);
    }

    function test_PauseBlocksUnstake() public {
        vm.prank(alice);
        staking.stake(MIN_STAKE);

        staking.pauseEmergency();

        vm.prank(alice);
        vm.expectRevert();
        staking.unstake(1 ether);

        staking.unpause();
    }

    function test_PauseBlocksClaim() public {
        vm.prank(alice);
        staking.stake(MIN_STAKE);

        vm.warp(block.timestamp + 10 days);

        staking.pauseEmergency();

        vm.prank(alice);
        vm.expectRevert();
        staking.claim();

        staking.unpause();
    }

    function test_BlacklistBlocksStake() public {
        staking.setBlacklist(alice, true);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: blacklisted"));
        staking.stake(MIN_STAKE);

        staking.setBlacklist(alice, false);

        vm.prank(alice);
        staking.stake(MIN_STAKE);

        (uint256 amount,,,,,,) = staking.getUser(alice);
        assertEq(amount, MIN_STAKE);
    }

    function test_BlacklistBlocksClaim() public {
        vm.prank(alice);
        staking.stake(MIN_STAKE);

        staking.setBlacklist(alice, true);

        vm.warp(block.timestamp + 10 days);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: blacklisted"));
        staking.claim();
    }

    function test_FundRewardsIncreasesReserve() public {
        uint256 beforeReserve = staking.rewardReserve();
        uint256 amount = 123_456 ether;

        vm.startPrank(bob);
        token.approve(address(staking), amount);
        staking.fundRewards(amount);
        vm.stopPrank();

        assertEq(staking.rewardReserve(), beforeReserve + amount);
    }

    function test_SyncRewardsFromBalance() public {
        uint256 extra = 777_777 ether;

        token.mint(address(staking), extra);

        uint256 expectedReserve = token.balanceOf(address(staking)) - staking.totalStaked();

        staking.syncRewardsFromBalance();

        assertEq(staking.rewardReserve(), expectedReserve);
    }

    function test_SetParamsOwner() public {
        uint256 newMinStake = 50_000 ether;
        uint256 newMinHold = 1 days;
        uint256 newCooldown = 1 days;
        uint256 newWeeklyLimit = 2_000_000_000 ether;
        uint256 newMaxClaimBps = 500;
        uint256 newBaseApy = 3_000;
        uint256 newMaxApy = 5_000;
        uint256 newMaxBoost = 1_000;

        staking.setParams(
            newMinStake,
            newMinHold,
            newCooldown,
            newWeeklyLimit,
            newMaxClaimBps,
            newBaseApy,
            newMaxApy,
            newMaxBoost
        );

        assertEq(staking.minStakeAmount(), newMinStake);
        assertEq(staking.minHoldToEarn(), newMinHold);
        assertEq(staking.claimCooldown(), newCooldown);
        assertEq(staking.weeklyLimit(), newWeeklyLimit);
        assertEq(staking.maxClaimBpsOfWeekly(), newMaxClaimBps);
        assertEq(staking.baseApyBpsTop(), newBaseApy);
        assertEq(staking.maxTotalApyBps(), newMaxApy);
        assertEq(staking.maxBoostBps(), newMaxBoost);
    }

    function test_DAOActivationTransfersOnlyDAOControl() public {
        address daoAddr = address(99);

        staking.setDAO(daoAddr);
        assertEq(staking.dao(), daoAddr);

        staking.activateDAO();
        assertEq(staking.daoActivated(), true);

        vm.expectRevert();
        staking.pauseEmergency();

        vm.prank(daoAddr);
        staking.pauseEmergency();

        assertEq(staking.paused(), true);

        vm.prank(daoAddr);
        staking.unpause();

        assertEq(staking.paused(), false);
    }

// =====================================================
    // FAILURE / ATOMICITY TESTS
    // =====================================================

    function test_FundRewardsRevertsWhenTransferFromFails() public {
        MockBrokenERC20 broken = new MockBrokenERC20();
        MockRegistry brokenRegistry = new MockRegistry(address(broken));
        MIMHOStaking brokenStaking = new MIMHOStaking(address(brokenRegistry));

        broken.mint(address(this), REWARD_FUND);
        broken.approve(address(brokenStaking), REWARD_FUND);

        broken.setFailTransferFrom(true);

        vm.expectRevert(bytes("MIMHO: transferFrom fail"));
        brokenStaking.fundRewards(REWARD_FUND);

        assertEq(brokenStaking.rewardReserve(), 0);
        assertEq(broken.balanceOf(address(brokenStaking)), 0);
    }

    function test_StakeRevertsWhenTransferFromFailsAndDoesNotMarkStake() public {
        MockBrokenERC20 broken = new MockBrokenERC20();
        MockRegistry brokenRegistry = new MockRegistry(address(broken));
        MIMHOStaking brokenStaking = new MIMHOStaking(address(brokenRegistry));

        broken.mint(alice, USER_INITIAL_BALANCE);

        vm.prank(alice);
        broken.approve(address(brokenStaking), type(uint256).max);

        broken.setFailTransferFrom(true);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: transferFrom fail"));
        brokenStaking.stake(MIN_STAKE);

        (uint256 amount,,,,,,) = brokenStaking.getUser(alice);

        assertEq(amount, 0);
        assertEq(brokenStaking.totalStaked(), 0);
        assertEq(broken.balanceOf(address(brokenStaking)), 0);
        assertEq(broken.balanceOf(alice), USER_INITIAL_BALANCE);
    }

    function test_UnstakeRevertsWhenTransferFailsAndStateRollsBack() public {
        MockBrokenERC20 broken = new MockBrokenERC20();
        MockRegistry brokenRegistry = new MockRegistry(address(broken));
        MIMHOStaking brokenStaking = new MIMHOStaking(address(brokenRegistry));

        broken.mint(alice, USER_INITIAL_BALANCE);

        vm.startPrank(alice);
        broken.approve(address(brokenStaking), type(uint256).max);
        brokenStaking.stake(MIN_STAKE);
        vm.stopPrank();

        (uint256 beforeAmount,,,,,,) = brokenStaking.getUser(alice);
        uint256 beforeTotalStaked = brokenStaking.totalStaked();
        uint256 beforeAliceBalance = broken.balanceOf(alice);
        uint256 beforeContractBalance = broken.balanceOf(address(brokenStaking));

        broken.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: transfer fail"));
        brokenStaking.unstake(10_000 ether);

        (uint256 afterAmount,,,,,,) = brokenStaking.getUser(alice);

        assertEq(afterAmount, beforeAmount);
        assertEq(brokenStaking.totalStaked(), beforeTotalStaked);
        assertEq(broken.balanceOf(alice), beforeAliceBalance);
        assertEq(broken.balanceOf(address(brokenStaking)), beforeContractBalance);
    }

    function test_ClaimRevertsWhenTransferFailsAndDoesNotMarkClaimed() public {
        MockBrokenERC20 broken = new MockBrokenERC20();
        MockRegistry brokenRegistry = new MockRegistry(address(broken));
        MIMHOStaking brokenStaking = new MIMHOStaking(address(brokenRegistry));

        broken.mint(address(this), REWARD_FUND);
        broken.approve(address(brokenStaking), REWARD_FUND);
        brokenStaking.fundRewards(REWARD_FUND);

        broken.mint(alice, USER_INITIAL_BALANCE);

        vm.startPrank(alice);
        broken.approve(address(brokenStaking), type(uint256).max);
        brokenStaking.stake(MIN_STAKE);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        (,, uint256 lastAccrueBefore, uint256 lastClaimBefore, uint256 accruedBefore,,) =
            brokenStaking.getUser(alice);

        uint256 reserveBefore = brokenStaking.rewardReserve();
        uint256 aliceBalanceBefore = broken.balanceOf(alice);
        uint256 contractBalanceBefore = broken.balanceOf(address(brokenStaking));

        broken.setFailTransfer(true);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: transfer fail"));
        brokenStaking.claim();

        (,, uint256 lastAccrueAfter, uint256 lastClaimAfter, uint256 accruedAfter,,) =
            brokenStaking.getUser(alice);

        assertEq(lastAccrueAfter, lastAccrueBefore);
        assertEq(lastClaimAfter, lastClaimBefore);
        assertEq(accruedAfter, accruedBefore);
        assertEq(brokenStaking.rewardReserve(), reserveBefore);
        assertEq(broken.balanceOf(alice), aliceBalanceBefore);
        assertEq(broken.balanceOf(address(brokenStaking)), contractBalanceBefore);
    }

    function test_ClaimWithoutRewardReserveDoesNotMarkClaimed() public {
        MockBrokenERC20 broken = new MockBrokenERC20();
        MockRegistry brokenRegistry = new MockRegistry(address(broken));
        MIMHOStaking brokenStaking = new MIMHOStaking(address(brokenRegistry));

        broken.mint(alice, USER_INITIAL_BALANCE);

        vm.startPrank(alice);
        broken.approve(address(brokenStaking), type(uint256).max);
        brokenStaking.stake(MIN_STAKE);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        (,, uint256 lastAccrueBefore, uint256 lastClaimBefore, uint256 accruedBefore,,) =
            brokenStaking.getUser(alice);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: no reward"));
        brokenStaking.claim();

        (,, uint256 lastAccrueAfter, uint256 lastClaimAfter, uint256 accruedAfter,,) =
            brokenStaking.getUser(alice);

        assertEq(lastAccrueAfter, lastAccrueBefore);
        assertEq(lastClaimAfter, lastClaimBefore);
        assertEq(accruedAfter, accruedBefore);
        assertEq(brokenStaking.rewardReserve(), 0);
    }

// =====================================================
    // INVARIANTS — HANDLER-BASED STATEFUL FUZZING
    // =====================================================

    function invariant_TotalStakedMatchesHandlerShadow() public view {
        assertEq(staking.totalStaked(), handler.shadowTotalStaked());
    }

    function invariant_UserStakesMatchHandlerShadow() public view {
        assertEq(_userStake(alice), handler.shadowStake(alice));
        assertEq(_userStake(bob), handler.shadowStake(bob));
        assertEq(_userStake(carol), handler.shadowStake(carol));
    }

    function invariant_ContractBalanceCoversStakeAndReserve() public view {
        uint256 contractBalance = token.balanceOf(address(staking));
        uint256 expectedMinimum = staking.totalStaked() + staking.rewardReserve();

        assertGe(contractBalance, expectedMinimum);
    }

    function _userStake(address user) internal view returns (uint256 amount) {
        (amount,,,,,,) = staking.getUser(user);
    }

}

contract StakingHandler is Test {
    MIMHOStaking public staking;
    MockERC20 public token;

    address public alice;
    address public bob;
    address public carol;

    uint256 public constant MIN_STAKE = 100_000 ether;
    uint256 public constant MAX_STAKE = 500_000 ether;
    uint256 public constant MAX_WARP = 30 days;

    uint256 public shadowTotalStaked;
    mapping(address => uint256) public shadowStake;

    constructor(
        MIMHOStaking _staking,
        MockERC20 _token,
        address _alice,
        address _bob,
        address _carol
    ) {
        staking = _staking;
        token = _token;
        alice = _alice;
        bob = _bob;
        carol = _carol;
    }

    function stake(uint256 actorSeed, uint256 amount) external {
        address user = _actor(actorSeed);

        uint256 balance = token.balanceOf(user);
        if (balance < MIN_STAKE) return;

        uint256 upper = balance < MAX_STAKE ? balance : MAX_STAKE;
        amount = bound(amount, MIN_STAKE, upper);

        vm.prank(user);
        try staking.stake(amount) {
            shadowStake[user] += amount;
            shadowTotalStaked += amount;
        } catch {
            // ignored intentionally: handler must not revert
        }
    }

    function unstake(uint256 actorSeed, uint256 amount) external {
        address user = _actor(actorSeed);

        uint256 currentStake = shadowStake[user];
        if (currentStake == 0) return;

        amount = bound(amount, 1, currentStake);

        vm.prank(user);
        try staking.unstake(amount) {
            shadowStake[user] -= amount;
            shadowTotalStaked -= amount;
        } catch {
            // ignored intentionally: handler must not revert
        }
    }

    function claim(uint256 actorSeed, uint32 warpBy) external {
        address user = _actor(actorSeed);

        if (shadowStake[user] == 0) return;

        warpBy = uint32(bound(uint256(warpBy), 0, MAX_WARP));
        vm.warp(block.timestamp + warpBy);

        vm.prank(user);
        try staking.claim() {
            // claim without reinvest does not change stake shadow
        } catch {
            // ignored intentionally: claim may revert before min hold/cooldown/no reward
        }
    }

    function warpTime(uint32 warpBy) external {
        warpBy = uint32(bound(uint256(warpBy), 0, MAX_WARP));
        vm.warp(block.timestamp + warpBy);
    }

    function _actor(uint256 actorSeed) internal view returns (address) {
        uint256 index = actorSeed % 3;

        if (index == 0) return alice;
        if (index == 1) return bob;
        return carol;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/v2/token.sol";

contract MockTokenRegistry {
    mapping(bytes32 => address) public contractsByKey;

    function set(bytes32 key, address value) external {
        contractsByKey[key] = value;
    }

    function getContract(bytes32 key) external view returns (address) {
        return contractsByKey[key];
    }
}

contract TokenFlowTest is Test {
    MIMHO token;
    MockTokenRegistry registry;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address dao = address(0xDA0);
    address pair = address(0xFA1);
    address stakingTarget = address(0x5700);
    address marketingWallet = address(0xBEEF);

    address constant FOUNDER = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address constant LP_RESERVE = 0xb891C4e94a1F4B7Aa35d21BbA37D245909B6ad95;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 constant TOTAL_SUPPLY = 1_000_000_000_000 ether;
    uint256 constant MIN_SUPPLY = 500_000_000_000 ether;
    uint256 constant MAX_BUY_AMOUNT = 500_000_000 ether;

    bytes32 constant KEY_STAKING = keccak256("STAKING_CONTRACT");
    bytes32 constant KEY_MARKETING_WALLET = keccak256("MARKETING_WALLET");

    function setUp() public {
        token = new MIMHO();
        registry = new MockTokenRegistry();

        registry.set(KEY_STAKING, stakingTarget);
        registry.set(KEY_MARKETING_WALLET, marketingWallet);
    }

    // =====================================================
    // METADATA / SUPPLY
    // =====================================================

    function test_Metadata() public {
        assertEq(token.name(), "MIMHO");
        assertEq(token.symbol(), "MIMHO");
        assertEq(token.decimals(), 18);
        assertEq(token.version(), "1.0.4");
    }

    function test_TotalSupplyAndInitialOwnerBalance() public {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
        assertEq(token.balanceOf(owner), TOTAL_SUPPLY);
        assertEq(token.circulatingSupply(), TOTAL_SUPPLY);
        assertEq(token.owner(), owner);
    }

    function test_BurnFloorInitiallyFalse() public {
        assertFalse(token.burnFloorReached());
    }

    // =====================================================
    // BASIC ERC20
    // =====================================================

    function test_OwnerCanTransferBeforeTradingEnabled() public {
        token.transfer(alice, 1_000 ether);

        assertEq(token.balanceOf(alice), 1_000 ether);
        assertEq(token.balanceOf(owner), TOTAL_SUPPLY - 1_000 ether);
    }

    function test_Revert_NonOwnerWalletTransferBeforeTradingEnabled() public {
        token.transfer(alice, 1_000 ether);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: Trading disabled"));
        token.transfer(bob, 100 ether);
    }

    function test_WalletToWalletAfterTradingHasNoFee() public {
        token.transfer(alice, 10_000 ether);
        token.enableTrading();

        vm.prank(alice);
        token.transfer(bob, 1_000 ether);

        assertEq(token.balanceOf(bob), 1_000 ether);
        assertEq(token.balanceOf(alice), 9_000 ether);
        assertEq(token.balanceOf(FOUNDER), 0);
    }

    function test_ApproveAndTransferFrom() public {
        token.transfer(alice, 10_000 ether);
        token.enableTrading();

        vm.prank(alice);
        token.approve(bob, 2_000 ether);

        vm.prank(bob);
        token.transferFrom(alice, bob, 1_500 ether);

        assertEq(token.balanceOf(bob), 1_500 ether);
        assertEq(token.balanceOf(alice), 8_500 ether);
        assertEq(token.allowance(alice, bob), 500 ether);
    }

    function test_Revert_TransferFromWithoutAllowance() public {
        token.transfer(alice, 10_000 ether);
        token.enableTrading();

        vm.prank(bob);
        vm.expectRevert(bytes("MIMHO: Allowance exceeded"));
        token.transferFrom(alice, bob, 1 ether);
    }

    // =====================================================
    // TRADING / AMM
    // =====================================================

    function test_EnableTrading() public {
        assertFalse(token.isTradingEnabled());
        assertEq(token.tradingEnabledAt(), 0);

        token.enableTrading();

        assertTrue(token.isTradingEnabled());
        assertGt(token.tradingEnabledAt(), 0);
        assertTrue(token.maxBuyActive());
    }

    function test_Revert_EnableTradingTwice() public {
        token.enableTrading();

        vm.expectRevert(bytes("MIMHO: Trading already enabled"));
        token.enableTrading();
    }

    function test_SetAMMPair() public {
        token.setAMMPair(pair, true);

        assertTrue(token.isAMMPair(pair));
    }

    function test_Revert_SetAMMPairZero() public {
        vm.expectRevert(bytes("MIMHO: Pair zero"));
        token.setAMMPair(address(0), true);
    }

    function test_BuyTakesFounderFeeOnly() public {
        uint256 seed = 1_000_000 ether;
        uint256 buyAmount = 100_000 ether;
        uint256 founderFee = (buyAmount * 100) / 10_000;
        uint256 userAmount = buyAmount - founderFee;

        // Seed liquidity BEFORE marking pair as AMM.
        // If pair is already AMM, the seed transfer is treated as a sell and taxed.
        token.transfer(pair, seed);

        token.setAMMPair(pair, true);
        token.enableTrading();

        vm.prank(pair);
        token.transfer(alice, buyAmount);

        assertEq(token.balanceOf(alice), userAmount);
        assertEq(token.balanceOf(FOUNDER), founderFee);
        assertEq(token.balanceOf(pair), seed - buyAmount);
    }

    function test_Revert_MaxBuyDuringFirst20Minutes() public {
        uint256 seed = 1_000_000_000 ether;

        // Seed liquidity before registering AMM pair to avoid setup tax.
        token.transfer(pair, seed);

        token.setAMMPair(pair, true);
        token.enableTrading();

        vm.prank(pair);
        vm.expectRevert(bytes("MIMHO: MaxBuy first 20m"));
        token.transfer(alice, MAX_BUY_AMOUNT + 1 ether);
    }

    function test_LargeBuyAllowedAfterFirst20Minutes() public {
        uint256 seed = 1_000_000_000 ether;
        uint256 buyAmount = MAX_BUY_AMOUNT + 1 ether;
        uint256 founderFee = (buyAmount * 100) / 10_000;

        // Seed liquidity before registering AMM pair to avoid setup tax.
        token.transfer(pair, seed);

        token.setAMMPair(pair, true);
        token.enableTrading();

        vm.warp(block.timestamp + 21 minutes);

        vm.prank(pair);
        token.transfer(alice, buyAmount);

        assertEq(token.balanceOf(alice), buyAmount - founderFee);
        assertEq(token.balanceOf(FOUNDER), founderFee);
    }

    function test_SellTakesAllSellFeesWhenRegistryReady() public {
        token.setRegistry(address(registry));
        token.setAMMPair(pair, true);
        token.enableTrading();

        uint256 sellAmount = 100_000 ether;

        token.transfer(alice, sellAmount);

        uint256 founderFee = (sellAmount * 100) / 10_000;
        uint256 lpFee = (sellAmount * 18) / 10_000;
        uint256 burnFee = (sellAmount * 16) / 10_000;
        uint256 stakeFee = (sellAmount * 16) / 10_000;
        uint256 totalFee = founderFee + lpFee + burnFee + stakeFee;
        uint256 pairReceives = sellAmount - totalFee;

        vm.prank(alice);
        token.transfer(pair, sellAmount);

        assertEq(token.balanceOf(pair), pairReceives);
        assertEq(token.balanceOf(FOUNDER), founderFee);
        assertEq(token.balanceOf(LP_RESERVE), lpFee);
        assertEq(token.balanceOf(DEAD), burnFee);
        assertEq(token.balanceOf(stakingTarget), stakeFee);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_SellWithoutRegistryTakesFounderAndLPFeesOnly() public {
        token.setAMMPair(pair, true);
        token.enableTrading();

        uint256 sellAmount = 100_000 ether;

        token.transfer(alice, sellAmount);

        uint256 founderFee = (sellAmount * 100) / 10_000;
        uint256 lpFee = (sellAmount * 18) / 10_000;
        uint256 pairReceives = sellAmount - founderFee - lpFee;

        vm.prank(alice);
        token.transfer(pair, sellAmount);

        assertEq(token.balanceOf(pair), pairReceives);
        assertEq(token.balanceOf(FOUNDER), founderFee);
        assertEq(token.balanceOf(LP_RESERVE), lpFee);
        assertEq(token.balanceOf(DEAD), 0);
        assertEq(token.balanceOf(stakingTarget), 0);
    }

    function test_FeeExemptBypassesAMMFees() public {
        token.setRegistry(address(registry));
        token.setAMMPair(pair, true);
        token.setFeeExempt(alice, true);
        token.enableTrading();

        uint256 sellAmount = 100_000 ether;
        token.transfer(alice, sellAmount);

        vm.prank(alice);
        token.transfer(pair, sellAmount);

        assertEq(token.balanceOf(pair), sellAmount);
        assertEq(token.balanceOf(FOUNDER), 0);
        assertEq(token.balanceOf(LP_RESERVE), 0);
        assertEq(token.balanceOf(DEAD), 0);
        assertEq(token.balanceOf(stakingTarget), 0);
    }

    // =====================================================
    // PAUSE / GOVERNANCE
    // =====================================================

    function test_PauseBlocksTransfer() public {
        token.transfer(alice, 1_000 ether);
        token.enableTrading();

        token.pauseEmergency();

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: Paused"));
        token.transfer(bob, 1 ether);
    }

    function test_UnpauseRestoresTransfer() public {
        token.transfer(alice, 1_000 ether);
        token.enableTrading();

        token.pauseEmergency();
        token.unpause();

        vm.prank(alice);
        token.transfer(bob, 1 ether);

        assertEq(token.balanceOf(bob), 1 ether);
    }

    function test_SetDAOAndActivateDAO() public {
        token.setDAO(dao);
        assertEq(token.daoContract(), dao);
        assertFalse(token.daoActivated());

        token.activateDAO();
        assertTrue(token.daoActivated());
    }

    function test_DAOCanOperateAfterActivation() public {
        token.setDAO(dao);
        token.activateDAO();

        vm.prank(dao);
        token.setAMMPair(pair, true);

        assertTrue(token.isAMMPair(pair));
    }

    function test_Revert_DAOCannotOperateBeforeActivation() public {
        token.setDAO(dao);

        vm.prank(dao);
        vm.expectRevert(bytes("MIMHO: Owner only"));
        token.setAMMPair(pair, true);
    }

    function test_RenounceOnlyAfterDAOReady() public {
        vm.expectRevert(bytes("MIMHO: DAO not set"));
        token.renounceIfReady();

        token.setDAO(dao);

        vm.expectRevert(bytes("MIMHO: DAO not activated"));
        token.renounceIfReady();

        token.activateDAO();
        token.renounceIfReady();

        assertEq(token.owner(), address(0));
    }

    function test_Revert_RecoverOwnToken() public {
        vm.expectRevert(bytes("MIMHO: Cannot recover MIMHO"));
        token.recoverTokens(address(token), alice, 1 ether);
    }
// =====================================================
    // FUZZ TESTS — ERC20 CORE
    // =====================================================

    function testFuzz_WalletToWalletNoFee(uint256 amount) public {
        amount = bound(amount, 1, 10_000_000 ether);

        token.transfer(alice, amount);
        token.enableTrading();

        vm.prank(alice);
        token.transfer(bob, amount);

        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(FOUNDER), 0);
        assertEq(token.balanceOf(LP_RESERVE), 0);
        assertEq(token.balanceOf(DEAD), 0);
    }

    function testFuzz_ApproveTransferFrom(uint256 amount, uint256 spendAmount) public {
        amount = bound(amount, 1, 10_000_000 ether);
        spendAmount = bound(spendAmount, 1, amount);

        token.transfer(alice, amount);
        token.enableTrading();

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        token.transferFrom(alice, bob, spendAmount);

        assertEq(token.balanceOf(bob), spendAmount);
        assertEq(token.balanceOf(alice), amount - spendAmount);
        assertEq(token.allowance(alice, bob), amount - spendAmount);
    }

    function testFuzz_BuyFounderFee(uint256 buyAmount) public {
        buyAmount = bound(buyAmount, 1 ether, MAX_BUY_AMOUNT);

        uint256 seed = MAX_BUY_AMOUNT * 2;

        token.transfer(pair, seed);
        token.setAMMPair(pair, true);
        token.enableTrading();

        uint256 founderBefore = token.balanceOf(FOUNDER);

        vm.prank(pair);
        token.transfer(alice, buyAmount);

        uint256 founderFee = (buyAmount * 100) / 10_000;
        uint256 userAmount = buyAmount - founderFee;

        assertEq(token.balanceOf(alice), userAmount);
        assertEq(token.balanceOf(FOUNDER), founderBefore + founderFee);
        assertEq(token.balanceOf(pair), seed - buyAmount);
    }

    function testFuzz_SellFeesWithRegistry(uint256 sellAmount) public {
        sellAmount = bound(sellAmount, 1 ether, 10_000_000 ether);

        token.setRegistry(address(registry));
        token.setAMMPair(pair, true);
        token.enableTrading();

        token.transfer(alice, sellAmount);

        uint256 founderFee = (sellAmount * 100) / 10_000;
        uint256 lpFee = (sellAmount * 18) / 10_000;
        uint256 burnFee = (sellAmount * 16) / 10_000;
        uint256 stakeFee = (sellAmount * 16) / 10_000;
        uint256 totalFee = founderFee + lpFee + burnFee + stakeFee;
        uint256 pairReceives = sellAmount - totalFee;

        vm.prank(alice);
        token.transfer(pair, sellAmount);

        assertEq(token.balanceOf(pair), pairReceives);
        assertEq(token.balanceOf(FOUNDER), founderFee);
        assertEq(token.balanceOf(LP_RESERVE), lpFee);
        assertEq(token.balanceOf(DEAD), burnFee);
        assertEq(token.balanceOf(stakingTarget), stakeFee);
        assertEq(token.balanceOf(alice), 0);
    }

    // =====================================================
    // LAUNCH / LIQUIDITY EDGE CASES
    // =====================================================

    function test_LiquiditySeedBeforeAMMPairHasNoFee() public {
        uint256 seed = 1_000_000_000 ether;

        token.transfer(pair, seed);

        assertEq(token.balanceOf(pair), seed);
        assertEq(token.balanceOf(FOUNDER), 0);
        assertEq(token.balanceOf(LP_RESERVE), 0);
        assertEq(token.balanceOf(DEAD), 0);
    }

    function test_LiquiditySeedAfterAMMPairIsTaxedAsSell() public {
        uint256 seed = 1_000_000 ether;

        token.setAMMPair(pair, true);

        token.transfer(pair, seed);

        uint256 founderFee = (seed * 100) / 10_000;
        uint256 lpFee = (seed * 18) / 10_000;
        uint256 pairReceives = seed - founderFee - lpFee;

        assertEq(token.balanceOf(pair), pairReceives);
        assertEq(token.balanceOf(FOUNDER), founderFee);
        assertEq(token.balanceOf(LP_RESERVE), lpFee);
    }

    function test_FeeExemptLiquiditySeedAfterAMMPairHasNoFee() public {
        uint256 seed = 1_000_000 ether;

        token.setAMMPair(pair, true);
        token.setFeeExempt(owner, true);

        token.transfer(pair, seed);

        assertEq(token.balanceOf(pair), seed);
        assertEq(token.balanceOf(FOUNDER), 0);
        assertEq(token.balanceOf(LP_RESERVE), 0);
        assertEq(token.balanceOf(DEAD), 0);
    }

    function test_MaxBuyInactiveAfter20Minutes() public {
        uint256 seed = 2_000_000_000 ether;
        uint256 buyAmount = MAX_BUY_AMOUNT + 100 ether;

        token.transfer(pair, seed);
        token.setAMMPair(pair, true);
        token.enableTrading();

        vm.warp(block.timestamp + 20 minutes);

        assertFalse(token.maxBuyActive());

        vm.prank(pair);
        token.transfer(alice, buyAmount);

        uint256 founderFee = (buyAmount * 100) / 10_000;

        assertEq(token.balanceOf(alice), buyAmount - founderFee);
    }

    // =====================================================
    // SUPPLY / BALANCE INVARIANT HELPERS
    // =====================================================

    function test_TotalTrackedBalancesAfterCommonFlows() public {
        uint256 amount = 100_000 ether;

        token.setRegistry(address(registry));
        token.transfer(pair, 1_000_000 ether);
        token.setAMMPair(pair, true);
        token.enableTrading();

        vm.prank(pair);
        token.transfer(alice, amount);

        vm.prank(alice);
        token.transfer(pair, token.balanceOf(alice));

        uint256 tracked =
            token.balanceOf(owner) +
            token.balanceOf(pair) +
            token.balanceOf(alice) +
            token.balanceOf(FOUNDER) +
            token.balanceOf(LP_RESERVE) +
            token.balanceOf(DEAD) +
            token.balanceOf(stakingTarget);

        assertEq(tracked, TOTAL_SUPPLY);
    }

}

contract TokenHandler is Test {
    MIMHO public token;

    address public alice;
    address public bob;
    address public carol;
    address public pair;

    uint256 public constant MAX_ACTION_AMOUNT = 2_000_000 ether;

    constructor(
        MIMHO token_,
        address alice_,
        address bob_,
        address carol_,
        address pair_
    ) {
        token = token_;
        alice = alice_;
        bob = bob_;
        carol = carol_;
        pair = pair_;
    }

    function actionWalletTransfer(uint8 fromSeed, uint8 toSeed, uint256 amount) external {
        address from = _actor(fromSeed);
        address to = _actor(toSeed);

        if (from == to) return;

        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;

        uint256 maxAmount = bal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = bound(amount, 1, maxAmount);

        vm.prank(from);
        try token.transfer(to, amount) {} catch {}
    }

    function actionSell(uint8 actorSeed, uint256 amount) external {
        address seller = _actor(actorSeed);

        uint256 bal = token.balanceOf(seller);
        if (bal == 0) return;

        uint256 maxAmount = bal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = bound(amount, 1, maxAmount);

        vm.prank(seller);
        try token.transfer(pair, amount) {} catch {}
    }

    function actionBuy(uint8 actorSeed, uint256 amount) external {
        address buyer = _actor(actorSeed);

        uint256 pairBal = token.balanceOf(pair);
        if (pairBal == 0) return;

        uint256 maxAmount = pairBal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = bound(amount, 1, maxAmount);

        vm.prank(pair);
        try token.transfer(buyer, amount) {} catch {}
    }

    function actionApproveAndTransferFrom(
        uint8 ownerSeed,
        uint8 spenderSeed,
        uint8 toSeed,
        uint256 amount
    ) external {
        address tokenOwner = _actor(ownerSeed);
        address spender = _actor(spenderSeed);
        address to = _actor(toSeed);

        if (tokenOwner == spender) return;

        uint256 bal = token.balanceOf(tokenOwner);
        if (bal == 0) return;

        uint256 maxAmount = bal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = bound(amount, 1, maxAmount);

        vm.prank(tokenOwner);
        try token.approve(spender, amount) {} catch {
            return;
        }

        vm.prank(spender);
        try token.transferFrom(tokenOwner, to, amount) {} catch {}
    }

    function _actor(uint8 seed) internal view returns (address) {
        uint8 index = seed % 3;

        if (index == 0) return alice;
        if (index == 1) return bob;
        return carol;
    }
}

contract TokenInvariantTest is Test {
    MIMHO token;
    MockTokenRegistry registry;
    TokenHandler handler;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address carol = address(0xCA20);
    address pair = address(0xFA1);
    address stakingTarget = address(0x5700);
    address marketingWallet = address(0xBEEF);

    address constant FOUNDER = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address constant LP_RESERVE = 0xb891C4e94a1F4B7Aa35d21BbA37D245909B6ad95;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 constant TOTAL_SUPPLY = 1_000_000_000_000 ether;
    uint256 constant MIN_SUPPLY = 500_000_000_000 ether;

    bytes32 constant KEY_STAKING = keccak256("STAKING_CONTRACT");
    bytes32 constant KEY_MARKETING_WALLET = keccak256("MARKETING_WALLET");

    function setUp() public {
        token = new MIMHO();
        registry = new MockTokenRegistry();

        registry.set(KEY_STAKING, stakingTarget);
        registry.set(KEY_MARKETING_WALLET, marketingWallet);

        token.setRegistry(address(registry));

        token.transfer(alice, 10_000_000 ether);
        token.transfer(bob, 10_000_000 ether);
        token.transfer(carol, 10_000_000 ether);

        // Seed liquidity before setting AMM pair to avoid launch setup tax.
        token.transfer(pair, 100_000_000 ether);

        token.setAMMPair(pair, true);
        token.enableTrading();

        // Disable max-buy launch window for invariant random buys.
        vm.warp(block.timestamp + 21 minutes);

        handler = new TokenHandler(token, alice, bob, carol, pair);

        targetContract(address(handler));
    }

    function invariant_KnownBalancesEqualTotalSupply() public view {
        uint256 tracked =
            token.balanceOf(address(this)) +
            token.balanceOf(alice) +
            token.balanceOf(bob) +
            token.balanceOf(carol) +
            token.balanceOf(pair) +
            token.balanceOf(FOUNDER) +
            token.balanceOf(LP_RESERVE) +
            token.balanceOf(DEAD) +
            token.balanceOf(stakingTarget) +
            token.balanceOf(marketingWallet);

        assertEq(tracked, TOTAL_SUPPLY);
    }

    function invariant_CirculatingSupplyMatchesDeadBalance() public view {
        assertEq(token.circulatingSupply(), TOTAL_SUPPLY - token.balanceOf(DEAD));
    }

    function invariant_BurnFloorFlagMatchesSupplyMath() public view {
        bool expected = (TOTAL_SUPPLY - token.balanceOf(DEAD)) <= MIN_SUPPLY;
        assertEq(token.burnFloorReached(), expected);
    }

    function invariant_TotalSupplyConstant() public view {
        assertEq(token.totalSupply(), TOTAL_SUPPLY);
    }

    function invariant_TradingRemainsEnabled() public view {
        assertTrue(token.isTradingEnabled());
    }
}

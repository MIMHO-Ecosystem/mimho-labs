// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/token.sol";

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

    function set(bytes32 key, address a) external {
        addrs[key] = a;
    }

    function getContract(bytes32 key) external view returns (address) {
        return addrs[key];
    }
}

contract MIMHOTokenAlphaTest is Test {
    MIMHO token;
    MockRegistry registry;
    MockEventsHub hub;

    address owner = address(0xA11CE);
    address ammPair = address(0xBEEF);        // simula par AMM
    address user = address(0xCAFE);           // buyer/seller
    address marketing = address(0xD00D);      // marketing wallet via registry
    address stakingTarget = address(0x515A);  // staking contract via registry

    // Legacy keys used by token
    bytes32 constant KEY_EVENTS_HUB       = keccak256("MIMHO_EVENTS_HUB");
    bytes32 constant KEY_STAKING          = keccak256("STAKING_CONTRACT");
    bytes32 constant KEY_MARKETING_WALLET = keccak256("MARKETING_WALLET");

    function setUp() public {
        vm.startPrank(owner);

        token = new MIMHO();

        registry = new MockRegistry();
        hub = new MockEventsHub();

        // Wire registry + hub
        registry.set(KEY_EVENTS_HUB, address(hub));
        registry.set(KEY_MARKETING_WALLET, marketing);
        registry.set(KEY_STAKING, stakingTarget);

        token.setRegistry(address(registry));

        // Enable trading + set AMM pair
        token.enableTrading();
        token.setAMMPair(ammPair, true);

        // Seed balances
        // owner already has TOTAL_SUPPLY from constructor
        token.transfer(user, 10_000_000 * 1e18);

        vm.stopPrank();
    }

    function test_TradingDisabledBlocksNonOwnerTransfer() public {
        // deploy fresh without enabling trading
        vm.startPrank(owner);
        MIMHO t2 = new MIMHO();
        // owner can transfer even if trading disabled
        t2.transfer(user, 1_000 * 1e18);
        vm.stopPrank();

        // user cannot transfer while trading disabled (unless to/from owner)
        vm.startPrank(user);
        vm.expectRevert(bytes("MIMHO: Trading disabled"));
        t2.transfer(address(0x1234), 1 * 1e18);
        vm.stopPrank();
    }

    function test_BuyFeeFounderOnly() public {
        // BUY = AMM -> user (from is AMM)
        // We simulate by giving AMM tokens then calling transfer from AMM
        vm.startPrank(owner);
        token.transfer(ammPair, 1_000_000 * 1e18);
        vm.stopPrank();

        uint256 amount = 100_000 * 1e18;

        uint256 founderBefore = token.balanceOf(token.founderWallet());
        uint256 userBefore = token.balanceOf(user);

        vm.prank(ammPair);
        token.transfer(user, amount);

        // buy founder fee = 1%
        uint256 expectedFounderFee = (amount * token.BUY_FOUNDER_BP()) / token.BP_DIVISOR();
        uint256 expectedNet = amount - expectedFounderFee;

        assertEq(token.balanceOf(token.founderWallet()), founderBefore + expectedFounderFee);
        assertEq(token.balanceOf(user), userBefore + expectedNet);
    }

    function test_SellFees_Distributed() public {
        // SELL = user -> AMM (to is AMM)
        uint256 amount = 100_000 * 1e18;

        uint256 founderBefore = token.balanceOf(token.founderWallet());
        uint256 lpBefore = token.balanceOf(token.LIQUIDITY_RESERVE_WALLET());
        uint256 stakeBefore = token.balanceOf(stakingTarget);

        vm.prank(user);
        token.transfer(ammPair, amount);

        uint256 founderFee = (amount * token.SELL_FOUNDER_BP()) / token.BP_DIVISOR();
        uint256 lpFee      = (amount * token.SELL_LP_BP()) / token.BP_DIVISOR();
        uint256 burnFee    = (amount * token.SELL_BURN_BP()) / token.BP_DIVISOR();
        uint256 stakeFee   = (amount * token.SELL_STAKE_BP()) / token.BP_DIVISOR();

        uint256 totalFee = founderFee + lpFee + burnFee + stakeFee;
        uint256 net = amount - totalFee;

        assertEq(token.balanceOf(token.founderWallet()), founderBefore + founderFee);
        assertEq(token.balanceOf(token.LIQUIDITY_RESERVE_WALLET()), lpBefore + lpFee);
        assertEq(token.balanceOf(stakingTarget), stakeBefore + stakeFee);

        // burn goes to DEAD unless floor reached (we assume not reached here)
        assertEq(token.balanceOf(token.DEAD()), burnFee);

        // AMM received net
        assertEq(token.balanceOf(ammPair), net);
    }

    function test_FeeExempt_NoFeesOnBuySell() public {
        vm.startPrank(owner);
        token.setFeeExempt(user, true);
        token.transfer(ammPair, 1_000_000 * 1e18);
        vm.stopPrank();

        uint256 amount = 100_000 * 1e18;

        uint256 founderBefore = token.balanceOf(token.founderWallet());
        uint256 userBefore = token.balanceOf(user);

        // buy: amm -> user
        vm.prank(ammPair);
        token.transfer(user, amount);

        assertEq(token.balanceOf(token.founderWallet()), founderBefore);
        assertEq(token.balanceOf(user), userBefore + amount);
    }

    function test_MaxBuyGuard_First20Minutes() public {
        // Give AMM a lot
        vm.startPrank(owner);
        token.transfer(ammPair, 2_000_000_000 * 1e18);
        vm.stopPrank();

        // During max-buy window, amount > MAX_BUY_AMOUNT should revert
        uint256 tooMuch = token.MAX_BUY_AMOUNT() + 1;

        vm.prank(ammPair);
        vm.expectRevert(bytes("MIMHO: MaxBuy first 20m"));
        token.transfer(user, tooMuch);
    }

    function test_BurnRedirectToMarketing_WhenFloorReached() public {
        // Force floor reached by burning enough to DEAD (send from owner to DEAD)
        // Bring circulating down to MIN_SUPPLY or below:
        // burn = TOTAL - MIN => burn 500B tokens
        vm.startPrank(owner);
        token.transfer(token.DEAD(), 500_000_000_000 * 1e18);
        vm.stopPrank();

        assertTrue(token.burnFloorReached());

        // Now sell should redirect burnFee to marketing (requires registry ready)
        uint256 amount = 100_000 * 1e18;

        uint256 marketingBefore = token.balanceOf(marketing);

        vm.prank(user);
        token.transfer(ammPair, amount);

        uint256 burnFee = (amount * token.SELL_BURN_BP()) / token.BP_DIVISOR();
        assertEq(token.balanceOf(marketing), marketingBefore + burnFee);
    }
}

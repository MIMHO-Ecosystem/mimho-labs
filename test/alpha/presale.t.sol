// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {MIMHOPresale} from "src/presale.sol";

/* ============================================================
   Mocks
   ============================================================ */

contract MockToken {
    string public constant name = "Mock";
    string public constant symbol = "MOCK";
    uint8 public constant decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
        emit Transfer(address(0), to, amt);
    }

    function approve(address s, uint256 a) external returns (bool) {
        allowance[msg.sender][s] = a;
        emit Approval(msg.sender, s, a);
        return true;
    }

    function transfer(address to, uint256 a) external returns (bool) {
        require(balanceOf[msg.sender] >= a, "BAL");
        balanceOf[msg.sender] -= a;
        balanceOf[to] += a;
        emit Transfer(msg.sender, to, a);
        return true;
    }

    function transferFrom(address f, address t, uint256 a) external returns (bool) {
        uint256 alw = allowance[f][msg.sender];
        require(alw >= a, "ALW");
        require(balanceOf[f] >= a, "BAL");
        allowance[f][msg.sender] = alw - a;
        balanceOf[f] -= a;
        balanceOf[t] += a;
        emit Transfer(f, t, a);
        return true;
    }
}

contract MockHub {
    event HubEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes data);
    function emitEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes calldata data) external {
        emit HubEvent(module, action, caller, value, data);
    }
}

contract MockVesting {
    struct Pos {
        address beneficiary;
        uint256 total;
        uint16 tgeBps;
        uint16 weeklyBps;
        uint64 startTs;
        uint256 calls;
    }

    mapping(address => Pos) public pos;

    function registerPresaleVesting(
        address beneficiary,
        uint256 totalPurchasedTokens,
        uint16 tgeBps,
        uint16 weeklyBps,
        uint64 startTimestamp
    ) external {
        Pos storage p = pos[beneficiary];
        p.beneficiary = beneficiary;
        p.total = totalPurchasedTokens;
        p.tgeBps = tgeBps;
        p.weeklyBps = weeklyBps;
        p.startTs = startTimestamp;
        p.calls += 1;
    }
}

contract MockLB {
    uint256 public received;
    bool public shouldRevert;

    function setRevert(bool v) external { shouldRevert = v; }

    function receivePresaleBNB() external payable {
        if (shouldRevert) revert("LB_REVERT");
        received += msg.value;
    }
}

contract MockRegistry {
    mapping(bytes32 => address) public addr;

    // Keys
    bytes32 public constant K_EVENTS = keccak256("K_EVENTS");
    bytes32 public constant K_TOKEN  = keccak256("K_TOKEN");
    bytes32 public constant K_VEST   = keccak256("K_VEST");
    bytes32 public constant K_LB     = keccak256("K_LB");

    function set(bytes32 k, address a) external { addr[k] = a; }

    function getContract(bytes32 key) external view returns (address) { return addr[key]; }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return K_EVENTS; }
    function KEY_MIMHO_TOKEN() external pure returns (bytes32) { return K_TOKEN; }
    function KEY_MIMHO_VESTING() external pure returns (bytes32) { return K_VEST; }
    function KEY_MIMHO_LIQUIDITY_BOOTSTRAPER() external pure returns (bytes32) { return K_LB; }
}

/* ============================================================
   Tests
   ============================================================ */

contract PresaleAlphaTest is Test {
    MockToken token;
    MockRegistry reg;
    MockHub hub;
    MockVesting vest;
    MockLB lb;

    MIMHOPresale presale;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    // Constants from contract
    address constant FOUNDER_SAFE = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address constant DEAD_BURN    = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        token = new MockToken();
        reg = new MockRegistry();
        hub = new MockHub();
        vest = new MockVesting();
        lb = new MockLB();

        reg.set(reg.K_EVENTS(), address(hub));
        reg.set(reg.K_TOKEN(), address(token));
        reg.set(reg.K_VEST(), address(vest));
        reg.set(reg.K_LB(), address(lb));

        presale = new MIMHOPresale(address(reg));

        // deposit exact tokensForSale into presale
        token.mint(address(presale), presale.requiredTokenDeposit());
    }

    function _warpIntoSale() internal {
        // Contract constants:
        // start 1775506800, end 1776716400
        vm.warp(1775506800 + 1);
    }

    function test_QuoteAndPriceNonZero() public {
        uint256 out = presale.quoteTokens(1 ether);
        assertGt(out, 0);

        uint256 p = presale.presalePriceWeiPerToken();
        assertGt(p, 0);
    }

    function test_Buy_Splits_InstantAndVested() public {
        _warpIntoSale();

        uint256 bnbIn = 1 ether;
        uint256 tokensTotal = presale.quoteTokens(bnbIn);
        uint256 instant = (tokensTotal * 2000) / 10_000;
        uint256 vested = tokensTotal - instant;

        vm.deal(alice, bnbIn);

        vm.prank(alice);
        presale.buy{value: bnbIn}();

        // instant transferred to buyer
        assertEq(token.balanceOf(alice), instant);

        // vested sent to vesting contract
        assertEq(token.balanceOf(address(vest)), vested);

        // vesting registered (totalPurchasedTokens == tokensTotal)
        (address ben, uint256 total, uint16 tgeBps, uint16 weeklyBps, uint64 startTs, uint256 calls) =
            vest.pos(alice);
        assertEq(ben, alice);
        assertEq(total, tokensTotal);
        assertEq(tgeBps, 2000);
        assertEq(weeklyBps, 500);
        assertGt(uint256(startTs), 0);
        assertEq(calls, 1);
    }

    function test_Buy_RespectsMinMaxAndHardCap() public {
        _warpIntoSale();

        // below min
        vm.deal(alice, 0.049 ether);
        vm.prank(alice);
        vm.expectRevert();
        presale.buy{value: 0.049 ether}();

        // above max (single tx)
        vm.deal(alice, 6 ether);
        vm.prank(alice);
        vm.expectRevert();
        presale.buy{value: 6 ether}();

        // cumulative max
        vm.deal(alice, 6 ether);

        vm.prank(alice);
        presale.buy{value: 3 ether}();

        // confirm spent so far
        assertEq(presale.spentWei(alice), 3 ether);

        vm.prank(alice);
        vm.expectRevert(bytes("ABOVE_MAX_WALLET"));
        presale.buy{value: 2.1 ether}();
        }

    function test_Finalize_BurnsUnsold() public {
        _warpIntoSale();

        // buy a small amount
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        presale.buy{value: 1 ether}();

        // warp to after end
        vm.warp(1776716400 + 1);

        uint256 deadBefore = token.balanceOf(DEAD_BURN);

        presale.finalize();

        // unsold burned to DEAD
        uint256 deadAfter = token.balanceOf(DEAD_BURN);
        assertGt(deadAfter, deadBefore);
    }

    function test_PushFunds_SuccessPath_SendsToFounderAndLB() public {
        _warpIntoSale();

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        presale.buy{value: 1 ether}();

        vm.warp(1776716400 + 1);
        presale.finalize();

        uint256 founderBefore = FOUNDER_SAFE.balance;
        uint256 lbBefore = lb.received();

        presale.pushFunds();

        assertGt(FOUNDER_SAFE.balance, founderBefore);
        assertGt(lb.received(), lbBefore);
    }

    function test_PushFunds_LBReverts_GoesPendingForLB() public {
        _warpIntoSale();

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        presale.buy{value: 1 ether}();

        vm.warp(1776716400 + 1);
        presale.finalize();

        lb.setRevert(true);

        presale.pushFunds();

        // pending should be set for LB address
        uint256 pend = presale.pendingNative(address(lb));
        assertGt(pend, 0);
    }

    function test_ReceiveOutsideSale_BlocksRandomSender() public {
        // outside sale (default block.timestamp == 1)
        vm.deal(bob, 1 ether);
        vm.prank(bob);
        (bool ok, ) = address(presale).call{value: 0.1 ether}("");
        assertFalse(ok);
    }
}

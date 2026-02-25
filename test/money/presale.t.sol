// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockVesting} from "../mocks/MockVesting.sol";
import {MockLiquidityBootstrapper} from "../mocks/MockLiquidityBootstrapper.sol";
import {MockRegistryPresale} from "../mocks/MockRegistryPresale.sol";

import {MIMHOPresale} from "../../src/presale.sol";

contract PresaleTest is Test {
    MockERC20 token;
    MockVesting vesting;
    MockLiquidityBootstrapper lb;
    MockRegistryPresale reg;
    MIMHOPresale presale;

    address alice = address(0xA11CE);

    // mesmos endereços do contrato
    address constant FOUNDER_SAFE = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address constant DEAD_BURN    = 0x000000000000000000000000000000000000dEaD;

    function setUp() public {
        token = new MockERC20();
        vesting = new MockVesting();
        lb = new MockLiquidityBootstrapper();
        reg = new MockRegistryPresale();

        // registry wiring
        reg.set(reg.KEY_MIMHO_TOKEN(), address(token));
        reg.set(reg.KEY_MIMHO_VESTING(), address(vesting));
        reg.set(reg.KEY_MIMHO_LIQUIDITY_BOOTSTRAPER(), address(lb));
        // EventsHub deixamos 0 por simplicidade (best-effort)

        presale = new MIMHOPresale(address(reg));

        // deposita a alocação inteira no Presale (100B)
        token.mint(address(presale), presale.requiredTokenDeposit());

        // dá BNB pra alice comprar
        vm.deal(alice, 100 ether);
    }

    function _warpToSaleActive() internal {
        // SALE_START = 1775506800 no contrato
        vm.warp(presale.SALE_START() + 1);
    }

    function test_Buy_Sends20PercentInstant_AndRegistersVesting() public {
        _warpToSaleActive();

        uint256 bnbIn = 1 ether;
        uint256 tokensTotal = presale.quoteTokens(bnbIn);
        uint256 tokensInstant = (tokensTotal * presale.TGE_BPS()) / 10_000;
        uint256 tokensVested = tokensTotal - tokensInstant;

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 vestBefore = token.balanceOf(address(vesting));

        vm.prank(alice);
        presale.buy{value: bnbIn}();

        assertEq(token.balanceOf(alice), aliceBefore + tokensInstant, "instant mismatch");
        assertEq(token.balanceOf(address(vesting)), vestBefore + tokensVested, "vesting token mismatch");

        // vesting call recorded
        assertEq(vesting.lastBeneficiary(), alice, "vesting beneficiary");
        assertEq(vesting.lastTotalPurchasedTokens(), tokensTotal, "vesting totalPurchased");
        assertEq(vesting.lastTgeBps(), presale.TGE_BPS(), "vesting tgeBps");
        assertEq(vesting.lastWeeklyBps(), presale.WEEKLY_BPS(), "vesting weeklyBps");
        assertEq(vesting.calls(), 1, "vesting calls");
    }

    function test_Finalize_BurnsUnsold() public {
        _warpToSaleActive();

        // 1 buy
        vm.prank(alice);
        presale.buy{value: 1 ether}();

        // encerra por tempo
        vm.warp(presale.SALE_END() + 1);
        presale.finalize();

        assertTrue(presale.finalized(), "not finalized");

        uint256 sold = presale.totalSoldTokens();
        uint256 unsold = presale.TOKENS_FOR_SALE() - sold;

        // unsold vai pro dead burn
        assertEq(token.balanceOf(DEAD_BURN), unsold, "unsold burn mismatch");
    }

    function test_PushFunds_AutoOrFallbackClaim_WorksForFounderAndLB() public {
        _warpToSaleActive();

        // compra pra ter BNB no contrato
        vm.prank(alice);
        presale.buy{value: 1 ether}();

        // finaliza por tempo
        vm.warp(presale.SALE_END() + 1);
        presale.finalize();

        uint256 totalRaised = presale.totalRaisedWei();
        uint256 founderAmt = (totalRaised * presale.FOUNDER_BPS()) / 10_000;
        uint256 lbAmt = totalRaised - founderAmt;

        uint256 founderBalBefore = FOUNDER_SAFE.balance;
        uint256 lbReceivedBefore = lb.receivedBNB();

        // executa
        presale.pushFunds();

        // --- FOUNDER: ou recebeu direto, ou ficou pendente e ele dá claim ---
        uint256 founderPending = presale.pendingNative(FOUNDER_SAFE);
        if (founderPending > 0) {
            assertEq(founderPending, founderAmt, "founder pending amount");
            vm.prank(FOUNDER_SAFE);
            presale.claimPendingNative();
            assertEq(FOUNDER_SAFE.balance, founderBalBefore + founderAmt, "founder claim mismatch");
        } else {
            assertEq(FOUNDER_SAFE.balance, founderBalBefore + founderAmt, "founder direct mismatch");
        }

        // --- LB: ou recebeu via receivePresaleBNB, ou ficou pendente e LB dá claim (entra no receive()) ---
        uint256 lbPending = presale.pendingNative(address(lb));
        if (lbPending > 0) {
            assertEq(lbPending, lbAmt, "lb pending amount");
            vm.prank(address(lb));
            presale.claimPendingNative();
            assertEq(lb.receivedBNB(), lbReceivedBefore + lbAmt, "lb claim mismatch");
        } else {
            assertEq(lb.receivedBNB(), lbReceivedBefore + lbAmt, "lb direct mismatch");
        }
    }

    function test_PushFunds_FallbackWhenLBReverts_ThenClaimWorks() public {
        _warpToSaleActive();

        // compra
        vm.prank(alice);
        presale.buy{value: 5 ether}();

        // finaliza
        vm.warp(presale.SALE_END() + 1);
        presale.finalize();

        // força LB a reverter no receivePresaleBNB()
        lb.setRevertReceivePresale(true);

        uint256 totalRaised = presale.totalRaisedWei();
        uint256 founderAmt = (totalRaised * presale.FOUNDER_BPS()) / 10_000;
        uint256 lbAmt = totalRaised - founderAmt;

        presale.pushFunds();

        // founder pode ter ido direto ou pendente
        uint256 founderPending = presale.pendingNative(FOUNDER_SAFE);
        if (founderPending > 0) {
            assertEq(founderPending, founderAmt, "founder pending");
        }

        // LB deve cair em pending quando revert
        uint256 lbPending = presale.pendingNative(address(lb));
        assertEq(lbPending, lbAmt, "lb must be pending");

        // LB faz claim e recebe via receive()
        uint256 lbBefore = lb.receivedBNB();
        vm.prank(address(lb));
        presale.claimPendingNative();
        assertEq(lb.receivedBNB(), lbBefore + lbAmt, "lb claim after revert mismatch");
    }
}

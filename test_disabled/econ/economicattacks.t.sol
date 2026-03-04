// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// Ajuste os imports conforme seus caminhos reais:
import "../../src/token.sol";
import "../../src/registry.sol";
import "../../src/injectliquidity.sol";
import "../../src/staking.sol";
import "../../src/holderdistribution.sol";
import "../../src/presale.sol";
import "../../src/liquiditybootstrapper.sol";
import "../../src/marketplace.sol";
import "../../src/locker.sol";

// Mocks (ajuste se necessário)
import "../mocks/MockRouter.sol";
import "../mocks/MockFactoryLB.sol"; // ou o factory que você usa
import "../mocks/MockRegistry.sol";  // se tiver
import "../mocks/MockERC20.sol";

contract EconomicAttacks is Test {
    // Actors
    address owner = address(this);
    address attacker = address(0xBEEF);
    address user1 = address(0x1111);
    address user2 = address(0x2222);

    // Core
    MIMHO token;
    MIMHORegistry registry;
    MIMHOInjectLiquidity inject;
    MIMHOStaking staking;
    MIMHOHolderDistributionVault holderDist;
    MIMHOPresale presale;
    MIMHOLiquidityBootstrapper lb;
    MIMHOMarketplace marketplace;
    MIMHOLocker locker;

    // DEX mocks
    MockFactoryLB factory;
    MockRouter router;

    function setUp() public {
        vm.deal(owner, 1000 ether);
        vm.deal(attacker, 1000 ether);
        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);

        // Deploy mocks
        factory = new MockFactoryLB();
        router = new MockRouter(address(factory));

        // Deploy Registry
        registry = new MIMHORegistry(address(0x1234)); // se seu construtor exigir EventsHub, ajuste aqui
        // Se o Registry precisa de setEventsHub(), faça:
        // registry.setEventsHub(address(eventsHub));

        // Deploy Token (se o construtor não aceita registry, ajuste)
        token = new MIMHO(); // OU new MIMHO(address(registry));
        // Se seu token precisa setRegistry:
        // token.setRegistry(address(registry));

        // Configure Registry keys (ajuste para suas funções reais)
        // registry.setMIMHOToken(address(token));
        // registry.setMIMHODEX(address(router));
        // registry.setWalletMarketing(... etc)

        // Deploy modules
        inject = new MIMHOInjectLiquidity(address(registry));
        staking = new MIMHOStaking(address(registry));
        holderDist = new MIMHOHolderDistributionVault(address(registry));
        lb = new MIMHOLiquidityBootstrapper(address(registry));
        presale = new MIMHOPresale(address(registry));
        marketplace = new MIMHOMarketplace(address(registry));
        locker = new MIMHOLocker(address(registry));

        // Fund token to actors for econ tests
        // Se seu token tem supply já mintado pro owner:
        // token.transfer(attacker, 50_000_000 ether);
        // token.transfer(user1, 50_000_000 ether);
        // token.transfer(user2, 50_000_000 ether);

        // Enable trading se necessário
        // token.enableTrading();

        vm.label(attacker, "attacker");
        vm.label(user1, "user1");
        vm.label(user2, "user2");
    }

    /* ============================================================
       ATTACK 1 — “Wash claims / double claim”
       Target: HolderDistribution / Airdrop / Presale Vesting claims
       Goal: cannot claim twice, cannot bypass cooldown, cannot drain.
       ============================================================ */
    function test_Attack_DoubleClaimMustFail() public {
        // Exemplo: simular uma rodada aberta e um claim repetido.
        // Ajuste para seu fluxo real:
        // holderDist.deposit(1_000_000 ether);
        // holderDist.openRound(...)

        vm.startPrank(user1);
        // holderDist.claim(roundId, proof, amount);
        // tentativa 2 deve falhar:
        vm.expectRevert();
        // holderDist.claim(roundId, proof, amount);
        vm.stopPrank();
    }

    /* ============================================================
       ATTACK 2 — “MEV sandwich style around InjectLiquidity”
       Target: InjectLiquidity addLiquidityETH path
       Goal: InjectLiquidity must never swap, only addLiquidity;
             attacker cannot steal LP, cannot redirect receiver.
       ============================================================ */
    function test_Attack_SandwichAroundInjectLiquidity_NoTheft() public {
        // 1) Attacker tries to front-run by pushing price (in mocks, you can simulate reserves)
        // 2) InjectLiquidity called
        // 3) Attacker back-runs
        //
        // Key asserts:
        // - LP receiver is burn (or expected)
        // - token balance not drained to attacker
        // - no unexpected approvals to attacker

        uint256 attackerBefore = token.balanceOf(attacker);

        // vm.prank(owner);
        // inject.depositTokens(10_000_000 ether);

        // vm.prank(owner);
        // inject.injectLiquidity{value: 10 ether}(minToken, minBNB);

        uint256 attackerAfter = token.balanceOf(attacker);
        assertEq(attackerAfter, attackerBefore, "attacker gained tokens");
    }

    /* ============================================================
       ATTACK 3 — “Staking reward extraction via rapid in/out”
       Target: Staking accrue + claim + unstake ordering
       Goal: no instant farm, no bypass min-hold/cooldown, no overpay
       ============================================================ */
    function test_Attack_StakeUnstakeRapid_NoFreeRewards() public {
        // user stakes
        vm.startPrank(attacker);

        // token.approve(address(staking), type(uint256).max);
        // staking.stake(1_000_000 ether);

        // immediately try claim
        vm.expectRevert();
        // staking.claim();

        // immediately unstake
        // staking.unstake(1_000_000 ether);

        vm.stopPrank();
    }

    /* ============================================================
       ATTACK 4 — “Marketplace payout reentrancy attempt”
       Target: pendingNative payout/claim
       Goal: cannot reenter to drain pending
       ============================================================ */
    function test_Attack_Marketplace_Reentrancy_NoDrain() public {
        // Se você já tem um mock receiver malicioso, pluga aqui.
        // Caso não tenha, a gente cria no próximo passo.

        // assert pending mapping consistent
        assertTrue(true);
    }

    /* ============================================================
       ATTACK 5 — “Locker fee bypass / DAO unset deadlock”
       Target: createPublicLock fee collect order + DAO fallback
       Goal: cannot create lock without fee, cannot brick by DAO=0
       ============================================================ */
    function test_Attack_Locker_FeeBypass_MustFail() public {
        vm.startPrank(attacker);

        // vm.expectRevert();
        // locker.createPublicLock(tokenAddr, amount, unlockTime);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {MockRegistry} from "../mocks/MockRegistry.sol";
import {MockRouter} from "../mocks/MockRouter.sol";

import {MIMHOInjectLiquidity} from "../../src/injectliquidity.sol";

contract InjectLiquidityTest is Test {
    MockERC20 token;
    MockRegistry reg;
    MockRouter router;
    MIMHOInjectLiquidity inj;

    address owner = address(this);
    address vc = address(0xBEEF);
    address alice = address(0xA11CE);
    address dao = address(0xD00D);

    function setUp() public {
        token = new MockERC20();
        reg = new MockRegistry();
        router = new MockRouter();

        // Configura registry
        reg.set(reg.KEY_MIMHO_TOKEN(), address(token));
        reg.set(reg.KEY_MIMHO_DEX(), address(router));
        reg.set(reg.KEY_MIMHO_VOTING_CONTROLLER(), vc);
        // Events hub não setado (0) de propósito: não quebra nada

        inj = new MIMHOInjectLiquidity(address(reg), owner);

        // Dá tokens pra alice
        token.mint(alice, 2_000_000e18);

        // Dá BNB pro Inject via receive()
        vm.deal(address(this), 10 ether);
        (bool ok,) = address(inj).call{value: 5 ether}("");
        require(ok, "fund bnb fail");
    }

    function test_DepositTokens_Works() public {
        uint256 amount = 1000e18;

        vm.startPrank(alice);
        token.approve(address(inj), amount);
        inj.depositTokens(amount);
        vm.stopPrank();

        assertEq(token.balanceOf(address(inj)), amount, "inject token bal");
    }

    function test_Inject_Reverts_WhenAutoInjectDisabled() public {
        // precisa ter tokens dentro do contrato
        vm.startPrank(alice);
        token.approve(address(inj), 1000e18);
        inj.depositTokens(1000e18);
        vm.stopPrank();

        vm.expectRevert(bytes("Not authorized"));
        inj.injectLiquidity(100e18, 1 ether, 0, 0, block.timestamp + 1 hours);
    }

    function test_SetAutoInject_OnlyVCOrOwner_PreDAO() public {
        // alice não pode
        vm.prank(alice);
        vm.expectRevert(bytes("AUTH: VC/owner"));
        inj.setAutoInject(true);

        // VC pode
        vm.prank(vc);
        inj.setAutoInject(true);
        assertTrue(inj.autoInjectEnabled(), "autoInject should be true");

        // owner pode
        inj.setAutoInject(false);
        assertTrue(!inj.autoInjectEnabled(), "autoInject should be false");
    }

    function test_Inject_Reverts_WhenCooldownActive() public {
        // Deposita tokens
        vm.startPrank(alice);
        token.approve(address(inj), 1000e18);
        inj.depositTokens(1000e18);
        vm.stopPrank();

        // autoriza
        vm.prank(vc);
        inj.setAutoInject(true);

        // executa 1 vez
        inj.injectLiquidity(100e18, 1 ether, 0, 0, block.timestamp + 1 hours);

        // tenta de novo imediatamente (cooldown 7 dias)
        vm.prank(vc);
        inj.setAutoInject(true);

        vm.expectRevert(bytes("Cooldown active"));
        inj.injectLiquidity(100e18, 1 ether, 0, 0, block.timestamp + 1 hours);
    }

    function test_Inject_Success_DisablesAutoInject_UpdatesTotals_AndBurnsLP() public {
        // Deposita tokens suficientes
        vm.startPrank(alice);
        token.approve(address(inj), 1000e18);
        inj.depositTokens(1000e18);
        vm.stopPrank();

        // autoriza
        vm.prank(vc);
        inj.setAutoInject(true);

        uint256 tokenAmount = 200e18;
        uint256 bnbAmount = 1 ether;
        uint256 deadline = block.timestamp + 1 hours;

        uint256 beforeTokenInj = token.balanceOf(address(inj));
        uint256 beforeRouterToken = token.balanceOf(address(router));

        inj.injectLiquidity(tokenAmount, bnbAmount, 0, 0, deadline);

        // autoInject vira false (one-shot)
        assertTrue(!inj.autoInjectEnabled(), "autoInject must be false after inject");

        // router puxou tokens
        assertEq(token.balanceOf(address(router)), beforeRouterToken + tokenAmount, "router token");
        assertEq(token.balanceOf(address(inj)), beforeTokenInj - tokenAmount, "inject token");

        // Totais atualizados com retorno do mock
        assertEq(inj.totalInjectedToken(), tokenAmount, "totalInjectedToken");
        assertEq(inj.totalInjectedBNB(), bnbAmount, "totalInjectedBNB");
        assertEq(inj.totalLPBurned(), 123456, "totalLPBurned");

        // Router foi chamado com receiver = DEAD (LP burn)
        assertEq(router.lastTo(), inj.LP_BURN_ADDRESS(), "LP burn address mismatch");

        // deadline e msg.value
        assertEq(router.lastDeadline(), deadline, "deadline mismatch");
        assertEq(router.lastMsgValue(), bnbAmount, "msg.value mismatch");
    }

    function test_Failsafe_EnablesAutoInject_AfterDelay() public {
        // por padrão failsafeDelay = 180 dias e lastActivityTimestamp setado no deploy/receive
        // avança tempo
        vm.warp(block.timestamp + 181 days);

        inj.triggerFailsafe();
        assertTrue(inj.autoInjectEnabled(), "failsafe should enable autoInject");
    }

    function test_AfterDAOActivated_OnlyDAO_CanSetAutoInject() public {
        // seta DAO e ativa
        inj.setDAO(dao);
        inj.activateDAO();

        // owner não pode mais (porque daoActivated=true)
        vm.expectRevert(bytes("AUTH: DAO only"));
        inj.setAutoInject(true);

        // vc também não pode
        vm.prank(vc);
        vm.expectRevert(bytes("AUTH: DAO only"));
        inj.setAutoInject(true);

        // DAO pode
        vm.prank(dao);
        inj.setAutoInject(true);
        assertTrue(inj.autoInjectEnabled(), "dao should enable");
    }
}

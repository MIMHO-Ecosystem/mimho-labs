// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {MockRegistryLB} from "../mocks/MockRegistryLB.sol";
import {MockFactoryLB} from "../mocks/MockFactoryLB.sol";
import {MockRouterLB} from "../mocks/MockRouterLB.sol";
import {MockPairERC20} from "../mocks/MockPairERC20.sol";

// use seu MockERC20 existente:
import {MockERC20} from "../mocks/MockERC20.sol";

import {MIMHOLiquidityBootstrapper} from "../../src/liquiditybootstrapper.sol";

contract PresaleReceiver {
uint256 public _presalePriceWeiPerToken;

    constructor(uint256 presalePriceWeiPerToken_) {
        require(presalePriceWeiPerToken_ > 0, "PRICE_0");
        _presalePriceWeiPerToken = presalePriceWeiPerToken_;
    }

    function presalePriceWeiPerToken() external view returns (uint256) {
        return _presalePriceWeiPerToken;
    }
    receive() external payable {}
}

contract LiquidityBootstrapperTest is Test {
    MockERC20 token;
    MockRegistryLB reg;
    MockFactoryLB factory;
    MockRouterLB router;
    PresaleReceiver presale;

    MIMHOLiquidityBootstrapper boot;

    address inject = address(0xBEEF);
    address lpBurn = 0x000000000000000000000000000000000000dEaD;
    address weth = address(0xBEEF);

    uint256 presalePriceWeiPerToken; // será lido do presale (fonte única)

    function setUp() public {
        token = new MockERC20();
        reg = new MockRegistryLB();
        factory = new MockFactoryLB();
        router = new MockRouterLB(weth, address(factory));
        uint256 presalePriceWeiPerToken = 1e16; // 0.01 BNB por token (wei por token)
        presale = new PresaleReceiver(presalePriceWeiPerToken);
        presalePriceWeiPerToken = presale.presalePriceWeiPerToken();


        // registry inject set
        reg.set(reg.KEY_MIMHO_INJECT_LIQUIDITY(), inject);
        // events hub fica 0 (não quebra nada)

        boot = new MIMHOLiquidityBootstrapper(
            address(reg),
            address(token),
            address(router),
            address(presale),
            lpBurn,
            presalePriceWeiPerToken
        );

        // cria o pair no factory (pra router conseguir mintar LP)
        factory.createPair(address(token), weth);

        // precisa ter MIMHO suficiente no boot pra mimhoForLiquidity
        // vamos mandar uma folga
        token.mint(address(boot), 10_000e18);

        // dá BNB pro "presale"
        vm.deal(address(presale), 10 ether);
    }

    function test_OnlyPresaleCanCall() public {
        vm.expectRevert(bytes("ONLY_PRESALE"));
        boot.receivePresaleBNB{value: 1 ether}();
    }

    function test_PauseBlocks() public {
        boot.pauseEmergencial();

        vm.prank(address(presale));
        vm.expectRevert(); // "Pausable: paused"
        boot.receivePresaleBNB{value: 1 ether}();
    }

    function test_OneShot_Executed() public {
        vm.prank(address(presale));
        boot.receivePresaleBNB{value: 10 ether}();

        assertTrue(boot.executed(), "executed should be true");

        vm.prank(address(presale));
        vm.expectRevert(bytes("ALREADY_EXECUTED"));
        boot.receivePresaleBNB{value: 1 ether}();
    }

    function test_Bootstrap_CreatesPair_BurnsLP_RefundsAndForwardsExcess() public {
        uint256 presaleBalBefore = address(presale).balance;
        assertEq(presaleBalBefore, 10 ether, "presale start bal");

        address pair = factory.pair();
        assertTrue(pair != address(0), "pair must exist");

        uint256 burnLPBefore = MockPairERC20(pair).balanceOf(lpBurn);

        vm.prank(address(presale));
        boot.receivePresaleBNB{value: 10 ether}();

        // pair recorded
        assertEq(boot.currentPair(), pair, "pair mismatch");

        // LP minted to boot and burned to lpBurn
        uint256 burnLPAfter = MockPairERC20(pair).balanceOf(lpBurn);
        assertEq(burnLPAfter - burnLPBefore, router.LP_MINTED(), "lp burned mismatch");

        // router call receiver was address(this) (boot), conforme seu contrato
        assertEq(router.lastTo(), address(boot), "router.to should be boot");
        assertEq(router.lastMsgValue(), 9 ether, "bnbForLiquidity should be 90%");

        // refund de BNB: 10 ether - 9 ether = 1 ether volta pro presale
        uint256 presaleBalAfter = address(presale).balance;
        assertEq(presaleBalAfter, 1 ether, "refund mismatch");

        // excess MIMHO forwarded to inject (no nosso mock, router não consome tokens, então vai tudo)
        assertEq(token.balanceOf(inject), 10_000e18, "inject should receive excess");
        assertEq(token.balanceOf(address(boot)), 0, "boot should end with 0 mimho");
    }
}

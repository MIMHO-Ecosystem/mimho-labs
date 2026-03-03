// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOLiquidityBootstrapper} from "src/liquiditybootstrapper.sol";

/*//////////////////////////////////////////////////////////////
                        Mocks
//////////////////////////////////////////////////////////////*/

contract MockEventsHub {
    function emitEvent(bytes32, bytes32, address, uint256, bytes calldata) external {}
}

contract MockRegistry {
    address public hub;
    address public inject;

    bytes32 public constant _KEY_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant _KEY_INJECT = keccak256("MIMHO_INJECT_LIQUIDITY");

    constructor(address hub_, address inject_) {
        hub = hub_;
        inject = inject_;
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return _KEY_HUB; }
    function KEY_MIMHO_INJECT_LIQUIDITY() external pure returns (bytes32) { return _KEY_INJECT; }

    function getContract(bytes32 key) external view returns (address) {
        if (key == _KEY_HUB) return hub;
        if (key == _KEY_INJECT) return inject;
        return address(0);
    }

    function isEcosystemContract(address) external pure returns (bool) { return false; }
}

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8  public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amt, "ALLOW");
        require(balanceOf[from] >= amt, "BAL");
        allowance[from][msg.sender] = a - amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockLPToken {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "LP_BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

contract MockFactory {
    address public lastPair;
    address public tokenA;
    address public tokenB;

    function getPair(address a, address b) external view returns (address pair) {
        // if created, return it; else 0
        if (lastPair == address(0)) return address(0);
        // ignore ordering for test
        if ((a == tokenA && b == tokenB) || (a == tokenB && b == tokenA)) return lastPair;
        return address(0);
    }

    function createPair(address a, address b) external returns (address pair) {
        tokenA = a;
        tokenB = b;
        MockLPToken lp = new MockLPToken();
        lastPair = address(lp);
        return lastPair;
    }
}

contract MockRouter {
    address public factoryAddr;
    address public weth;

    constructor(address factory_, address weth_) {
        factoryAddr = factory_;
        weth = weth_;
    }

    function factory() external view returns (address) { return factoryAddr; }
    function WETH() external view returns (address) { return weth; }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256,
        uint256,
        address to,
        uint256
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        // take tokens from caller (bootstrapper)
        require(MockERC20(token).transferFrom(msg.sender, address(this), amountTokenDesired), "TF");

        amountToken = amountTokenDesired;
        amountETH = msg.value;

        // mint LP to `to` (bootstrapper)
        address pair = MockFactory(factoryAddr).lastPair();
        require(pair != address(0), "NO_PAIR");
        liquidity = 12345e18;
        MockLPToken(pair).mint(to, liquidity);
    }
}

contract MockPresale {
    // MUST match bootstrapper check: IMIMHOPresale(presale).presalePriceWeiPerToken()
    function presalePriceWeiPerToken() external pure returns (uint256) {
        return 1e12; // arbitrary constant used in test
    }

    receive() external payable {}

    function callReceivePresaleBNB(address bootstrapper) external payable {
        MIMHOLiquidityBootstrapper(payable(bootstrapper)).receivePresaleBNB{value: msg.value}();
    }
}

contract DummyInject {}

/*//////////////////////////////////////////////////////////////
                        Tests
//////////////////////////////////////////////////////////////*/
contract LiquidityBootstrapperAlphaTest is Test {
    MIMHOLiquidityBootstrapper boot;

    MockEventsHub hub;
    DummyInject inject;
    MockRegistry reg;

    MockERC20 mimho;
    MockFactory factory;
    MockRouter router;
    MockPresale presale;

    address lpBurn = address(0x000000000000000000000000000000000000dEaD);
    address weth = address(0xBEEF);

    function setUp() public {
        hub = new MockEventsHub();
        inject = new DummyInject();
        reg = new MockRegistry(address(hub), address(inject));

        mimho = new MockERC20();
        factory = new MockFactory();
        router = new MockRouter(address(factory), weth);
        presale = new MockPresale();

        // create pair upfront (bootstrapper also can create, but we ensure router can mint LP)
        factory.createPair(address(mimho), weth);

        // deploy bootstrapper
        boot = new MIMHOLiquidityBootstrapper(
            address(reg),
            address(mimho),
            address(router),
            address(presale),
            lpBurn,
            1e12 // must equal presale.presalePriceWeiPerToken()
        );

        // fund bootstrapper with enough MIMHO for liquidity
        // We will send 1 ether BNB => liquidity 0.9 ether
        // presalePrice=1e12, launchPrice=1.1e12, tokens = (0.9e18*1e18)/1.1e12 ≈ 8.18e23, so mint big
        mimho.mint(address(boot), 2_000_000_000_000_000_000_000_000_000_000_000); // 2e30

        // approve router from bootstrapper: bootstrapper does approve(router, mimhoForLiquidity) internally,
        // but router uses transferFrom(boot,...). So token must allow boot->router via approve inside boot (ok).
        // nothing else needed.
    }

    function test_Deploy_Works() public {
        assertEq(boot.executed(), false);
        assertEq(boot.presaleContract(), address(presale));
        assertEq(address(boot.mimho()), address(mimho));
    }

    function test_OnlyPresaleCanCall() public {
        vm.deal(address(this), 1 ether);
        vm.expectRevert("ONLY_PRESALE");
        boot.receivePresaleBNB{value: 1 ether}();
    }

    function test_ReceivePresaleBNB_Executes_Once() public {
        vm.deal(address(presale), 2 ether);

        // call from presale contract
        vm.prank(address(presale));
        presale.callReceivePresaleBNB{value: 1 ether}(address(boot));

        assertTrue(boot.executed());
        assertTrue(boot.currentPair() != address(0));

        // second call must revert
        vm.prank(address(presale));
        vm.expectRevert("ALREADY_EXECUTED");
        presale.callReceivePresaleBNB{value: 1 ether}(address(boot));
    }

    function test_LPIsBurned_AndExcessMIMHOForwarded() public {
        vm.deal(address(presale), 1 ether);

        address pair = factory.lastPair();
        uint256 burnBefore = MockLPToken(pair).balanceOf(lpBurn);

        vm.prank(address(presale));
        presale.callReceivePresaleBNB{value: 1 ether}(address(boot));

        // LP burned
        uint256 burnAfter = MockLPToken(pair).balanceOf(lpBurn);
        assertTrue(burnAfter > burnBefore);

        // excess mimho forwarded to inject
        uint256 injectBal = mimho.balanceOf(address(inject));
        assertTrue(injectBal > 0);
    }

    function test_BNBRefundToPresale() public {
        // Send more BNB so there is refund (bootstrap uses 90%, refunds remaining 10%)
        vm.deal(address(presale), 1 ether);

        uint256 presaleBefore = address(presale).balance;

        vm.prank(address(presale));
        presale.callReceivePresaleBNB{value: 1 ether}(address(boot));

        // Presale started with 1 ether and sent 1 ether, so it goes to 0,
        // then gets refund of 0.1 ether => should be > 0
        assertTrue(address(presale).balance > 0);
        assertTrue(address(presale).balance < presaleBefore); // not full refund, only remainder
    }
}

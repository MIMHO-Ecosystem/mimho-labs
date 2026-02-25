// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// Seus contratos reais
import {MIMHOPresale} from "../../src/presale.sol";
import {MIMHOInjectLiquidity} from "../../src/injectliquidity.sol";
import {MIMHOLiquidityBootstrapper} from "../../src/liquiditybootstrapper.sol";

/* ============================================================
   Mocks mínimos p/ integração (sem depender de outros arquivos)
   ============================================================ */

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8  public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed o, address indexed s, uint256 v);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address s, uint256 v) external returns (bool) {
        allowance[msg.sender][s] = v;
        emit Approval(msg.sender, s, v);
        return true;
    }

    function transfer(address to, uint256 v) external returns (bool) {
        require(balanceOf[msg.sender] >= v, "BAL");
        balanceOf[msg.sender] -= v;
        balanceOf[to] += v;
        emit Transfer(msg.sender, to, v);
        return true;
    }

    function transferFrom(address f, address t, uint256 v) external returns (bool) {
        uint256 a = allowance[f][msg.sender];
        require(a >= v, "ALLOW");
        require(balanceOf[f] >= v, "BALF");
        allowance[f][msg.sender] = a - v;
        balanceOf[f] -= v;
        balanceOf[t] += v;
        emit Transfer(f, t, v);
        return true;
    }
}

contract MockVesting {
    struct Last {
        address beneficiary;
        uint256 totalPurchasedTokens;
        uint16 tgeBps;
        uint16 weeklyBps;
        uint64 startTimestamp;
    }
    Last public last;

    function registerPresaleVesting(
        address beneficiary,
        uint256 totalPurchasedTokens,
        uint16 tgeBps,
        uint16 weeklyBps,
        uint64 startTimestamp
    ) external {
        last = Last(beneficiary, totalPurchasedTokens, tgeBps, weeklyBps, startTimestamp);
    }
}

/* Router/Factory/Pair mocks p/ LiquidityBootstrapper */
contract MockPairLP {
    mapping(address => uint256) public balanceOf;
    event Transfer(address indexed f, address indexed t, uint256 v);

    function mint(address to, uint256 v) external {
        balanceOf[to] += v;
        emit Transfer(address(0), to, v);
    }

    function transfer(address to, uint256 v) external returns (bool) {
        require(balanceOf[msg.sender] >= v, "LP_BAL");
        balanceOf[msg.sender] -= v;
        balanceOf[to] += v;
        emit Transfer(msg.sender, to, v);
        return true;
    }
}

contract MockFactory {
    address public pair;
    function getPair(address, address) external view returns (address) { return pair; }
    function createPair(address, address) external returns (address) {
        MockPairLP p = new MockPairLP();
        pair = address(p);
        return pair;
    }
}

contract MockRouter {
    MockFactory public f;
    address public weth;

    // tracking (opcional)
    address public lastToken;
    uint256 public lastAmountTokenDesired;
    uint256 public lastMsgValue;
    address public lastTo;

    constructor(address _weth) {
        f = new MockFactory();
        weth = _weth;
    }

    function factory() external view returns (address) { return address(f); }
    function WETH() external view returns (address) { return weth; }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256,
        uint256,
        address to,
        uint256
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        // OBS: Por causa da interface do seu LB (IERC20 sem transferFrom),
        // este mock NÃO puxa tokens de verdade. Ele só simula o retorno e minta LP.
        lastToken = token;
        lastAmountTokenDesired = amountTokenDesired;
        lastMsgValue = msg.value;
        lastTo = to;

        address pair = f.pair();
        if (pair == address(0)) {
            pair = f.createPair(token, weth);
        }

        // Simula LP mintado p/ "to"
        MockPairLP(pair).mint(to, 123456);

        // Retornos simulados
        return (amountTokenDesired, msg.value, 123456);
    }
}

/* Registry mock completo p/ Presale + LB + Inject */
contract MockRegistryFull {
    mapping(bytes32 => address) public a;

    // keys fixas
    bytes32 public constant K_EVENTS  = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant K_TOKEN   = keccak256("MIMHO_TOKEN");
    bytes32 public constant K_VEST    = keccak256("MIMHO_VESTING");
    bytes32 public constant K_LB      = keccak256("MIMHO_LIQUIDITY_BOOTSTRAPER");
    bytes32 public constant K_INJECT  = keccak256("MIMHO_INJECT_LIQUIDITY");
    bytes32 public constant K_DEX     = keccak256("MIMHO_DEX");
    bytes32 public constant K_VC      = keccak256("MIMHO_VOTING_CONTROLLER");

    function set(bytes32 k, address v) external { a[k] = v; }
    function getContract(bytes32 k) external view returns (address) { return a[k]; }

    // getters obrigatórios (Protocolo)
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32) { return K_EVENTS; }
    function KEY_MIMHO_TOKEN() external view returns (bytes32) { return K_TOKEN; }
    function KEY_MIMHO_VESTING() external view returns (bytes32) { return K_VEST; }
    function KEY_MIMHO_LIQUIDITY_BOOTSTRAPER() external view returns (bytes32) { return K_LB; }
    function KEY_MIMHO_INJECT_LIQUIDITY() external view returns (bytes32) { return K_INJECT; }
    function KEY_MIMHO_DEX() external view returns (bytes32) { return K_DEX; }
    function KEY_MIMHO_VOTING_CONTROLLER() external view returns (bytes32) { return K_VC; }

    function isEcosystemContract(address) external pure returns (bool) { return true; }
}

/* ============================================================
   TESTE DE INTEGRAÇÃO CROSS-FLOW
   ============================================================ */
contract CrossFlowTest is Test {
    MockERC20 token;
    MockVesting vest;
    MockRegistryFull reg;

    MIMHOPresale presale;
    MIMHOInjectLiquidity inj;
    MIMHOLiquidityBootstrapper lb;

    MockRouter router;
    address WETH = address(0xB0B); // qualquer addr não-zero p/ mock
    address owner = address(this);
    address alice = address(0xA11CE);

    function setUp() public {
        token = new MockERC20();
        vest  = new MockVesting();
        reg   = new MockRegistryFull();

        // Registry base
        reg.set(reg.K_TOKEN(), address(token));
        reg.set(reg.K_VEST(), address(vest));
        // EventsHub fica 0 (ok)
        // VC e DEX não são necessários pra este teste

        // Deploy Presale (puxa token do registry no ctor)
        presale = new MIMHOPresale(address(reg));

        // Deploy InjectLiquidity (precisa do registry)
        inj = new MIMHOInjectLiquidity(address(reg), owner);
        reg.set(reg.K_INJECT(), address(inj));

        // Mock router p/ LB
        router = new MockRouter(WETH);

        // Preço presale (wei por token 1e18) derivado do próprio presale
        // priceWeiPerToken = 1e36 / TOKENS_PER_BNB  (porque token tem 18 dec)
        uint256 tpb = presale.TOKENS_PER_BNB();
        uint256 presalePriceWeiPerToken = (1e36) / tpb;

        // Deploy LB (presaleContract = presale)
        lb = new MIMHOLiquidityBootstrapper(
            address(reg),
            address(token),
            address(router),
            address(presale),
            address(0x000000000000000000000000000000000000dEaD), // burn LP
            presalePriceWeiPerToken
        );
        reg.set(reg.K_LB(), address(lb));

        // Deposita tokens na Presale (obrigatório)
        token.mint(address(this), presale.TOKENS_FOR_SALE());
        token.approve(address(presale), presale.TOKENS_FOR_SALE());
        // Presale recebe via transfer
        token.transfer(address(presale), presale.TOKENS_FOR_SALE());

        // LB precisa ter tokens para liquidez (coloca uma “gordura” p/ não faltar)
        token.mint(address(lb), 2_000_000_000e18);

        // Funds p/ alice comprar
        vm.deal(alice, 10 ether);
    }

    function test_CrossFlow_PresaleToLBToInject_Works() public {
        // 1) abre janela da sale
        vm.warp(presale.SALE_START() + 1);

        // 2) alice compra (1 ether respeita MAX 5)
        vm.prank(alice);
        presale.buy{value: 1 ether}();

        // 3) encerra sale pelo tempo
        vm.warp(presale.SALE_END() + 1);

        // 4) finalize (queima unsold)
        presale.finalize();
        // 🔄 garante que Presale puxe LB do Registry
        presale.syncFromRegistry();
        assertTrue(presale.finalized(), "presale not finalized");

        // 5) pushFunds (manda 10% founder + 90% LB)
        // Se teu presale estiver no modo "auto send + fallback pending", aqui ele chama o LB.
        presale.pushFunds();

        // 6) valida LB executou
        assertTrue(lb.isFinalized(), "LB not executed");

        // 7) valida Inject recebeu algum MIMHO (excesso do LB)
        uint256 injBal = token.balanceOf(address(inj));
        assertTrue(injBal > 0, "Inject did not receive excess MIMHO");

        // (Opcional) valida que pair foi criado
        assertTrue(lb.currentPair() != address(0), "pair not created");
    }
}

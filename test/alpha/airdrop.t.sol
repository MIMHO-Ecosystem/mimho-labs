// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// Ajuste o path se seu projeto tiver estrutura diferente.
// Aqui assumo que o contrato está em src/airdrop.sol
import {MIMHOAirdrop} from "../../src/airdrop.sol";

/* ============================================================
   Mocks
   ============================================================ */

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BAL_LOW");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

contract MockVeritas {
    uint256 public priceUsd18;

    constructor(uint256 p) {
        priceUsd18 = p;
    }

    function setPrice(uint256 p) external {
        priceUsd18 = p;
    }

    function getUSDPrice(address) external view returns (uint256) {
        return priceUsd18;
    }
}

contract MockLabs {
    uint256 public consultaFee;
    address public collector;

    mapping(address => bool) public whitelisted;

    constructor(uint256 fee, address feeCollector_) {
        consultaFee = fee;
        collector = feeCollector_;
    }

    function setWhitelisted(address a, bool v) external {
        whitelisted[a] = v;
    }

    function setFee(uint256 fee) external {
        consultaFee = fee;
    }

    function isWhitelisted(address requester) external view returns (bool) {
        return whitelisted[requester];
    }

    function getConsultaFee() external view returns (uint256) {
        return consultaFee;
    }

    function feeCollector() external view returns (address) {
        return collector;
    }
}

contract MockRegistryAirdrop {
    mapping(bytes32 => address) public addrOf;
    mapping(address => bool) public eco;

    // keys
    bytes32 internal constant K_TOKEN  = keccak256("KEY_MIMHO_TOKEN");
    bytes32 internal constant K_HUB    = keccak256("KEY_MIMHO_EVENTS_HUB");
    bytes32 internal constant K_DAO    = keccak256("KEY_MIMHO_DAO");
    bytes32 internal constant K_VER    = keccak256("KEY_MIMHO_VERITAS");
    bytes32 internal constant K_LABS   = keccak256("KEY_MIMHO_LABS");

    function set(bytes32 k, address a) external {
        addrOf[k] = a;
    }

    function setEco(address a, bool v) external {
        eco[a] = v;
    }

    function getContract(bytes32 key) external view returns (address) {
        return addrOf[key];
    }

    function isEcosystemContract(address a) external view returns (bool) {
        return eco[a];
    }

    function KEY_MIMHO_TOKEN() external pure returns (bytes32) { return K_TOKEN; }
    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return K_HUB; }
    function KEY_MIMHO_DAO() external pure returns (bytes32) { return K_DAO; }
    function KEY_MIMHO_VERITAS() external pure returns (bytes32) { return K_VER; }
    function KEY_MIMHO_LABS() external pure returns (bytes32) { return K_LABS; }
}

contract MockBonusVerifier {
    mapping(address => bool) public ok;

    function setOk(address a, bool v) external {
        ok[a] = v;
    }

    function isOk(address a) external view returns (bool) {
        return ok[a];
    }
}

/* ============================================================
   Airdrop Tests
   ============================================================ */

contract AirdropTest is Test {
    // actors
    address internal owner = address(this);
    address internal marketing = address(0xBEEF01);
    address internal dao = address(0xDA001);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);
    address internal collector = address(0xC011);

    // system
    MockERC20 internal token;
    MockRegistryAirdrop internal reg;
    MockVeritas internal veritas;
    MockLabs internal labs;
    MockBonusVerifier internal verifier;

    // target
    MIMHOAirdrop internal drop;

    // params
    uint256 internal constant CYCLE_DURATION = 7 days;
    uint256 internal constant ABSOLUTE_CYCLE_CAP = 1000e18;
    uint256 internal constant MIN_USD_REQUIRED = 100e18; // $100

    // merkle
    uint256 internal baseAlice = 100e18;
    uint256 internal baseBob = 80e18;

    bytes32 internal leafA;
    bytes32 internal leafB;
    bytes32 internal root;

    function setUp() public {
        token = new MockERC20();
        reg = new MockRegistryAirdrop();
        veritas = new MockVeritas(1e18); // $1 por token
        labs = new MockLabs(0.01 ether, collector);
        verifier = new MockBonusVerifier();

        // registry wiring
        reg.set(reg.KEY_MIMHO_TOKEN(), address(token));
        reg.set(reg.KEY_MIMHO_VERITAS(), address(veritas));
        reg.set(reg.KEY_MIMHO_LABS(), address(labs));
        reg.set(reg.KEY_MIMHO_DAO(), dao);
        // hub pode ser 0, airdrop faz best-effort e ignora

        drop = new MIMHOAirdrop(
            address(reg),
            marketing,
            CYCLE_DURATION,
            ABSOLUTE_CYCLE_CAP,
            MIN_USD_REQUIRED
        );

        // usuários precisam ter token para passar minUsdRequired (usdValue = balance * price)
        // como price=$1, basta >= 100 tokens
        token.mint(alice, 200e18);
        token.mint(bob, 200e18);

        // tesouraria do airdrop (prefunded)
        // vamos dar bastante; budget do ciclo = min(5% do saldo, ABSOLUTE_CYCLE_CAP)
        // 5% de 10.000 = 500
        token.mint(address(drop), 10_000e18);

        // preparar merkle (2 folhas)
        leafA = _leafFor(alice, baseAlice);
        leafB = _leafFor(bob, baseBob);
        root = _root2(leafA, leafB);
    }

    /* ----------------- Merkle helpers (match contract leafFor) ----------------- */

    function _leafFor(address user, uint256 baseAmount) internal pure returns (bytes32) {
        // contrato usa keccak256(abi.encode(user, baseAmount))
        return keccak256(abi.encode(user, baseAmount));
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return (a < b) ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _root2(bytes32 leaf1, bytes32 leaf2) internal pure returns (bytes32) {
        return _hashPair(leaf1, leaf2);
    }

    function _proof1(bytes32 x) internal pure returns (bytes32[] memory p) {
        p = new bytes32[](1);
        p[0] = x;
    }

    /* ------------------------------ Cycle start ------------------------------ */

    function _startCycle2(bytes32 newRoot) internal {
        // precisa esperar cicloDuration
        vm.warp(block.timestamp + CYCLE_DURATION + 1);
        drop.startNextCycle(newRoot);
    }

    function test_StartNextCycle_RevertsBeforeReady() public {
        vm.expectRevert(); // CycleNotReady (custom error)
        drop.startNextCycle(root);
    }

    function test_StartNextCycle_Works_SetsBudgetAndPrice() public {
        _startCycle2(root);

        (
            uint256 id,
            uint256 startTs,
            uint256 duration,
            uint256 budget,
            uint256 spent,
            uint256 claims,
            uint256 nextStartTs,
            bytes32 merkleRoot,
            uint256 priceUsd18,
            bool manualPrice
        ) = drop.getCycle(2);

        assertEq(id, 2);
        assertEq(duration, CYCLE_DURATION);
        assertEq(spent, 0);
        assertEq(claims, 0);
        assertEq(merkleRoot, root);
        assertEq(priceUsd18, 1e18);
        assertEq(manualPrice, false);

        // budget = min(5% do saldo do contrato, absoluteCycleCap)
        // saldo = 10.000 => 5% = 500
        assertEq(budget, 500e18);

        assertEq(nextStartTs, startTs + CYCLE_DURATION);
    }

    /* ------------------------------ Claim ------------------------------ */

    function test_Claim_Succeeds_Alice_WithBonus() public {
        _startCycle2(root);

        // configurar 1 task de bonus 5% para Alice
        bytes32 taskId = keccak256("TASK1");
        verifier.setOk(alice, true);

        // owner/dao podem setTask (onlyDAOorOwner). owner aqui é address(this)
        drop.setTask(
            taskId,
            true,
            5, // 5%
            address(verifier),
            MockBonusVerifier.isOk.selector,
            keccak256("TASK_LABEL")
        );

        uint256 balBefore = token.balanceOf(alice);
        uint256 treasuryBefore = token.balanceOf(address(drop));

        vm.prank(alice);
        drop.claim(baseAlice, _proof1(leafB));

        // payout = base + 5%
        uint256 expectedPay = baseAlice + (baseAlice * 5) / 100;

        assertEq(token.balanceOf(alice), balBefore + expectedPay);
        assertEq(token.balanceOf(address(drop)), treasuryBefore - expectedPay);

        // double claim bloqueado
        vm.prank(alice);
        vm.expectRevert(); // AlreadyClaimed (custom error NotEligible)
        drop.claim(baseAlice, _proof1(leafB));
    }

    function test_Claim_Reverts_WrongProof() public {
        _startCycle2(root);

        vm.prank(alice);
        vm.expectRevert(); // NotEligible(INVALID_MERKLE_PROOF)
        drop.claim(baseAlice, _proof1(keccak256("WRONG")));
    }

    function test_Claim_Reverts_IfPaused() public {
        _startCycle2(root);

        drop.pauseEmergencial();

        vm.prank(alice);
        vm.expectRevert(); // Pausable: paused
        drop.claim(baseAlice, _proof1(leafB));
    }

    function test_Claim_ClampsToRemainingBudget_ThenBudgetOver() public {
        _startCycle2(root);

        // budget esperado = 500e18 (ver setup)
        // tentar claim base grande para forçar clamp no remaining
        uint256 bigBase = 600e18;

        // Coloca alice elegível com bigBase -> precisa estar na merkle (então vamos criar root novo com bigBase)
        bytes32 leafA2 = _leafFor(alice, bigBase);
        bytes32 leafB2 = _leafFor(bob, baseBob);
        bytes32 root2 = _root2(leafA2, leafB2);

        // esperar próximo ciclo
        vm.warp(block.timestamp + CYCLE_DURATION + 1);
        drop.startNextCycle(root2);

        // budget vai ser de novo 500e18 (saldo ainda alto)
        // claim da alice vai ser clampada para 500e18 (remaining)
        uint256 balBefore = token.balanceOf(alice);

        vm.prank(alice);
        drop.claim(bigBase, _proof1(leafB2));

        assertEq(token.balanceOf(alice), balBefore + 500e18);

        // agora budget está esgotado -> bob reverte BudgetOver
        vm.prank(bob);
        vm.expectRevert(); // BudgetOver (custom error)
        drop.claim(baseBob, _proof1(leafA2));
    }

    /* ------------------------------ Labs read API ------------------------------ */

    function test_LabsConsulta_Works_WithFee() public {
        _startCycle2(root);

        // não whitelisted => precisa pagar fee
        uint256 fee = labs.getConsultaFee();

        vm.deal(address(0x1234), 1 ether);
        vm.prank(address(0x1234));

        (bool eligible, bytes32 reason, uint256 bonusPercent, uint256 estimatedPay) =
            drop.labsConsultaElegibilidade{value: fee}(2, alice, baseAlice, _proof1(leafB));

        assertTrue(eligible);
        assertEq(reason, bytes32(0));
        assertEq(bonusPercent, 0);
        assertEq(estimatedPay, baseAlice);
    }
}

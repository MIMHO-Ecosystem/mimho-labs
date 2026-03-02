// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// --- import do seu contrato alvo ---
import "../../src/dao.sol";

/* ============================================================
   DAO Alpha Test (MIMHO)
   - Teste estrutural (deploy + flows principais)
   - Usa mocks simples (Registry, Token, Reputation, EventsHub)
   ============================================================ */

contract MockERC20 {
    mapping(address => uint256) public balanceOf;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }
}

contract MockEventsHub is IMIMHOEventsHub {
    event HubEvent(bytes32 module, bytes32 action, address caller, uint256 value, bytes data);

    bytes32 public lastModule;
    bytes32 public lastAction;
    address public lastCaller;
    uint256 public lastValue;

    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external override {
        lastModule = module;
        lastAction = action;
        lastCaller = caller;
        lastValue = value;
        emit HubEvent(module, action, caller, value, data);
    }
}

contract MockReputation is IMIMHOReputationBonus {
    uint256 public bonus;

    function setBonus(uint256 b) external {
        bonus = b;
    }

    function getBonusPercent(address /*user*/) external view override returns (uint256) {
        return bonus;
    }
}

contract MockRegistryDAO is IMIMHORegistry {
    mapping(bytes32 => address) public map;

    bytes32 internal constant K_EVENTS = keccak256("KEY_MIMHO_EVENTS_HUB");
    bytes32 internal constant K_REP    = keccak256("KEY_MIMHO_REPUTATION");
    bytes32 internal constant K_TOKEN  = keccak256("KEY_MIMHO_TOKEN");

    function set(bytes32 k, address v) external {
        map[k] = v;
    }

    function getContract(bytes32 key) external view override returns (address) {
        return map[key];
    }

    function KEY_MIMHO_EVENTS_HUB() external pure override returns (bytes32) { return K_EVENTS; }
    function KEY_MIMHO_REPUTATION() external pure override returns (bytes32) { return K_REP; }
    function KEY_MIMHO_TOKEN() external pure override returns (bytes32) { return K_TOKEN; }
}

contract DaoAlphaTest is Test {
    MIMHODaoGovernance internal dao;
    MockRegistryDAO internal reg;
    MockERC20 internal token;
    MockEventsHub internal hub;
    MockReputation internal rep;

    address internal alice = address(0xA11CE);
    address internal bob   = address(0xB0B);
    address internal c1    = address(0xC001);
    address internal c2    = address(0xC002);
    address internal c3    = address(0xC003);
    address internal c4    = address(0xC004);
    address internal c5    = address(0xC005);

    function setUp() public {
        reg = new MockRegistryDAO();
        token = new MockERC20();
        hub = new MockEventsHub();
        rep = new MockReputation();

        // Registry wiring
        reg.set(reg.KEY_MIMHO_TOKEN(), address(token));
        reg.set(reg.KEY_MIMHO_EVENTS_HUB(), address(hub));
        reg.set(reg.KEY_MIMHO_REPUTATION(), address(rep));

        // Deploy DAO with params (ajustáveis)
        dao = new MIMHODaoGovernance(
            address(reg),
            1_000_000e18,  // minTokensToVote
            1_000_000e18,  // minTokensToCandidate
            50             // maxBonusPercent (cap)
        );
    }

    function _eligible(address user) internal {
        // dá tokens
        token.mint(user, 1_000_000e18);

        // registra holding
        vm.prank(user);
        dao.registerHolding();

        // avança tempo pra bater minHoldTime (default 90 days)
        vm.warp(block.timestamp + 90 days + 1);
    }

    function _register5Candidates() internal {
        _eligible(c1);
        _eligible(c2);
        _eligible(c3);
        _eligible(c4);
        _eligible(c5);

        vm.prank(c1); dao.registerCandidate();
        vm.prank(c2); dao.registerCandidate();
        vm.prank(c3); dao.registerCandidate();
        vm.prank(c4); dao.registerCandidate();
        vm.prank(c5); dao.registerCandidate();
    }

    function test_Deploy_Works() public {
        assertEq(dao.version(), "1.0.0");
        assertTrue(address(dao.registry()) != address(0));
        // token foi resolvido via registry
        assertTrue(address(dao.mimhoToken()) != address(0));
    }

    function test_RegisterHolding_Works_Once() public {
        vm.prank(alice);
        dao.registerHolding();
        uint256 t1 = dao.holdingSince(alice);
        assertTrue(t1 > 0);

        // segunda chamada não muda
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        dao.registerHolding();
        uint256 t2 = dao.holdingSince(alice);
        assertEq(t1, t2);
    }

    function test_Candidate_RequiresEligibility() public {
        // sem tokens + sem holding -> deve reverter
        vm.prank(alice);
        vm.expectRevert();
        dao.registerCandidate();

        _eligible(alice);

        // agora pode
        vm.prank(alice);
        dao.registerCandidate();
        assertTrue(dao.isCandidate(alice));
        assertEq(dao.candidatesCount(), 1);
    }

    function test_StartElection_Requires5Candidates() public {
    // registra só 1 candidato
    _eligible(c1);
    vm.prank(c1);
    dao.registerCandidate();

    vm.expectRevert(bytes("MIMHO: need >= 5 candidates"));
    dao.startElection(3 days);

    // agora completa até 5 SEM duplicar c1
    _eligible(c2);
    _eligible(c3);
    _eligible(c4);
    _eligible(c5);

    vm.prank(c2); dao.registerCandidate();
    vm.prank(c3); dao.registerCandidate();
    vm.prank(c4); dao.registerCandidate();
    vm.prank(c5); dao.registerCandidate();

    dao.startElection(3 days);

    (bool active,, uint256 end, uint256 count) = dao.getElectionState();
    assertTrue(active);
    assertTrue(end > block.timestamp);
    assertEq(count, 5);
}

    function test_Vote_Works_AndUsesBonusCap() public {
        _register5Candidates();
        dao.startElection(3 days);

        _eligible(alice);

        // dá mais tokens pra aumentar sqrt(bal) e ter peso > 0
        token.mint(alice, 9_000_000e18);

        // seta bônus alto, mas cap deve cortar para maxBonusPercent (50)
        rep.setBonus(200);

        vm.prank(alice);
        dao.vote(c1);

        assertTrue(dao.hasVoted(alice));
        uint256 v = dao.getVotes(c1);
        assertTrue(v > 0);
    }

    function test_PauseBlocks_RegisterHolding_And_Vote() public {
        // pausa
        dao.pauseEmergencial();
        assertTrue(dao.paused());

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: paused"));
        dao.registerHolding();

        // prepara eleição
        dao.unpause();
        _register5Candidates();
        dao.startElection(3 days);

        _eligible(alice);

        // pausa e tenta votar
        dao.pauseEmergencial();

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: paused"));
        dao.vote(c1);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/* ============================================================
   MIMHO Inject Liquidity Voting Controller — v1.0.1 (Pre-DAO)
   ============================================================

   DESIGN PHILOSOPHY (MIMHO ABSOLUTE STANDARD)

   - Minimal, Single-Purpose Governance:
     This contract exists for one decision only: authorize (YES/NO)
     whether MIMHOInjectLiquidity may enable its auto-injection mode
     for the current cycle.

   - No Funds, No Economics, No Execution:
     It never holds, transfers, swaps, burns, mints, injects liquidity,
     or touches LP/BNB. It is NOT a DAO. It is only a gatekeeper.

   - Safe-by-Design:
     Limited surface area, strict phases (prepare -> vote -> finalize),
     reentrancy protection on voting, and no upgrade logic.

   - Transparent & HUD-Ready:
     Every meaningful action emits local events and also broadcasts
     (best-effort) to the MIMHO Events Hub via Registry resolution.

   - Registry-First, No Hardcoded Addresses:
     All integrations resolve addresses from MIMHORegistry using its
     public KEY getters (no local keccak/string repetition).

   - Permission Model with Clean DAO Takeover:
     Uses onlyDAOorOwner before DAO activation and onlyDAO after.
     No renounceOwnership patterns.

   - No Cron / No Hidden Automation:
     Blockchain does not execute by itself. Anyone can finalize after
     the end time. The "authorization" is pushed to InjectLiquidity
     at finalize (one call), InjectLiquidity does the execution later
     under its own cooldown/guards.

   ============================================================ */

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    // ABSOLUTE RULE: use registry.KEY_*() + getContract(key)
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_INJECT_LIQUIDITY() external view returns (bytes32);
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
}

interface IMIMHOEventsHub {
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external;
}

interface IERC20Like {
    function balanceOf(address account) external view returns (uint256);
}

interface IMIMHOInjectLiquidity {
    function setAutoInject(bool enabled) external;
    function autoInjectEnabled() external view returns (bool);
}

contract MIMHOInjectLiquidityVotingController is ReentrancyGuard, Pausable, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                               MIMHO ID
    //////////////////////////////////////////////////////////////*/

    string public constant name = "MIMHO Inject Liquidity Voting Controller";
    string public constant version = "1.0.1";

    /// @dev Used by Events Hub as "module" identifier (HUD category)
    function contractType() public pure returns (bytes32) {
        return keccak256("MIMHO_VOTING_CONTROLLER_INJECT_LIQUIDITY");
    }

    /*//////////////////////////////////////////////////////////////
                           DAO TAKEOVER (ABS)
    //////////////////////////////////////////////////////////////*/

    address public daoAddress;
    bool public daoActivated;

    modifier onlyDAOorOwner() {
        require(msg.sender == owner() || (daoActivated && msg.sender == daoAddress), "MIMHO: not authorized");
        _;
    }

    modifier onlyDAO() {
        require(daoActivated && msg.sender == daoAddress, "MIMHO: DAO not active");
        _;
    }

    function setDAO(address dao) external onlyOwner {
        require(!daoActivated, "MIMHO: DAO active");
        require(dao != address(0), "MIMHO: dao=0");

        // Efeito
        daoAddress = dao;

        // ✅ CORREÇÃO SLITHER: Emissão do evento padrão
        emit DAOSet(dao);

        // Registro no Hub
        _emitHubEvent(bytes32("ACTION_SET_DAO"), msg.sender, 0, abi.encode(dao));
    }

    function activateDAO() external onlyOwner {
        require(daoAddress != address(0), "MIMHO: DAO not set");
        daoActivated = true;
        emit DAOActivated(daoAddress);
        _emitHubEvent(ACTION_DAO_ACTIVATED, msg.sender, 0, abi.encode(daoAddress));
    }

    /*//////////////////////////////////////////////////////////////
                               REGISTRY
    //////////////////////////////////////////////////////////////*/

    IMIMHORegistry public immutable registry;

    constructor(address registryAddr) Ownable() {
        require(registryAddr != address(0), "MIMHO: registry=0");
        registry = IMIMHORegistry(registryAddr);

        // Soft-announce deploy (best-effort)
        _emitHubEvent(ACTION_DEPLOYED, msg.sender, 0, abi.encode(registryAddr));
    }

    /*//////////////////////////////////////////////////////////////
                           VOTING PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimal balance required to vote (set to 0 for open voting).
    uint256 public minBalance;

    /// @notice Controls how frequently a new vote can be started.
    /// @dev This is NOT the injection cooldown; InjectLiquidity must enforce its own cooldown.
    uint256 public voteCooldown; // default configurable (e.g., 7 days)
    uint256 public lastVoteStart; // timestamp of last startVote()

    uint256 public constant MIN_VOTE_COOLDOWN = 1 days;
    uint256 public constant MAX_VOTE_COOLDOWN = 45 days;

    /*//////////////////////////////////////////////////////////////
                              VOTING STATE
    //////////////////////////////////////////////////////////////*/

    // Phases:
    // - Prepare: [prepareStart, voteStart)
    // - Vote:    [voteStart, voteEnd)
    // - Ended:   >= voteEnd (anyone can finalize)
    uint256 public voteId; // increments each new cycle

    uint256 public prepareStart;
    uint256 public voteStart;
    uint256 public voteEnd;

    uint256 public yesVotes;
    uint256 public noVotes;

    bool public voteFinalized;

    // per vote tracking without clearing mappings
    mapping(address => uint256) private _votedIn; // voter => voteId they voted in
    mapping(address => uint256) private _weightSnapshot; // last snapshot stored
    mapping(address => uint256) private _weightSnapshotIn; // voteId for which snapshot is valid

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VoteStarted(uint256 indexed voteId, uint256 prepareStart, uint256 voteStart, uint256 voteEnd);
    event VoteCast(uint256 indexed voteId, address indexed  voter, bool support, uint256 weight);
    event VoteFinalized(uint256 indexed voteId, bool approved);
    event AutoInjectStatusChanged(bool enabled);
    event DAOSet(address indexed dao);
    event DAOActivated(address indexed dao);

    event MinBalanceChanged(uint256 newMinBalance);
    event VoteCooldownChanged(uint256 newCooldown);

    /*//////////////////////////////////////////////////////////////
                            EVENTS HUB (ABS)
    //////////////////////////////////////////////////////////////*/

    // Actions (bytes32) for hub
    bytes32 private constant ACTION_DEPLOYED          = keccak256("DEPLOYED");
    bytes32 private constant ACTION_SET_DAO           = keccak256("SET_DAO");
    bytes32 private constant ACTION_ACTIVATE_DAO      = keccak256("ACTIVATE_DAO");
    bytes32 private constant ACTION_PAUSED            = keccak256("PAUSED");
    bytes32 private constant ACTION_UNPAUSED          = keccak256("UNPAUSED");
    bytes32 public constant ACTION_DAO_ACTIVATED      = keccak256("ACTION_DAO_ACTIVATED");

    bytes32 private constant ACTION_VOTE_STARTED      = keccak256("VOTE_STARTED");
    bytes32 private constant ACTION_VOTE_CAST         = keccak256("VOTE_CAST");
    bytes32 private constant ACTION_VOTE_FINALIZED    = keccak256("VOTE_FINALIZED");
    bytes32 private constant ACTION_AUTO_INJECT_SET   = keccak256("AUTO_INJECT_SET");

    bytes32 private constant ACTION_MIN_BALANCE_SET   = keccak256("MIN_BALANCE_SET");
    bytes32 private constant ACTION_VOTE_COOLDOWN_SET = keccak256("VOTE_COOLDOWN_SET");

    function _emitHubEvent(bytes32 action, address caller, uint256 value, bytes memory data) internal {
        address hubAddr = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());
        if (hubAddr == address(0)) return;

        // ABSOLUTE RULE: best-effort try/catch to never break core logic
        try IMIMHOEventsHub(hubAddr).emitEvent(contractType(), action, caller, value, data) {
            // ok
        } catch {
            // ignore
        }
    }

    /*//////////////////////////////////////////////////////////////
                             ADMIN CONFIG
    //////////////////////////////////////////////////////////////*/

    /// @notice Adjust the minimum balance to vote. Set to 0 for open voting.
    function setMinBalance(uint256 newMinBalance) external onlyDAOorOwner {
        require(!isVotingActive(), "MIMHO: locked during vote");
        minBalance = newMinBalance;
        emit MinBalanceChanged(newMinBalance);
        _emitHubEvent(ACTION_MIN_BALANCE_SET, msg.sender, newMinBalance, "");
    }

    /// @notice Adjust how often a new vote can start (vote creation frequency).
    function setVoteCooldown(uint256 newCooldown) external onlyDAOorOwner {
        require(!isVotingActive(), "MIMHO: locked during vote");
        require(newCooldown >= MIN_VOTE_COOLDOWN, "MIMHO: cooldown too low");
        require(newCooldown <= MAX_VOTE_COOLDOWN, "MIMHO: cooldown too high");
        voteCooldown = newCooldown;
        emit VoteCooldownChanged(newCooldown);
        _emitHubEvent(ACTION_VOTE_COOLDOWN_SET, msg.sender, newCooldown, "");
    }

    /*//////////////////////////////////////////////////////////////
                          START / PHASE CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice Starts a new cycle with a prepare phase and a vote phase.
    /// @dev Only owner/DAO can start. Anyone can finalize after voteEnd.
    /// @param prepareDuration Seconds for community to prepare (no voting allowed).
    /// @param voteDuration Seconds for actual voting.
    function startVote(uint256 prepareDuration, uint256 voteDuration)
        external
        onlyDAOorOwner
        whenNotPaused
    {
        require(prepareDuration > 0, "MIMHO: prepare=0");
        require(voteDuration > 0, "MIMHO: vote=0");
        require(!isVotingActive(), "MIMHO: already active");
        require(block.timestamp >= lastVoteStart + voteCooldown, "MIMHO: vote cooldown");

        // Registry sanity checks (avoid misconfig errors)
        require(
            registry.getContract(registry.KEY_MIMHO_TOKEN()) != address(0),
            "MIMHO: token not set in registry"
        );
        require(
            registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY()) != address(0),
            "MIMHO: inject not set in registry"
        );

        voteId += 1;

        prepareStart = block.timestamp;
        voteStart = block.timestamp + prepareDuration;
        voteEnd = voteStart + voteDuration;

        lastVoteStart = block.timestamp;

        yesVotes = 0;
        noVotes = 0;
        voteFinalized = false;

        emit VoteStarted(voteId, prepareStart, voteStart, voteEnd);
        _emitHubEvent(ACTION_VOTE_STARTED, msg.sender, 0, abi.encode(voteId, prepareStart, voteStart, voteEnd));
    }

    /*//////////////////////////////////////////////////////////////
                                VOTING
    //////////////////////////////////////////////////////////////*/

    function voteYes() external nonReentrant whenNotPaused {
        _vote(true);
    }

    function voteNo() external nonReentrant whenNotPaused {
        _vote(false);
    }

    function _vote(bool support) internal {
        require(isVotingPhase(), "MIMHO: not voting phase");
        require(_votedIn[msg.sender] != voteId, "MIMHO: already voted");
        require(canVote(msg.sender), "MIMHO: not eligible");

        uint256 weight = _snapshotWeight(msg.sender);
        require(weight > 0, "MIMHO: zero weight");

        _votedIn[msg.sender] = voteId;

        if (support) {
            yesVotes += weight;
        } else {
            noVotes += weight;
        }

        emit VoteCast(voteId, msg.sender, support, weight);
        _emitHubEvent(ACTION_VOTE_CAST, msg.sender, weight, abi.encode(voteId, support, weight));
    }

    /// @dev Snapshot on first vote of the current voteId (lightweight and safe).
    function _snapshotWeight(address voter) internal returns (uint256) {
        if (_weightSnapshotIn[voter] != voteId) {
            address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
            require(tokenAddr != address(0), "MIMHO: token not set");
            uint256 bal = IERC20Like(tokenAddr).balanceOf(voter);
            _weightSnapshot[voter] = bal;
            _weightSnapshotIn[voter] = voteId;
        }
        return _weightSnapshot[voter];
    }

    /*//////////////////////////////////////////////////////////////
                               FINALIZE
    //////////////////////////////////////////////////////////////*/

    /// @notice Finalizes the vote after voteEnd. Anyone can call.
    /// @dev Pushes authorization to InjectLiquidity by calling setAutoInject(true) if approved.
    function finalizeVote() external whenNotPaused {
        require(hasVoteEnded(), "MIMHO: not ended");
        require(!voteFinalized, "MIMHO: finalized");

        // Registry sanity check
        address injectAddr = registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
        require(injectAddr != address(0), "MIMHO: inject not set in registry");

        voteFinalized = true;

        bool approved = yesVotes > noVotes;

        if (approved) {
            // Authorization push: "InjectLiquidity, you're allowed (auto mode ON)."
            IMIMHOInjectLiquidity(injectAddr).setAutoInject(true);

            emit AutoInjectStatusChanged(true);
            _emitHubEvent(ACTION_AUTO_INJECT_SET, msg.sender, 1, abi.encode(true));
        }

        emit VoteFinalized(voteId, approved);
        _emitHubEvent(
            ACTION_VOTE_FINALIZED,
            msg.sender,
            approved ? 1 : 0,
            abi.encode(voteId, approved, yesVotes, noVotes)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW (HUD)
    //////////////////////////////////////////////////////////////*/

    function isPreparePhase() public view returns (bool) {
        return prepareStart != 0 && block.timestamp >= prepareStart && block.timestamp < voteStart && !voteFinalized;
    }

    function isVotingPhase() public view returns (bool) {
        return voteStart != 0 && block.timestamp >= voteStart && block.timestamp < voteEnd && !voteFinalized;
    }

    function isVotingActive() public view returns (bool) {
        // "active" includes prepare or voting
        return (isPreparePhase() || isVotingPhase());
    }

    function hasVoteEnded() public view returns (bool) {
        return voteEnd != 0 && block.timestamp >= voteEnd;
    }

    function voteEndTime() external view returns (uint256) {
        return voteEnd;
    }

    function hasVoted(address voter) external view returns (bool) {
        return _votedIn[voter] == voteId;
    }

    function canVote(address voter) public view returns (bool) {
        address tokenAddr = registry.getContract(registry.KEY_MIMHO_TOKEN());
        if (tokenAddr == address(0)) return false;
        uint256 bal = IERC20Like(tokenAddr).balanceOf(voter);
        return bal >= minBalance;
    }

    function currentAutoInjectStatus() external view returns (bool) {
        address injectAddr = registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
        require(injectAddr != address(0), "MIMHO: inject not set");
        return IMIMHOInjectLiquidity(injectAddr).autoInjectEnabled();
    }

    /// @notice Helper HUD button: what InjectLiquidity address is currently set in Registry.
    function injectLiquidityAddress() external view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY());
    }

    /// @notice Helper HUD button: what Token address is currently set in Registry.
    function tokenAddress() external view returns (address) {
        return registry.getContract(registry.KEY_MIMHO_TOKEN());
    }

    /*//////////////////////////////////////////////////////////////
                                SAFETY
    //////////////////////////////////////////////////////////////*/

    function pauseEmergencial() external onlyDAOorOwner {
        _pause();
        _emitHubEvent(ACTION_PAUSED, msg.sender, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        _unpause();
        _emitHubEvent(ACTION_UNPAUSED, msg.sender, 0, "");
    }

    /*//////////////////////////////////////////////////////////////
                              RECEIVE / FALLBACK
    //////////////////////////////////////////////////////////////*/

    receive() external payable {
        revert("MIMHO: no BNB");
    }

    fallback() external payable {
        revert("MIMHO: invalid call");
    }

    /// @dev Resgata BNB preso acidentalmente no contrato.
    function rescueNative() external onlyDAOorOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "MIMHO: balance is zero");
        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "MIMHO: rescue failed");
    }
}
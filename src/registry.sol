// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title MIMHO Registry
 * @notice Single source of truth for the MIMHO ecosystem contract addresses.
 *
 * @dev DESIGN PHILOSOPHY
 * ------------------------------------------------------------
 * The Registry is intentionally simple, strict, and transparent.
 * It stores and exposes official ecosystem addresses and forwards
 * important actions to the MIMHO Events Hub.
 *
 * It does NOT:
 * - Execute business logic
 * - Hold user funds
 * - Mint/burn tokens
 * - Depend on external contracts to function
 *
 * MODULARITY
 * - Ecosystem modules are identified by fixed, explicit setters.
 * - Partner/Labs contracts are handled separately (manual module).
 *
 * GOVERNANCE
 * - Before DAO activation: Founder Safe controls updates.
 * - After DAO activation: only DAO controls updates.
 *
 * SECURITY
 * - No delegatecall, no proxies, no hidden authority.
 * - Pause support for emergency management.
 * - Address validation for all setters.
 *
 * OBSERVABILITY
 * - Every relevant action emits events and is forwarded to Events Hub.
 */

/* ============================================================
                        EVENTS HUB INTERFACE
   ============================================================ */
interface IMIMHOEventsHub {
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external;
}

/* ============================================================
                        REGISTRY INTERFACE (SLITHER)
   ============================================================ */
interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
    function isEcosystemContract(address a) external view returns (bool);
}

/* ============================================================
                        OPTIONAL PROTOCOL INTERFACE
   ============================================================ */
interface IMIMHOProtocol {
    function contractName() external pure returns (string memory);
    function contractType() external pure returns (bytes32);
    function version() external pure returns (string memory);

    function paused() external view returns (bool);
    function isObservable() external pure returns (bool);
    function getActionType() external pure returns (bytes32);

    function getRiskLevel() external pure returns (uint8);
    function isFinalized() external view returns (bool);

    function getFinancialImpact(address user)
        external
        view
        returns (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue);

    function getBoostValue(address user) external view returns (uint256);
    function onExternalAction(address user, bytes32 action) external;
}

/* ============================================================
                            REGISTRY
   ============================================================ */
contract MIMHORegistry is IMIMHORegistry, IMIMHOProtocol, Ownable2Step {

    /* =======================================================
                            CONSTANTS
    ======================================================= */

    bytes32 public constant CONTRACT_TYPE = keccak256("MIMHO_REGISTRY");
    bytes32 public constant ACTION_TYPE   = keccak256("REGISTRY_ACTION");

    bytes32 private constant HUB_MODULE = keccak256("REGISTRY");

    bytes32 private constant ACT_SET_DAO          = keccak256("SET_DAO");
    bytes32 private constant ACT_ACTIVATE_DAO     = keccak256("ACTIVATE_DAO");
    bytes32 private constant ACT_PAUSE            = keccak256("PAUSE");
    bytes32 private constant ACT_UNPAUSE          = keccak256("UNPAUSE");
    bytes32 private constant ACT_SET_ADDRESS      = keccak256("SET_ADDRESS");
    bytes32 private constant ACT_PARTNER_SERVICE  = keccak256("PARTNER_SERVICE_SET");

    // ------------------------------------------------------------
    // OFFICIAL KEYS (anti-typo / anti-human-error)
    // ------------------------------------------------------------
    bytes32 public constant KEY_MIMHO_TOKEN               = keccak256("MIMHO_TOKEN");
    bytes32 public constant KEY_MIMHO_DAO                 = keccak256("MIMHO_DAO");
    bytes32 public constant KEY_MIMHO_EVENTS_HUB          = keccak256("MIMHO_EVENTS_HUB");

    bytes32 public constant KEY_MIMHO_SECURITY_WALLET     = keccak256("MIMHO_SECURITY_WALLET");
    bytes32 public constant KEY_MIMHO_VERITAS             = keccak256("MIMHO_VERITAS");
    bytes32 public constant KEY_MIMHO_AUDIT               = keccak256("MIMHO_AUDIT");
    bytes32 public constant KEY_MIMHO_GAS_SAVER           = keccak256("MIMHO_GAS_SAVER");
    bytes32 public constant KEY_MIMHO_OBSERVER            = keccak256("MIMHO_OBSERVER");

    bytes32 public constant KEY_MIMHO_STAKING             = keccak256("MIMHO_STAKING");
    bytes32 public constant KEY_MIMHO_PRESALE             = keccak256("MIMHO_PRESALE");
    bytes32 public constant KEY_MIMHO_VESTING             = keccak256("MIMHO_VESTING");
    bytes32 public constant KEY_MIMHO_BURN                = keccak256("MIMHO_BURN");
    bytes32 public constant KEY_MIMHO_LOCKER              = keccak256("MIMHO_LOCKER");
    bytes32 public constant KEY_MIMHO_AIRDROP             = keccak256("MIMHO_AIRDROP");
    bytes32 public constant KEY_MIMHO_INVOICE             = keccak256("MIMHO_INVOICE");
    bytes32 public constant KEY_MIMHO_INJECT_LIQUIDITY    = keccak256("MIMHO_INJECT_LIQUIDITY");
    bytes32 public constant KEY_MIMHO_TRADING_ACTIVITY    = keccak256("MIMHO_TRADING_ACTIVITY");

    bytes32 public constant KEY_MIMHO_LOANS               = keccak256("MIMHO_LOANS");
    bytes32 public constant KEY_MIMHO_BET                 = keccak256("MIMHO_BET");
    bytes32 public constant KEY_MIMHO_LOTTERY             = keccak256("MIMHO_LOTTERY");
    bytes32 public constant KEY_MIMHO_RAFFLE              = keccak256("MIMHO_RAFFLE");
    bytes32 public constant KEY_MIMHO_AUCTIONER           = keccak256("MIMHO_AUCTIONER");
    bytes32 public constant KEY_MIMHO_PULSE               = keccak256("MIMHO_PULSE");
    bytes32 public constant KEY_MIMHO_QUIZ                = keccak256("MIMHO_QUIZ");

    bytes32 public constant KEY_MIMHO_MART                = keccak256("MIMHO_MART");
    bytes32 public constant KEY_MIMHO_MARKETPLACE         = keccak256("MIMHO_MARKETPLACE");

    bytes32 public constant KEY_MIMHO_VOTING_CONTROLLER   = keccak256("MIMHO_VOTING_CONTROLLER");
    bytes32 public constant KEY_MIMHO_STRATEGY_HUB        = keccak256("MIMHO_STRATEGY_HUB");
    bytes32 public constant KEY_MIMHO_LIQUIDITY_BOOTSTRAPER = keccak256("MIMHO_LIQUIDITY_BOOTSTRAPER");
    bytes32 public constant KEY_MIMHO_HOLDER_DISTRIBUTION = keccak256("MIMHO_HOLDER_DISTRIBUTION");

    bytes32 public constant KEY_MIMHO_GATEWAY             = keccak256("MIMHO_GATEWAY");
    bytes32 public constant KEY_MIMHO_DEX                 = keccak256("MIMHO_DEX");
    bytes32 public constant KEY_MIMHO_SCORE               = keccak256("MIMHO_SCORE");
    bytes32 public constant KEY_MIMHO_PERSONA             = keccak256("MIMHO_PERSONA");
    bytes32 public constant KEY_MIMHO_BANK                = keccak256("MIMHO_BANK");
    bytes32 public constant KEY_MIMHO_RECEIVE             = keccak256("MIMHO_RECEIVE");
    bytes32 public constant KEY_MIMHO_PIX                 = keccak256("MIMHO_PIX");
    bytes32 public constant KEY_MIMHO_CERTIFY             = keccak256("MIMHO_CERTIFY");

    // ------------------------------------------------------------
    // OFFICIAL WALLET KEYS (OPERATIONAL SAFES)
    // ------------------------------------------------------------
    bytes32 public constant KEY_MIMHO_DAO_WALLET           = keccak256("MIMHO_DAO_WALLET");
    bytes32 public constant KEY_WALLET_MARKETING          = keccak256("WALLET_MARKETING");
    bytes32 public constant KEY_WALLET_TECHNICAL          = keccak256("WALLET_TECHNICAL");
    bytes32 public constant KEY_WALLET_DONATION           = keccak256("WALLET_DONATION");
    bytes32 public constant KEY_WALLET_BURN               = keccak256("WALLET_BURN");
    bytes32 public constant KEY_WALLET_LP_RESERVE         = keccak256("WALLET_LP_RESERVE");
    bytes32 public constant KEY_WALLET_LIQUIDITY_RESERVE  = keccak256("WALLET_LIQUIDITY_RESERVE");
    bytes32 public constant KEY_WALLET_SECURITY_RESERVE   = keccak256("WALLET_SECURITY_RESERVE");
    bytes32 public constant KEY_WALLET_BANK               = keccak256("WALLET_BANK");
    bytes32 public constant KEY_WALLET_LOCKER             = keccak256("WALLET_LOCKER");
    bytes32 public constant KEY_WALLET_LABS               = keccak256("WALLET_LABS");
    bytes32 public constant KEY_WALLET_AIRDROPS           = keccak256("WALLET_AIRDROPS");
    bytes32 public constant KEY_WALLET_GAME               = keccak256("WALLET_GAME");
    bytes32 public constant KEY_WALLET_MART               = keccak256("WALLET_MART");

    // ------------------------------------------------------------
    // LEGACY / TOKEN COMPATIBILITY KEYS (ALIASES)
    // (DO NOT REMOVE)
    // ------------------------------------------------------------
    bytes32 public constant KEY_LP_INJECTOR       = keccak256("LP_INJECTOR");
    bytes32 public constant KEY_STAKING_CONTRACT  = keccak256("STAKING_CONTRACT");
    bytes32 public constant KEY_MARKETING_WALLET  = keccak256("MARKETING_WALLET");

    /* =======================================================
                            STORAGE
    ======================================================= */

    // NOTE: kept governance logic intact; this is the Founder Safe identity for pre-DAO phase.
    address public immutable ownersafe;

    address public dao;            // DAO contract address
    bool public daoActivated;
    bool public paused;

    IMIMHOEventsHub public eventsHub; // HUD speaker

    /* =======================================================
                        ECOSYSTEM ADDRESSES
    ======================================================= */

    // Core
    address public mimhoToken;

    // Security / infra
    address public mimhoSecurityWallet;
    address public mimhoVeritas;
    address public mimhoAudit;
    address public mimhoGasSaver;
    address public mimhoObserver;

    // Economy modules
    address public mimhoStaking;
    address public mimhoPresale;
    address public mimhoVesting;
    address public mimhoBurn;
    address public mimhoLocker;
    address public mimhoAirdrop;
    address public mimhoInvoice;
    address public mimhoInjectLiquidity;
    address public mimhoTradingActivity;

    // Extra economy / games
    address public mimhoLoans;
    address public mimhoBet;
    address public mimhoLottery;
    address public mimhoQuiz;
    address public mimhoRaffle;
    address public mimhoAuctioner;
    address public mimhoPulse;

    // NFT & apps
    address public mimhoMart;
    address public mimhoMarketplace;

    // Optional / extended
    address public mimhoGateway;
    address public mimhoDEX;
    address public mimhoScore;
    address public mimhoPersona;
    address public mimhoBank;
    address public mimhoReceive;
    address public mimhoPIX;
    address public mimhoCertify;

    // Governance helpers
    address public mimhoVotingController;
    address public mimhoStrategyHub;
    address public mimhoLiquidityBootstraper;
    address public mimhoHolderDistribution;

    // Wallets / operational safes (NOT ecosystem emitters)
    address public walletDAOTreasury;
    address public walletMarketing;
    address public walletTechnical;
    address public walletDonation;
    address public walletBurn;
    address public walletLPReserve;
    address public walletLiquidityReserve;
    address public walletSecurityReserve;
    address public walletBank;
    address public walletLocker;
    address public walletLabs;
    address public walletAirdrops;
    address public walletGame;
    address public walletMart;

    /* =======================================================
                            PARTNERS / LABS
    ======================================================= */
    struct PartnerService {
        bool allowed;
        uint64 validUntil; // unix timestamp (0 = inactive)
    }

    mapping(address => mapping(bytes32 => PartnerService)) private partnerServices;

    /* =======================================================
                            EVENTS
    ======================================================= */

    event OwnerSet(address indexed  owner);
    event DAOSet(address indexed  dao);
    event DAOActivated();
    event Paused();
    event Unpaused();

    event EventsHubSet(address indexed  hub);
    event AddressSet(bytes32 indexed moduleId, address indexed  addr);

    event PartnerServiceSet(address indexed  partner, bytes32 indexed serviceId, uint64 validUntil, bool allowed);

    /* =======================================================
                          MODIFIERS
    ======================================================= */

    modifier onlyDAOorOwner() {
        if (daoActivated) {
            require(msg.sender == dao, "MIMHO: DAO only");
        } else {
            require(msg.sender == ownersafe, "MIMHO: owner only");
        }
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "MIMHO: paused");
        _;
    }

    /* =======================================================
                          CONSTRUCTOR
    ======================================================= */

    constructor(address founderSafeOwner) {
        require(founderSafeOwner != address(0), "MIMHO: zero owner");
        ownersafe = founderSafeOwner;

        // OZ owner set (kept for tooling), DOES NOT change your governance logic.
        _transferOwnership(founderSafeOwner);

        emit OwnerSet(founderSafeOwner);
    }

    /* =======================================================
                      INTERNAL HUB EMITTER (BEST-EFFORT)
    ======================================================= */

    function _emitHubEvent(bytes32 action, uint256 value, bytes memory data) internal {
        address hub = address(eventsHub);
        if (hub == address(0)) return;

        // Best-effort (never break core logic)
        try IMIMHOEventsHub(hub).emitEvent(HUB_MODULE, action, msg.sender, value, data) {
        } catch {
            // intentionally swallow
        }
    }

    /* =======================================================
                        GOVERNANCE
    ======================================================= */

    function setDAO(address _dao) external onlyOwner whenNotPaused {
        require(_dao != address(0), "MIMHO: zero DAO");
        require(dao == address(0), "MIMHO: DAO already set");
        dao = _dao;
        _setAddress(KEY_MIMHO_DAO, _dao);
        emit DAOSet(_dao);
        _emitHubEvent(ACT_SET_DAO, 0, abi.encode(_dao));
    }

    function activateDAO() external onlyOwner whenNotPaused {
        require(dao != address(0), "MIMHO: DAO not set");
        require(!daoActivated, "MIMHO: DAO already active");
        daoActivated = true;
        emit DAOActivated();
        _emitHubEvent(ACT_ACTIVATE_DAO, 0, abi.encode(dao));
    }

    function pauseEmergencial() external onlyDAOorOwner {
        require(!paused, "MIMHO: already paused");
        paused = true;
        emit Paused();
        _emitHubEvent(ACT_PAUSE, 0, "");
    }

    function unpause() external onlyDAOorOwner {
        require(paused, "MIMHO: not paused");
        paused = false;
        emit Unpaused();
        _emitHubEvent(ACT_UNPAUSE, 0, "");
    }

    /* =======================================================
                        EVENTS HUB CONFIG
       IMPORTANT:
       - Must set BOTH: mimhoEventsHub + eventsHub speaker
       - Must emit via _setAddress() (which already speaks to hub)
       - Must avoid duplicate hub emissions for the same action
    ======================================================= */

    function setEventsHub(address hub) external onlyDAOorOwner whenNotPaused {
        require(hub != address(0), "MIMHO: zero hub");

        eventsHub = IMIMHOEventsHub(hub);
        emit EventsHubSet(hub);

        // Standardize: one canonical path (also emits AddressSet + HUD event)
        _setAddress(KEY_MIMHO_EVENTS_HUB, hub);
    }

    /* =======================================================
                        INTERNAL SETTER HELPER
    ======================================================= */

    function _setAddress(bytes32 moduleId, address a) internal {
        require(a != address(0), "MIMHO: zero address");
        emit AddressSet(moduleId, a);
        _emitHubEvent(ACT_SET_ADDRESS, 0, abi.encode(moduleId, a));
    }

    /* =======================================================
                    SETTERS — ECOSYSTEM (EXPLICIT)
    ======================================================= */

    // Core
    function setMIMHOToken(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        mimhoToken = a;
        _setAddress(KEY_MIMHO_TOKEN, a);
    }

    // Security / infra
    function setMIMHOSecurityWallet(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoSecurityWallet = a; _setAddress(KEY_MIMHO_SECURITY_WALLET, a); }
    function setMIMHOVeritas(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoVeritas = a; _setAddress(KEY_MIMHO_VERITAS, a); }
    function setMIMHOAudit(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoAudit = a; _setAddress(KEY_MIMHO_AUDIT, a); }
    function setMIMHOGasSaver(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoGasSaver = a; _setAddress(KEY_MIMHO_GAS_SAVER, a); }
    function setMIMHOObserver(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoObserver = a; _setAddress(KEY_MIMHO_OBSERVER, a); }

    // Economy modules
    function setMIMHOStaking(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoStaking = a; _setAddress(KEY_MIMHO_STAKING, a); }
    function setMIMHOPresale(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoPresale = a; _setAddress(KEY_MIMHO_PRESALE, a); }
    function setMIMHOVesting(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoVesting = a; _setAddress(KEY_MIMHO_VESTING, a); }
    function setMIMHOBurn(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoBurn = a; _setAddress(KEY_MIMHO_BURN, a); }
    function setMIMHOLocker(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoLocker = a; _setAddress(KEY_MIMHO_LOCKER, a); }
    function setMIMHOAirdrop(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoAirdrop = a; _setAddress(KEY_MIMHO_AIRDROP, a); }
    function setMIMHOInvoice(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoInvoice = a; _setAddress(KEY_MIMHO_INVOICE, a); }
    function setMIMHOInjectLiquidity(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoInjectLiquidity = a; _setAddress(KEY_MIMHO_INJECT_LIQUIDITY, a); }
    function setMIMHOTradingActivity(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoTradingActivity = a; _setAddress(KEY_MIMHO_TRADING_ACTIVITY, a); }

    // Extra economy / games
    function setMIMHOLoans(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoLoans = a; _setAddress(KEY_MIMHO_LOANS, a); }
    function setMIMHOBet(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoBet = a; _setAddress(KEY_MIMHO_BET, a); }
    function setMIMHOLottery(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoLottery = a; _setAddress(KEY_MIMHO_LOTTERY, a); }
    function setMIMHOQuiz(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoQuiz = a; _setAddress(KEY_MIMHO_QUIZ, a); }
    function setMIMHORaffle(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoRaffle = a; _setAddress(KEY_MIMHO_RAFFLE, a); }
    function setMIMHOAuctioner(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoAuctioner = a; _setAddress(KEY_MIMHO_AUCTIONER, a); }
    function setMIMHOPulse(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoPulse = a; _setAddress(KEY_MIMHO_PULSE, a); }

    // NFT & apps
    function setMIMHOMart(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoMart = a; _setAddress(KEY_MIMHO_MART, a); }
    function setMIMHOMarketplace(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoMarketplace = a; _setAddress(KEY_MIMHO_MARKETPLACE, a); }

    // Optional / extended
    function setMIMHOGateway(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoGateway = a; _setAddress(KEY_MIMHO_GATEWAY, a); }
    function setMIMHODEX(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoDEX = a; _setAddress(KEY_MIMHO_DEX, a); }
    function setMIMHOScore(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoScore = a; _setAddress(KEY_MIMHO_SCORE, a); }
    function setMIMHOPersona(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoPersona = a; _setAddress(KEY_MIMHO_PERSONA, a); }
    function setMIMHOBank(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoBank = a; _setAddress(KEY_MIMHO_BANK, a); }

    function setMIMHOReceive(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoReceive = a; _setAddress(KEY_MIMHO_RECEIVE, a); }
    function setMIMHOPIX(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoPIX = a; _setAddress(KEY_MIMHO_PIX, a); }

    function setMIMHOCertify(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoCertify = a; _setAddress(KEY_MIMHO_CERTIFY, a); }

    // Governance helpers
    function setMIMHOVotingController(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoVotingController = a; _setAddress(KEY_MIMHO_VOTING_CONTROLLER, a); }
    function setMIMHOStrategyHub(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoStrategyHub = a; _setAddress(KEY_MIMHO_STRATEGY_HUB, a); }
    function setMIMHOLiquidityBootstraper(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoLiquidityBootstraper = a; _setAddress(KEY_MIMHO_LIQUIDITY_BOOTSTRAPER, a); }
    function setMIMHOHolderDistribution(address a) external onlyDAOorOwner whenNotPaused { require(a != address(0), "MIMHO: zero address"); mimhoHolderDistribution = a; _setAddress(KEY_MIMHO_HOLDER_DISTRIBUTION, a); }

    function setWalletDAOTreasury(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletDAOTreasury = a;
        _setAddress(KEY_MIMHO_DAO_WALLET, a);
    }

    function setWalletMarketing(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletMarketing = a;
        _setAddress(KEY_WALLET_MARKETING, a);
    }

    function setWalletTechnical(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletTechnical = a;
        _setAddress(KEY_WALLET_TECHNICAL, a);
    }

    function setWalletDonation(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletDonation = a;
        _setAddress(KEY_WALLET_DONATION, a);
    }

    function setWalletBurn(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletBurn = a;
        _setAddress(KEY_WALLET_BURN, a);
    }

    function setWalletLPReserve(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletLPReserve = a;
        _setAddress(KEY_WALLET_LP_RESERVE, a);
    }

    function setWalletLiquidityReserve(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletLiquidityReserve = a;
        _setAddress(KEY_WALLET_LIQUIDITY_RESERVE, a);
    }

    function setWalletSecurityReserve(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletSecurityReserve = a;
        _setAddress(KEY_WALLET_SECURITY_RESERVE, a);
    }

    function setWalletBank(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletBank = a;
        _setAddress(KEY_WALLET_BANK, a);
    }

    function setWalletLocker(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletLocker = a;
        _setAddress(KEY_WALLET_LOCKER, a);
    }

    function setWalletLabs(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletLabs = a;
        _setAddress(KEY_WALLET_LABS, a);
    }

    function setWalletAirdrops(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletAirdrops = a;
        _setAddress(KEY_WALLET_AIRDROPS, a);
    }

    function setWalletGame(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletGame = a;
        _setAddress(KEY_WALLET_GAME, a);
    }

    function setWalletMart(address a) external onlyDAOorOwner whenNotPaused {
        require(a != address(0), "MIMHO: zero address");
        walletMart = a;
        _setAddress(KEY_WALLET_MART, a);
    }

    /* =======================================================
                    PARTNERS / LABS (MANUAL)
    ======================================================= */

    function setPartnerService(
        address partner,
        bytes32 serviceId,
        bool allowed,
        uint64 validUntil
    ) external onlyDAOorOwner whenNotPaused {
        require(partner != address(0), "MIMHO: zero partner");
        if (allowed) {
            require(validUntil > uint64(block.timestamp), "MIMHO: invalid expiry");
        } else {
            validUntil = 0;
        }

        partnerServices[partner][serviceId] = PartnerService({
            allowed: allowed,
            validUntil: validUntil
        });

        emit PartnerServiceSet(partner, serviceId, validUntil, allowed);
        _emitHubEvent(ACT_PARTNER_SERVICE, 0, abi.encode(partner, serviceId, allowed, validUntil));
    }

    function isPartnerAuthorized(address partner, bytes32 serviceId) external view returns (bool) {
        PartnerService memory p = partnerServices[partner][serviceId];
        if (!p.allowed) return false;
        if (p.validUntil == 0) return false;
        if (block.timestamp > p.validUntil) return false;
        return true;
    }

    function getPartnerService(address partner, bytes32 serviceId) external view returns (bool allowed, uint64 validUntil) {
        PartnerService memory p = partnerServices[partner][serviceId];
        return (p.allowed, p.validUntil);
    }

    /* =======================================================
                        RESOLVER (REQUIRED)
    ======================================================= */

    function getContract(bytes32 key) external view returns (address) {
        // Core / mandatory
        if (key == KEY_MIMHO_TOKEN) return mimhoToken;
        if (key == KEY_MIMHO_DAO) return dao;
        if (key == KEY_MIMHO_EVENTS_HUB) return address(eventsHub);

        // Security / infra
        if (key == KEY_MIMHO_SECURITY_WALLET) return mimhoSecurityWallet;
        if (key == KEY_MIMHO_VERITAS) return mimhoVeritas;
        if (key == KEY_MIMHO_AUDIT) return mimhoAudit;
        if (key == KEY_MIMHO_GAS_SAVER) return mimhoGasSaver;
        if (key == KEY_MIMHO_OBSERVER) return mimhoObserver;

        // Economy modules (ALL)
        if (key == KEY_MIMHO_STAKING) return mimhoStaking;
        if (key == KEY_MIMHO_PRESALE) return mimhoPresale;
        if (key == KEY_MIMHO_VESTING) return mimhoVesting;
        if (key == KEY_MIMHO_BURN) return mimhoBurn;
        if (key == KEY_MIMHO_LOCKER) return mimhoLocker;
        if (key == KEY_MIMHO_AIRDROP) return mimhoAirdrop;
        if (key == KEY_MIMHO_INVOICE) return mimhoInvoice;
        if (key == KEY_MIMHO_INJECT_LIQUIDITY) return mimhoInjectLiquidity;
        if (key == KEY_MIMHO_TRADING_ACTIVITY) return mimhoTradingActivity;

        // Extra economy / games (ALL)
        if (key == KEY_MIMHO_LOANS) return mimhoLoans;
        if (key == KEY_MIMHO_BET) return mimhoBet;
        if (key == KEY_MIMHO_LOTTERY) return mimhoLottery;
        if (key == KEY_MIMHO_RAFFLE) return mimhoRaffle;
        if (key == KEY_MIMHO_AUCTIONER) return mimhoAuctioner;
        if (key == KEY_MIMHO_PULSE) return mimhoPulse;
        if (key == KEY_MIMHO_QUIZ) return mimhoQuiz;

        // NFT & apps
        if (key == KEY_MIMHO_MART) return mimhoMart;
        if (key == KEY_MIMHO_MARKETPLACE) return mimhoMarketplace;

        // Governance helpers
        if (key == KEY_MIMHO_VOTING_CONTROLLER) return mimhoVotingController;
        if (key == KEY_MIMHO_STRATEGY_HUB) return mimhoStrategyHub;
        if (key == KEY_MIMHO_LIQUIDITY_BOOTSTRAPER) return mimhoLiquidityBootstraper;
        if (key == KEY_MIMHO_HOLDER_DISTRIBUTION) return mimhoHolderDistribution;

        // Optional / extended (ALL)
        if (key == KEY_MIMHO_GATEWAY) return mimhoGateway;
        if (key == KEY_MIMHO_DEX) return mimhoDEX;
        if (key == KEY_MIMHO_SCORE) return mimhoScore;
        if (key == KEY_MIMHO_PERSONA) return mimhoPersona;
        if (key == KEY_MIMHO_BANK) return mimhoBank;
        if (key == KEY_MIMHO_RECEIVE) return mimhoReceive;
        if (key == KEY_MIMHO_PIX) return mimhoPIX;
        if (key == KEY_MIMHO_CERTIFY) return mimhoCertify;

        // Wallets (operational safes)
        if (key == KEY_MIMHO_DAO_WALLET) return walletDAOTreasury;
        if (key == KEY_WALLET_MARKETING) return walletMarketing;
        if (key == KEY_WALLET_TECHNICAL) return walletTechnical;
        if (key == KEY_WALLET_DONATION) return walletDonation;
        if (key == KEY_WALLET_BURN) return walletBurn;
        if (key == KEY_WALLET_LP_RESERVE) return walletLPReserve;
        if (key == KEY_WALLET_LIQUIDITY_RESERVE) return walletLiquidityReserve;
        if (key == KEY_WALLET_SECURITY_RESERVE) return walletSecurityReserve;
        if (key == KEY_WALLET_BANK) return walletBank;
        if (key == KEY_WALLET_LOCKER) return walletLocker;
        if (key == KEY_WALLET_LABS) return walletLabs;
        if (key == KEY_WALLET_AIRDROPS) return walletAirdrops;
        if (key == KEY_WALLET_GAME) return walletGame;
        if (key == KEY_WALLET_MART) return walletMart;

        // LEGACY / TOKEN COMPATIBILITY KEYS (ALIASES)
        if (key == KEY_LP_INJECTOR) return mimhoInjectLiquidity;
        if (key == KEY_STAKING_CONTRACT) return mimhoStaking;
        if (key == KEY_MARKETING_WALLET) return walletMarketing;

        // Alias dao Wallet
        if (key == keccak256("MIMHO_DAO_WALLET")) return walletDAOTreasury;

        return address(0);
    }

    /* =======================================================
                ECOSYSTEM VALIDATION (FOR EVENTS HUB)
       IMPORTANT: CONTRACTS ONLY (NO WALLETS)
    ======================================================= */

    function isEcosystemContract(address a) external view returns (bool) {
        if (a == address(0)) return false;

        return (
            a == mimhoToken ||
            a == dao ||
            a == mimhoSecurityWallet ||
            a == address(eventsHub) ||
            a == mimhoVeritas ||
            a == mimhoStaking ||
            a == mimhoAudit ||
            a == mimhoPulse ||
            a == mimhoGateway ||
            a == mimhoPresale ||
            a == mimhoVesting ||
            a == mimhoBurn ||
            a == mimhoLocker ||
            a == mimhoAirdrop ||
            a == mimhoInvoice ||
            a == mimhoInjectLiquidity ||
            a == mimhoTradingActivity ||
            a == mimhoLoans ||
            a == mimhoBet ||
            a == mimhoLottery ||
            a == mimhoQuiz ||
            a == mimhoRaffle ||
            a == mimhoAuctioner ||
            a == mimhoGasSaver ||
            a == mimhoMart ||
            a == mimhoDEX ||
            a == mimhoScore ||
            a == mimhoPersona ||
            a == mimhoBank ||
            a == mimhoReceive ||
            a == mimhoPIX ||
            a == mimhoCertify ||
            a == mimhoObserver ||
            a == mimhoVotingController ||
            a == mimhoLiquidityBootstraper ||
            a == mimhoHolderDistribution ||
            a == mimhoMarketplace ||
            a == mimhoStrategyHub
        );
    }

    /* =======================================================
                WALLET CONFIG — READ ONLY
   ======================================================= */

    function checkWalletsConfigured() external view returns (bool ok) {
        return (
            walletDAOTreasury != address(0) &&
            walletMarketing != address(0) &&
            walletDonation != address(0) &&
            walletBurn != address(0)
        );
    }

    function checkCoreConfigured() external view returns (bool ok) {
        return (mimhoToken != address(0) && dao != address(0) && address(eventsHub) != address(0));
    }

    function getWallets()
        external
        view
        returns (
            address daoTreasury,
            address marketing,
            address donation,
            address burn
        )
    {
        return (
            walletDAOTreasury,
            walletMarketing,
            walletDonation,
            walletBurn
        );
    }

    /* =======================================================
                IMIMHOProtocol — REQUIRED BUTTONS / VIEWS
    ======================================================= */

    function contractName() external pure override returns (string memory) {
        return "MIMHO Registry";
    }

    function contractType() external pure override returns (bytes32) {
        return CONTRACT_TYPE;
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    function isObservable() external pure override returns (bool) {
        return true;
    }

    function getActionType() external pure override returns (bytes32) {
        return ACTION_TYPE;
    }

    function getRiskLevel() external pure override returns (uint8) {
        return 0;
    }

    function isFinalized() external view override returns (bool) {
        return false;
    }

    function getFinancialImpact(address) external view override returns (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue) {
        return (0, 0, 0);
    }

    function getBoostValue(address) external view override returns (uint256) {
        return 0;
    }

    function onExternalAction(address, bytes32) external override {
        // intentionally empty
    }
}
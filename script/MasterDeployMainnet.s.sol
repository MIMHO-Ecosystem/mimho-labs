// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import {MIMHORegistry} from "../src/registry.sol";
import {MIMHOEventsHub} from "../src/eventshub.sol";
import {MIMHO} from "../src/token.sol";
import {MIMHOInjectLiquidity} from "../src/injectliquidity.sol";
import {MIMHOInjectLiquidityVotingController} from "../src/votingcontroller.sol";
import {MIMHOStaking} from "../src/staking.sol";
import {MIMHOVesting} from "../src/vesting.sol";
import {MIMHOPresale} from "../src/presale.sol";
import {MIMHOLiquidityBootstrapper} from "../src/liquiditybootstrapper.sol";
import {MIMHODaoGovernance} from "../src/dao.sol";
import {MIMHOBurnGovernanceVault} from "../src/burn.sol";
import {MIMHOHolderDistributionVault} from "../src/holderdistribution.sol";
import {MIMHOAirdrop} from "../src/airdrop.sol";
import {MIMHOLocker} from "../src/locker.sol";
import {MIMHOMarketplace} from "../src/marketplace.sol";
import {MIMHOMart} from "../src/mart.sol";
import {MIMHOQuiz} from "../src/quizacademy.sol";
import {MIMHOStrategyHub} from "../src/strategyhub.sol";
import {MIMHOTradingActivity} from "../src/tradingactivity.sol";

contract MasterDeployMainnet is Script {
    /*//////////////////////////////////////////////////////////////
                              SAFES / WALLETS
    //////////////////////////////////////////////////////////////*/

    address public founderSafe;
    address public daoSafe;
    address public marketingSafe;
    address public liquidityReserveSafe;

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    /*//////////////////////////////////////////////////////////////
                           PANCAKESWAP MAINNET
    //////////////////////////////////////////////////////////////*/

    // PancakeSwap v2 Periphery Router on BNB Smart Chain mainnet
    address constant PANCAKE_V2_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    /*//////////////////////////////////////////////////////////////
                           PRESALE (FROZEN)
    //////////////////////////////////////////////////////////////*/

    uint64  constant SALE_START = 1775480400; // 06/04/2026 10:00 America/Sao_Paulo
    uint64  constant SALE_END   = 1776690000; // 20/04/2026 10:00 America/Sao_Paulo

    uint256 constant MIN_BUY_WEI             = 0.05 ether;
    uint256 constant MAX_BUY_PER_WALLET_WEI  = 5 ether;
    uint256 constant HARD_CAP_WEI            = 150 ether;

    uint256 constant TOKENS_FOR_SALE         = 100_000_000_000 ether; // 100B
    uint16  constant TGE_BPS                 = 2000; // 20%
    uint16  constant WEEKLY_BPS              = 500;  // 5%

    // 150 BNB / 100B MIMHO => 1.5e9 wei per token
    uint256 constant PRESALE_PRICE_WEI_PER_TOKEN = 1_500_000_000;

    /*//////////////////////////////////////////////////////////////
                           STAKING (FROZEN)
    //////////////////////////////////////////////////////////////*/

    uint256 constant STAKE_MIN_AMOUNT            = 100_000 ether;
    uint256 constant STAKE_MIN_HOLD              = 7 days;
    uint256 constant STAKE_CLAIM_COOLDOWN        = 7 days;
    uint256 constant STAKE_WEEKLY_LIMIT          = 25_000_000 ether;
    uint256 constant STAKE_MAX_CLAIM_BPS_WEEK    = 3500;
    uint256 constant STAKE_BASE_APY_TOP          = 4000;
    uint256 constant STAKE_MAX_TOTAL_APY         = 6500;
    uint256 constant STAKE_MAX_BOOST_BPS         = 2500;

    uint256 constant STAKE_PROMISED_PHASE_DURATION = 90 days;
    uint256 constant STAKE_ANNUAL_CAP_PROMISED    = 65_000_000 ether;

    /*//////////////////////////////////////////////////////////////
                      VOTING CONTROLLER (FROZEN)
    //////////////////////////////////////////////////////////////*/

    uint256 constant VC_MIN_BALANCE     = 10_000_000 ether;
    uint256 constant VC_VOTE_COOLDOWN   = 7 days;
    uint256 constant VC_PREPARE_DURATION = 3 days;
    uint256 constant VC_VOTE_DURATION    = 3 days;

    /*//////////////////////////////////////////////////////////////
                       INJECT LIQUIDITY (FROZEN)
    //////////////////////////////////////////////////////////////*/

    uint256 constant INJECT_COOLDOWN   = 7 days;
    uint256 constant INJECT_FAILSAFE   = 180 days;
    bool    constant INJECT_AUTO_START = false;

    /*//////////////////////////////////////////////////////////////
                         DAO GOVERNANCE (DEFAULTS)
    //////////////////////////////////////////////////////////////*/

    uint256 constant DAO_MIN_TOKENS_TO_VOTE      = 10_000_000 ether;
    uint256 constant DAO_MIN_TOKENS_TO_CANDIDATE = 100_000_000 ether;
    uint256 constant DAO_MAX_BONUS_PERCENT       = 25;

    /*//////////////////////////////////////////////////////////////
                            AIRDROP (DEFAULTS)
    //////////////////////////////////////////////////////////////*/

    uint256 constant AIRDROP_CYCLE_DURATION = 30 days;
    uint256 constant AIRDROP_ABSOLUTE_CAP   = 5_000_000_000 ether;
    uint256 constant AIRDROP_MIN_USD_18     = 10 ether;

    /*//////////////////////////////////////////////////////////////
                              MART DEFAULTS
    //////////////////////////////////////////////////////////////*/

    string constant MART_NAME   = "MIMHO Mart";
    string constant MART_SYMBOL = "MART";

    /*//////////////////////////////////////////////////////////////
                              ADDRESSES OUT
    //////////////////////////////////////////////////////////////*/

    MIMHORegistry public registry;
    MIMHOEventsHub public eventsHub;
    MIMHO public token;
    MIMHOInjectLiquidity public injectLiquidity;
    MIMHOInjectLiquidityVotingController public votingController;
    MIMHOStaking public staking;
    MIMHOVesting public vesting;
    MIMHOPresale public presale;
    MIMHOLiquidityBootstrapper public liquidityBootstrapper;
    MIMHODaoGovernance public daoGov;
    MIMHOBurnGovernanceVault public burnVault;
    MIMHOHolderDistributionVault public holderDistribution;
    MIMHOAirdrop public airdrop;
    MIMHOLocker public locker;
    MIMHOMarketplace public marketplace;
    MIMHOMart public mart;
    MIMHOQuiz public quiz;
    MIMHOStrategyHub public strategyHub;
    MIMHOTradingActivity public tradingActivity;

    function run() external {
        founderSafe = vm.envAddress("FOUNDER_SAFE");
        daoSafe = vm.envAddress("DAO_SAFE");
        marketingSafe = vm.envAddress("MARKETING_SAFE");
        liquidityReserveSafe = vm.envAddress("LIQUIDITY_RESERVE_SAFE");

        vm.startBroadcast(founderSafe);

        /* ============================================================
                           1. REGISTRY
        ============================================================ */

        registry = new MIMHORegistry(founderSafe);

        /* ============================================================
                           2. EVENTS HUB
        ============================================================ */

        eventsHub = new MIMHOEventsHub(founderSafe, address(registry));

        /* ============================================================
                           3. TOKEN
        ============================================================ */

        token = new MIMHO();

        /* ============================================================
                   3.1 EARLY REGISTRY SETUP (REQUIRED)
        ============================================================ */

        registry.setEventsHub(address(eventsHub));
        registry.setMIMHOToken(address(token));

        /* ============================================================
                           4. STRATEGY HUB
        ============================================================ */

        strategyHub = new MIMHOStrategyHub(address(registry));

        /* ============================================================
                           5. INJECT LIQUIDITY
        ============================================================ */

        injectLiquidity = new MIMHOInjectLiquidity(
            address(registry),
            founderSafe
        );

        /* ============================================================
                        6. VOTING CONTROLLER
        ============================================================ */

        votingController = new MIMHOInjectLiquidityVotingController(
            address(registry)
        );

        /* ============================================================
                             7. STAKING
        ============================================================ */

        staking = new MIMHOStaking(address(registry));

        /* ============================================================
                              8. VESTING
        ============================================================ */

        vesting = new MIMHOVesting(
            address(token),
            address(registry)
        );

        /* ============================================================
                              9. PRESALE
        ============================================================ */

        presale = new MIMHOPresale(address(registry));

        /* ============================================================
                       10. LIQUIDITY BOOTSTRAPPER
        ============================================================ */

        liquidityBootstrapper = new MIMHOLiquidityBootstrapper(
            address(registry),
            address(token),
            PANCAKE_V2_ROUTER,
            address(presale),
            DEAD,
            PRESALE_PRICE_WEI_PER_TOKEN
        );

        /* ============================================================
                           11. DAO GOVERNANCE
        ============================================================ */

        daoGov = new MIMHODaoGovernance(
            address(registry),
            DAO_MIN_TOKENS_TO_VOTE,
            DAO_MIN_TOKENS_TO_CANDIDATE,
            DAO_MAX_BONUS_PERCENT
        );

        /* ============================================================
                           12. BURN VAULT
        ============================================================ */

        burnVault = new MIMHOBurnGovernanceVault(address(registry));

        /* ============================================================
                     13. HOLDER DISTRIBUTION
        ============================================================ */

        holderDistribution = new MIMHOHolderDistributionVault(
            address(registry),
            address(token)
        );

        /* ============================================================
                              14. AIRDROP
        ============================================================ */

        airdrop = new MIMHOAirdrop(
            address(registry),
            marketingSafe,
            AIRDROP_CYCLE_DURATION,
            AIRDROP_ABSOLUTE_CAP,
            AIRDROP_MIN_USD_18
        );

        /* ============================================================
                               15. LOCKER
        ============================================================ */

        locker = new MIMHOLocker(address(registry));

        /* ============================================================
                             16. MARKETPLACE
        ============================================================ */

        marketplace = new MIMHOMarketplace(address(registry));

        /* ============================================================
                                17. MART
        ============================================================ */

        mart = new MIMHOMart(
            address(registry),
            MART_NAME,
            MART_SYMBOL
        );

        /* ============================================================
                               18. QUIZ
        ============================================================ */

        quiz = new MIMHOQuiz(address(registry));

        /* ============================================================
                          19. TRADING ACTIVITY
        ============================================================ */

        tradingActivity = new MIMHOTradingActivity(address(registry));

        /* ============================================================
                          20. REGISTRY: CORE
        ============================================================ */

        registry.setContract(registry.KEY_MIMHO_INJECT_LIQUIDITY(), address(injectLiquidity));
        registry.setContract(registry.KEY_MIMHO_VOTING_CONTROLLER(), address(votingController));
        registry.setContract(registry.KEY_MIMHO_STAKING(), address(staking));
        registry.setContract(registry.KEY_MIMHO_VESTING(), address(vesting));
        registry.setContract(registry.KEY_MIMHO_PRESALE(), address(presale));
        registry.setContract(registry.KEY_MIMHO_LIQUIDITY_BOOTSTRAPER(), address(liquidityBootstrapper));

        /* ============================================================
                       21. REGISTRY: ECOSYSTEM MODULES
        ============================================================ */

        registry.setContract(registry.KEY_MIMHO_BURN(), address(burnVault));
        registry.setContract(registry.KEY_MIMHO_HOLDER_DISTRIBUTION(), address(holderDistribution));
        registry.setContract(registry.KEY_MIMHO_AIRDROP(), address(airdrop));
        registry.setContract(registry.KEY_MIMHO_LOCKER(), address(locker));
        registry.setContract(registry.KEY_MIMHO_MARKETPLACE(), address(marketplace));
        registry.setContract(registry.KEY_MIMHO_MART(), address(mart));
        registry.setContract(registry.KEY_MIMHO_QUIZ(), address(quiz));
        registry.setContract(registry.KEY_MIMHO_STRATEGY_HUB(), address(strategyHub));
        registry.setContract(registry.KEY_MIMHO_TRADING_ACTIVITY(), address(tradingActivity));

        /* ============================================================
                         22. REGISTRY: WALLET KEYS
        ============================================================ */

        registry.setWallet(registry.KEY_MIMHO_DAO_WALLET(), daoSafe);
        registry.setWallet(registry.KEY_WALLET_MARKETING(), marketingSafe);
        registry.setWallet(registry.KEY_WALLET_LIQUIDITY_RESERVE(), liquidityReserveSafe);

        /* ============================================================
                             23. SET DAO
        ============================================================ */

        registry.setDAO(daoSafe);

        token.setDAO(daoSafe);
        injectLiquidity.setDAO(daoSafe);
        votingController.setDAO(daoSafe);
        staking.setDAO(daoSafe);
        presale.setDAO(daoSafe);
        liquidityBootstrapper.setDAO(daoSafe);

        daoGov.setDAO(daoSafe);
        burnVault.setDAO(daoSafe);
        holderDistribution.setDAO(daoSafe);
        airdrop.setDAO(daoSafe);
        locker.setDAO(daoSafe);
        marketplace.setDAO(daoSafe);
        mart.setDAO(daoSafe);
        strategyHub.setDAO(daoSafe);
        tradingActivity.setDAO(daoSafe);

        // EventsHub supports DAO assignment too
        eventsHub.setDAO(daoSafe);

        /* ============================================================
                    24. POST-DEPLOY LINKS / SYNC
        ============================================================ */

        token.setRegistry(address(registry));

        presale.syncFromRegistry();
        vesting.setPresaleContract(address(presale));

        /* ============================================================
                         25. STAKING PARAMS
        ============================================================ */

        staking.setParams(
            STAKE_MIN_AMOUNT,
            STAKE_MIN_HOLD,
            STAKE_CLAIM_COOLDOWN,
            STAKE_WEEKLY_LIMIT,
            STAKE_MAX_CLAIM_BPS_WEEK,
            STAKE_BASE_APY_TOP,
            STAKE_MAX_TOTAL_APY,
            STAKE_MAX_BOOST_BPS
        );

        staking.setPromisedPhase(
            block.timestamp + STAKE_PROMISED_PHASE_DURATION,
            STAKE_ANNUAL_CAP_PROMISED
        );

        /* ============================================================
                     26. VOTING CONTROLLER PARAMS
        ============================================================ */

        votingController.setMinBalance(VC_MIN_BALANCE);
        votingController.setVoteCooldown(VC_VOTE_COOLDOWN);

        /* ============================================================
                      27. INJECT LIQUIDITY PARAMS
        ============================================================ */

        injectLiquidity.setInjectionCooldown(INJECT_COOLDOWN);
        injectLiquidity.setFailsafeDelay(INJECT_FAILSAFE);

        if (INJECT_AUTO_START) {
            injectLiquidity.setAutoInject(true);
        }

        /* ============================================================
                         28. LOG DEPLOY SUMMARY
        ============================================================ */

        console2.log("REGISTRY:", address(registry));
        console2.log("EVENTS_HUB:", address(eventsHub));
        console2.log("TOKEN:", address(token));
        console2.log("INJECT_LIQUIDITY:", address(injectLiquidity));
        console2.log("VOTING_CONTROLLER:", address(votingController));
        console2.log("STAKING:", address(staking));
        console2.log("VESTING:", address(vesting));
        console2.log("PRESALE:", address(presale));
        console2.log("LIQUIDITY_BOOTSTRAPPER:", address(liquidityBootstrapper));
        console2.log("DAO_GOV:", address(daoGov));
        console2.log("BURN_VAULT:", address(burnVault));
        console2.log("HOLDER_DISTRIBUTION:", address(holderDistribution));
        console2.log("AIRDROP:", address(airdrop));
        console2.log("LOCKER:", address(locker));
        console2.log("MARKETPLACE:", address(marketplace));
        console2.log("MART:", address(mart));
        console2.log("QUIZ:", address(quiz));
        console2.log("STRATEGY_HUB:", address(strategyHub));
        console2.log("TRADING_ACTIVITY:", address(tradingActivity));

        vm.stopBroadcast();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

import * as REG from "../src/registry.sol";
import * as HUB from "../src/eventshub.sol";
import * as TOK from "../src/token.sol";
import * as DAO from "../src/dao.sol";
import * as STK from "../src/staking.sol";
import * as VEST from "../src/vesting.sol";
import * as PRE from "../src/presale.sol";
import * as LOCK from "../src/locker.sol";
import * as MKT from "../src/marketplace.sol";
import * as MART from "../src/mart.sol";
import * as BURN from "../src/burn.sol";
import * as HD from "../src/holderdistribution.sol";
import * as INJ from "../src/injectliquidity.sol";
import * as SH from "../src/strategyhub.sol";
import * as TA from "../src/tradingactivity.sol";
import * as QUIZ from "../src/quizacademy.sol";
import * as VC from "../src/votingcontroller.sol";
import * as AIR from "../src/airdrop.sol";

contract MasterDeploy is Script {
    // wallets oficiais
    address constant FOUNDER_SAFE  = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address constant DAO_WALLET    = 0x63dd2eB7250612Ef7Dc24193ABbf7856fDaB7882;
    address constant MARKETING     = 0x34C561E00fEBB1FEbB461C21934F7d3609D122E2;
    address constant LP_RESERVE    = 0x66789aB0861A1979df2fCCB1053Ca76BB61c1248;
    address constant TECHNICAL     = 0x12a662CD95b8CCF92386f7505e2e54aF33550c6a;
    address constant LIQ_RESERVE   = 0xb891C4e94a1F4B7Aa35d21BbA37D245909B6ad95;
    address constant DONATION      = 0x7149Bf2EA785C2D414c8eC6409F472dFaf95a06f;
    address constant BURN_WALLET   = 0x57357EF9025d5cB435121ceF5f45f761E16ff56A;
    address constant SEC_RESERVE   = 0xc7B097384fe490B88D2d6EB032B1db702374C5eE;
    address constant MART_WALLET   = 0x026b6994E25B5602b8c7525dD0dCb1eC41c5D275;
    address constant BANK_WALLET   = 0x802DbeB782E1AA63fac20B4DA1723144089067C6;
    address constant LOCKER_WALLET = 0xFb794A6147dC7d70E626808563a7936c75A12016;
    address constant LABS_WALLET   = 0x5E2a01BBE5687aBCfa8dfeD9C5cC7Fc7bEaf2432;
    address constant AIRDROPS_WAL  = 0x15512E6331a6AaDa1221180Eb571fd41FBfFdEEA;
    address constant GAME_WALLET   = 0x291641d158eb053b9315482375F092D7C20c83Cd;

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(pk);

        vm.startBroadcast(pk);

        // =====================================================
        // 1) CORE
        // =====================================================

        REG.MIMHORegistry registry = new REG.MIMHORegistry(deployer);
        console2.log("Registry:", address(registry));

        HUB.MIMHOEventsHub hub = new HUB.MIMHOEventsHub(deployer, address(registry));
        console2.log("EventsHub:", address(hub));

        registry.setEventsHub(address(hub));

        TOK.MIMHO token = new TOK.MIMHO();
        console2.log("Token:", address(token));

        token.setRegistry(address(registry));
        registry.setMIMHOToken(address(token));

        // =====================================================
        // 2) WALLETS
        // =====================================================

        registry.setWallet(registry.KEY_MIMHO_DAO_WALLET(), DAO_WALLET);
        registry.setWallet(registry.KEY_WALLET_MARKETING(), MARKETING);
        registry.setWallet(registry.KEY_WALLET_TECHNICAL(), TECHNICAL);
        registry.setWallet(registry.KEY_WALLET_DONATION(), DONATION);
        registry.setWallet(registry.KEY_WALLET_BURN(), BURN_WALLET);
        registry.setWallet(registry.KEY_WALLET_LP_RESERVE(), LP_RESERVE);
        registry.setWallet(registry.KEY_WALLET_LIQUIDITY_RESERVE(), LIQ_RESERVE);
        registry.setWallet(registry.KEY_WALLET_SECURITY_RESERVE(), SEC_RESERVE);
        registry.setWallet(registry.KEY_WALLET_BANK(), BANK_WALLET);
        registry.setWallet(registry.KEY_WALLET_LOCKER(), LOCKER_WALLET);
        registry.setWallet(registry.KEY_WALLET_LABS(), LABS_WALLET);
        registry.setWallet(registry.KEY_WALLET_AIRDROPS(), AIRDROPS_WAL);
        registry.setWallet(registry.KEY_WALLET_GAME(), GAME_WALLET);
        registry.setWallet(registry.KEY_WALLET_MART(), MART_WALLET);

        // =====================================================
        // 3) GOVERNANCE / HELPERS
        // =====================================================

        DAO.MIMHODaoGovernance dao = new DAO.MIMHODaoGovernance(
            address(registry),
            1_000_000 ether,
            5_000_000 ether,
            20
        );
        console2.log("DAO:", address(dao));
        registry.setDAO(address(dao));

        VC.MIMHOInjectLiquidityVotingController voting = new VC.MIMHOInjectLiquidityVotingController(address(registry));
        console2.log("VotingController:", address(voting));
        registry.setContract(registry.KEY_MIMHO_VOTING_CONTROLLER(), address(voting));

        SH.MIMHOStrategyHub strategyHub = new SH.MIMHOStrategyHub(address(registry));
        console2.log("StrategyHub:", address(strategyHub));
        registry.setContract(registry.KEY_MIMHO_STRATEGY_HUB(), address(strategyHub));

        TA.MIMHOTradingActivity trading = new TA.MIMHOTradingActivity(address(registry));
        console2.log("TradingActivity:", address(trading));
        registry.setContract(registry.KEY_MIMHO_TRADING_ACTIVITY(), address(trading));

        // =====================================================
        // 4) ECONOMY
        // =====================================================

        STK.MIMHOStaking staking = new STK.MIMHOStaking(address(registry));
        console2.log("Staking:", address(staking));
        registry.setContract(registry.KEY_MIMHO_STAKING(), address(staking));

        VEST.MIMHOVesting vesting = new VEST.MIMHOVesting(address(token), address(registry));
        console2.log("Vesting:", address(vesting));
        registry.setContract(registry.KEY_MIMHO_VESTING(), address(vesting));

        PRE.MIMHOPresale presale = new PRE.MIMHOPresale(address(registry));
        console2.log("Presale:", address(presale));
        registry.setContract(registry.KEY_MIMHO_PRESALE(), address(presale));

        LOCK.MIMHOLocker locker = new LOCK.MIMHOLocker(address(registry));
        console2.log("Locker:", address(locker));
        registry.setContract(registry.KEY_MIMHO_LOCKER(), address(locker));

        BURN.MIMHOBurnGovernanceVault burn = new BURN.MIMHOBurnGovernanceVault(address(registry));
        console2.log("Burn:", address(burn));
        registry.setContract(registry.KEY_MIMHO_BURN(), address(burn));

        HD.MIMHOHolderDistributionVault holderDistribution =
            new HD.MIMHOHolderDistributionVault(address(registry), address(token));
        console2.log("HolderDistribution:", address(holderDistribution));
        registry.setContract(registry.KEY_MIMHO_HOLDER_DISTRIBUTION(), address(holderDistribution));

        INJ.MIMHOInjectLiquidity inject = new INJ.MIMHOInjectLiquidity(address(registry), deployer);
        console2.log("InjectLiquidity:", address(inject));
        registry.setContract(registry.KEY_MIMHO_INJECT_LIQUIDITY(), address(inject));

        // =====================================================
        // 5) NFT / APPS
        // =====================================================

        MART.MIMHOMart mart = new MART.MIMHOMart(address(registry), "MIMHO Mart", "MIMART");
        console2.log("Mart:", address(mart));
        registry.setContract(registry.KEY_MIMHO_MART(), address(mart));

        MKT.MIMHOMarketplace marketplace = new MKT.MIMHOMarketplace(address(registry));
        console2.log("Marketplace:", address(marketplace));
        registry.setContract(registry.KEY_MIMHO_MARKETPLACE(), address(marketplace));

        QUIZ.MIMHOQuiz quiz = new QUIZ.MIMHOQuiz(address(registry));
        console2.log("Quiz:", address(quiz));
        registry.setContract(registry.KEY_MIMHO_QUIZ(), address(quiz));

        AIR.MIMHOAirdrop airdrop = new AIR.MIMHOAirdrop(
            address(registry),
            MARKETING,
            30 days,
            10_000_000 ether,
            10 ether
        );
        console2.log("Airdrop:", address(airdrop));
        registry.setContract(registry.KEY_MIMHO_AIRDROP(), address(airdrop));

        vm.stopBroadcast();
    }
}

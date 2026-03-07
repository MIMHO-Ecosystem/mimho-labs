// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";

// IMPORTS DOS SEUS CONTRATOS (ajuste nomes se necessário)
import "../src/registry.sol";
import "../src/eventshub.sol";
import "../src/token.sol";

// Os demais (vamos ligar todos aqui e ajustar construtores conforme o build reclamar)
import "../src/dao.sol";
import "../src/staking.sol";
import "../src/vesting.sol";
import "../src/presale.sol";
import "../src/locker.sol";
import "../src/marketplace.sol";
import "../src/mart.sol";
import "../src/burn.sol";
import "../src/holderdistribution.sol";
import "../src/injectliquidity.sol";
import "../src/liquiditybootstrapper.sol";
import "../src/strategyhub.sol";
import "../src/tradingactivity.sol";
import "../src/quizacademy.sol";
import "../src/votingcontroller.sol";
import "../src/airdrop.sol";

contract DeployAll is Script {
    // Carteiras oficiais (as suas)
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

        // ---------------------------------------------------------------------
        // 1) REGISTRY
        // Obs: No Anvil, "owner" precisa ser o deployer (EOA). Em mainnet, Safe.
        // Então no teste local a gente usa deployer como "founderSafeOwner" do contrato.
        // ---------------------------------------------------------------------
        MIMHORegistry registry = new MIMHORegistry(deployer);
        console2.log("Registry:", address(registry));

        // ---------------------------------------------------------------------
        // 2) EVENTS HUB
        // ---------------------------------------------------------------------
        MIMHOEventsHub hub = new MIMHOEventsHub(deployer, address(registry));
        console2.log("EventsHub:", address(hub));

        // Registry -> set hub
        registry.setEventsHub(address(hub));

        // ---------------------------------------------------------------------
        // 3) TOKEN
        // ---------------------------------------------------------------------
        MIMHO token = new MIMHO();
        console2.log("Token:", address(token));

        // Token -> set registry
        token.setRegistry(address(registry));

        // Registry -> set token + wallets base (as que existirem no seu Registry)
        registry.setMIMHOToken(address(token));

        registry.setWalletDAOTreasury(DAO_WALLET);
        registry.setWalletMarketing(MARKETING);
        registry.setWalletTechnical(TECHNICAL);
        registry.setWalletDonation(DONATION);
        registry.setWalletBurn(BURN_WALLET);
        registry.setWalletLPReserve(LP_RESERVE);
        registry.setWalletLiquidityReserve(LIQ_RESERVE);
        registry.setWalletSecurityReserve(SEC_RESERVE);
        registry.setWalletBank(BANK_WALLET);
        registry.setWalletLocker(LOCKER_WALLET);
        registry.setWalletLabs(LABS_WALLET);
        registry.setWalletAirdrops(AIRDROPS_WAL);
        registry.setWalletGame(GAME_WALLET);
        registry.setWalletMart(MART_WALLET);

        // ---------------------------------------------------------------------
        // 4) DEMAIS MÓDULOS (19 total)
        // AQUI: vamos compilar, e se algum construtor não bater, o forge vai apontar.
        // Aí a gente ajusta 1 por vez até completar 19/19.
        // ---------------------------------------------------------------------

        // exemplos “prováveis”: muitos contratos recebem registry no construtor.
        // Se algum não recebe, o build vai reclamar e a gente ajusta.

        MIMHODaoGovernance dao = new MIMHODaoGovernance(address(registry));
        console2.log("DAO:", address(dao));
        registry.setMIMHODAO(address(dao)); // se existir no seu registry; se não existir, o build vai apontar

        MIMHOStaking staking = new MIMHOStaking(address(registry));
        console2.log("Staking:", address(staking));
        registry.setMIMHOStaking(address(staking));

        MIMHOVesting vesting = new MIMHOVesting(address(registry));
        console2.log("Vesting:", address(vesting));
        registry.setMIMHOVesting(address(vesting));

        MIMHOPresale presale = new MIMHOPresale(address(registry));
        console2.log("Presale:", address(presale));
        registry.setMIMHOPresale(address(presale));

        MIMHOLocker locker = new MIMHOLocker(address(registry));
        console2.log("Locker:", address(locker));
        registry.setMIMHOLocker(address(locker));

        MIMHOMarketplace marketplace = new MIMHOMarketplace(address(registry));
        console2.log("Marketplace:", address(marketplace));
        registry.setMIMHOMarketplace(address(marketplace));

        MIMHOMart mart = new MIMHOMart(address(registry));
        console2.log("Mart:", address(mart));
        registry.setMIMHOMart(address(mart));

        MIMHOBurnGovernanceVault burn = new MIMHOBurnGovernanceVault(address(registry));
        console2.log("Burn:", address(burn));
        registry.setMIMHOBurn(address(burn));

        MIMHOHolderDistributionVault holderDist = new MIMHOHolderDistributionVault(address(registry));
        console2.log("HolderDistribution:", address(holderDist));
        registry.setMIMHOHolderDistribution(address(holderDist));

        MIMHOInjectLiquidity inject = new MIMHOInjectLiquidity(address(registry));
        console2.log("InjectLiquidity:", address(inject));
        registry.setMIMHOInjectLiquidity(address(inject));

        MIMHOLiquidityBootstrapper lb = new MIMHOLiquidityBootstrapper(address(registry));
        console2.log("LiquidityBootstrapper:", address(lb));
        registry.setMIMHOLiquidityBootstraper(address(lb));

        MIMHOStrategyHub strategyHub = new MIMHOStrategyHub(address(registry));
        console2.log("StrategyHub:", address(strategyHub));
        registry.setMIMHOStrategyHub(address(strategyHub));

        MIMHOTradingActivity trading = new MIMHOTradingActivity(address(registry));
        console2.log("TradingActivity:", address(trading));
        registry.setMIMHOTradingActivity(address(trading));

        MIMHOQuiz quiz = new MIMHOQuiz(address(registry));
        console2.log("Quiz:", address(quiz));
        registry.setMIMHOQuiz(address(quiz));

        MIMHOInjectLiquidityVotingController voting = new MIMHOInjectLiquidityVotingController(address(registry));
        console2.log("VotingController:", address(voting));
        registry.setMIMHOVotingController(address(voting));

        MIMHOAirdrop airdrop = new MIMHOAirdrop(address(registry));
        console2.log("Airdrop:", address(airdrop));
        registry.setMIMHOAirdrop(address(airdrop));

        // 19 módulos: se faltar algum, a gente adiciona aqui.
        // (Veritas, Certify, Observer, Persona etc. se já existirem no repo.)

        vm.stopBroadcast();
    }
}

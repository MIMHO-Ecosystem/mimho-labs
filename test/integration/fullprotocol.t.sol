// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// ✅ importe SOMENTE 1 arquivo para evitar colisão de interfaces duplicadas
import "../../src/token.sol";

// --------- Interfaces mínimas (nomes ÚNICOS) ---------
interface IRegistryLike {
    function setMIMHOToken(address token) external;
    function setMIMHOStaking(address staking) external;
    function setMIMHOHolderDistribution(address holderDistribution) external;
    function setMIMHOEventsHub(address hub) external;

    function setWalletDAOTreasury(address a) external;
    function setWalletMarketing(address a) external;
    function setWalletTechnical(address a) external;
    function setWalletDonation(address a) external;
    function setWalletBurn(address a) external;
    function setWalletLPReserve(address a) external;
    function setWalletLiquidityReserve(address a) external;
    function setWalletSecurityReserve(address a) external;
    function setWalletBank(address a) external;
    function setWalletLocker(address a) external;
    function setWalletLabs(address a) external;
    function setWalletAirdrops(address a) external;
    function setWalletGame(address a) external;
    function setWalletMart(address a) external;
}

interface IStakingLike {
    function stake(uint256 amount) external;
    function claim() external;
}

interface IHolderDistributionLike {
    function deposit(uint256 amount) external;
    function openRound(bytes32 merkleRoot, uint64 claimStart, uint64 claimEnd) external;
    function claim(uint256 roundId, uint256 amount, bytes32[] calldata proof) external;
}

contract FullProtocolTest is Test {
    // Endereços dummy para teste
    address founder = address(0x100);
    address user    = address(0x200);

    // contratos
    MIMHO token;

    // ⚠️ Aqui você coloca os endereços reais quando for testar de verdade
    // (ou você pode importar e instanciar contratos reais, mas aí volta a colisão)
    IRegistryLike registry = IRegistryLike(address(0x300));
    IStakingLike staking   = IStakingLike(address(0x400));
    IHolderDistributionLike dist = IHolderDistributionLike(address(0x500));

    function setUp() public {
        vm.startPrank(founder);

        // Token exige registry no construtor
        token = new MIMHO();

        vm.stopPrank();
    }

    function testSmoke_TokenTransfer() public {
        vm.startPrank(founder);

        token.transfer(user, 1_000_000 * 1e18);

        vm.stopPrank();

        assertEq(token.balanceOf(user), 1_000_000 * 1e18);
    }
}

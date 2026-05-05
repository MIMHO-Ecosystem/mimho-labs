// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../src/registry.sol";

contract EchidnaRegistry {
    MIMHORegistry public registry;

    address public dao = address(0xDA0);

    address[] private contractValues;
    address[] private walletValues;

    bytes32[] private contractKeys;
    bytes32[] private walletKeys;

    constructor() {
        registry = new MIMHORegistry(address(this));

        registry.setDAO(dao);

        contractValues.push(address(0xC001));
        contractValues.push(address(0xC002));
        contractValues.push(address(0xC003));
        contractValues.push(address(0xC004));
        contractValues.push(address(0xC005));
        contractValues.push(address(0xC006));
        contractValues.push(address(0xC007));

        walletValues.push(address(0xA001));
        walletValues.push(address(0xA002));
        walletValues.push(address(0xA003));
        walletValues.push(address(0xA004));
        walletValues.push(address(0xA005));
        walletValues.push(address(0xA006));
        walletValues.push(address(0xA007));

        contractKeys.push(registry.KEY_MIMHO_STAKING());
        contractKeys.push(registry.KEY_MIMHO_LOCKER());
        contractKeys.push(registry.KEY_MIMHO_AIRDROP());
        contractKeys.push(registry.KEY_MIMHO_BURN());
        contractKeys.push(registry.KEY_MIMHO_INJECT_LIQUIDITY());
        contractKeys.push(registry.KEY_MIMHO_MART());
        contractKeys.push(registry.KEY_MIMHO_MARKETPLACE());
        contractKeys.push(registry.KEY_MIMHO_STRATEGY_HUB());
        contractKeys.push(registry.KEY_MIMHO_GATEWAY());

        walletKeys.push(registry.KEY_MIMHO_DAO_WALLET());
        walletKeys.push(registry.KEY_WALLET_MARKETING());
        walletKeys.push(registry.KEY_WALLET_DONATION());
        walletKeys.push(registry.KEY_WALLET_BURN());
        walletKeys.push(registry.KEY_WALLET_TECHNICAL());
        walletKeys.push(registry.KEY_WALLET_LP_RESERVE());
        walletKeys.push(registry.KEY_WALLET_SECURITY_RESERVE());
    }

    function actionSetContract(uint8 keySeed, uint8 valueSeed) external {
        bytes32 key = contractKeys[keySeed % contractKeys.length];
        address value = contractValues[valueSeed % contractValues.length];

        try registry.setContract(key, value) {} catch {}
    }

    function actionSetWallet(uint8 keySeed, uint8 valueSeed) external {
        bytes32 key = walletKeys[keySeed % walletKeys.length];
        address value = walletValues[valueSeed % walletValues.length];

        try registry.setWallet(key, value) {} catch {}
    }

    function actionSetToken(uint8 valueSeed) external {
        address value = contractValues[valueSeed % contractValues.length];

        try registry.setMIMHOToken(value) {} catch {}
    }

    function actionSetEventsHub(uint8 valueSeed) external {
        address value = contractValues[valueSeed % contractValues.length];

        try registry.setEventsHub(value) {} catch {}
    }

    function actionSetPartnerService(uint8 partnerSeed, uint8 serviceSeed, uint32 durationSeed) external {
        address partner = contractValues[partnerSeed % contractValues.length];
        bytes32 serviceId = keccak256(abi.encodePacked("SERVICE", serviceSeed));

        uint64 validUntil = uint64(block.timestamp + _bound(uint256(durationSeed), 1 days, 365 days));

        try registry.setPartnerService(partner, serviceId, true, validUntil) {} catch {}
    }

    function echidna_core_config_matches_storage() external view returns (bool) {
        bool expected =
            registry.getContract(registry.KEY_MIMHO_TOKEN()) != address(0) &&
            registry.getContract(registry.KEY_MIMHO_DAO()) != address(0) &&
            registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()) != address(0);

        return registry.checkCoreConfigured() == expected;
    }

    function echidna_wallet_config_matches_storage() external view returns (bool) {
        bool expected =
            registry.getContract(registry.KEY_MIMHO_DAO_WALLET()) != address(0) &&
            registry.getContract(registry.KEY_WALLET_MARKETING()) != address(0) &&
            registry.getContract(registry.KEY_WALLET_DONATION()) != address(0) &&
            registry.getContract(registry.KEY_WALLET_BURN()) != address(0);

        return registry.checkWalletsConfigured() == expected;
    }

    function echidna_legacy_aliases_remain_consistent() external view returns (bool) {
        if (registry.getContract(registry.KEY_LP_INJECTOR()) != registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY())) {
            return false;
        }

        if (registry.getContract(registry.KEY_STAKING_CONTRACT()) != registry.getContract(registry.KEY_MIMHO_STAKING())) {
            return false;
        }

        if (registry.getContract(registry.KEY_MARKETING_WALLET()) != registry.getContract(registry.KEY_WALLET_MARKETING())) {
            return false;
        }

        return true;
    }

    function echidna_compatibility_getters_match_storage() external view returns (bool) {
        if (registry.mimhoToken() != registry.getContract(registry.KEY_MIMHO_TOKEN())) return false;
        if (registry.mimhoStaking() != registry.getContract(registry.KEY_MIMHO_STAKING())) return false;
        if (registry.mimhoBurn() != registry.getContract(registry.KEY_MIMHO_BURN())) return false;
        if (registry.mimhoLocker() != registry.getContract(registry.KEY_MIMHO_LOCKER())) return false;
        if (registry.mimhoAirdrop() != registry.getContract(registry.KEY_MIMHO_AIRDROP())) return false;
        if (registry.mimhoInjectLiquidity() != registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY())) return false;
        if (registry.mimhoMart() != registry.getContract(registry.KEY_MIMHO_MART())) return false;
        if (registry.mimhoMarketplace() != registry.getContract(registry.KEY_MIMHO_MARKETPLACE())) return false;

        return true;
    }

    function echidna_current_contract_values_are_ecosystem_contracts() external view returns (bool) {
        for (uint256 i = 0; i < contractKeys.length; i++) {
            address value = registry.getContract(contractKeys[i]);

            if (value != address(0) && !registry.isEcosystemContract(value)) {
                return false;
            }
        }

        address token = registry.getContract(registry.KEY_MIMHO_TOKEN());
        address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
        address hub = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());

        if (token != address(0) && !registry.isEcosystemContract(token)) return false;
        if (daoAddr != address(0) && !registry.isEcosystemContract(daoAddr)) return false;
        if (hub != address(0) && !registry.isEcosystemContract(hub)) return false;

        return true;
    }

    function echidna_wallet_values_are_not_ecosystem_contracts_unless_also_contracts() external view returns (bool) {
        for (uint256 i = 0; i < walletValues.length; i++) {
            address walletValue = walletValues[i];

            bool alsoContract = _isCurrentContractValue(walletValue);

            if (!alsoContract && registry.isEcosystemContract(walletValue)) {
                return false;
            }
        }

        return true;
    }

    function echidna_registry_never_paused_in_this_harness() external view returns (bool) {
        return !registry.paused();
    }

    function echidna_dao_remains_set() external view returns (bool) {
        return registry.dao() == dao;
    }

    function _isCurrentContractValue(address value) internal view returns (bool) {
        for (uint256 i = 0; i < contractKeys.length; i++) {
            if (registry.getContract(contractKeys[i]) == value) {
                return true;
            }
        }

        if (registry.getContract(registry.KEY_MIMHO_TOKEN()) == value) return true;
        if (registry.getContract(registry.KEY_MIMHO_DAO()) == value) return true;
        if (registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()) == value) return true;

        return false;
    }

    function _bound(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (value % (max - min + 1));
    }
}

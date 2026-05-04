// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/v2/registry.sol";

contract MockEventsHub {
    uint256 public calls;

    bytes32 public lastModule;
    bytes32 public lastAction;
    address public lastCaller;
    uint256 public lastValue;
    bytes public lastData;

    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external {
        calls++;
        lastModule = module;
        lastAction = action;
        lastCaller = caller;
        lastValue = value;
        lastData = data;
    }
}

contract MockBrokenEventsHub {
    function emitEvent(
        bytes32,
        bytes32,
        address,
        uint256,
        bytes calldata
    ) external pure {
        revert("BROKEN_HUB");
    }
}

contract RegistryFlowTest is Test {
    MIMHORegistry registry;

    address ownerSafe = address(this);
    address dao = address(0xDA0);
    address alice = address(0xA11CE);

    address token = address(0x1001);
    address staking = address(0x1002);
    address eventsHub = address(0x1003);
    address injectLiquidity = address(0x1004);
    address marketing = address(0x2001);
    address donation = address(0x2002);
    address burn = address(0x2003);
    address daoTreasury = address(0x2004);

    bytes32 serviceId = keccak256("MIMHO_LABS_TEST_SERVICE");

    function setUp() public {
        registry = new MIMHORegistry(ownerSafe);
    }

    // =====================================================
    // CONSTRUCTOR / METADATA
    // =====================================================

    function test_ConstructorSetsOwnerSafeAndOwner() public {
        assertEq(registry.ownersafe(), ownerSafe);
        assertEq(registry.owner(), ownerSafe);
        assertFalse(registry.daoActivated());
        assertFalse(registry.paused());
    }

    function test_Revert_ConstructorZeroOwner() public {
        vm.expectRevert(bytes("ZERO"));
        new MIMHORegistry(address(0));
    }

    function test_Metadata() public {
        assertEq(registry.contractName(), "MIMHO Registry");
        assertEq(registry.version(), "2.0.0");
        assertEq(registry.contractType(), keccak256("MIMHO_REGISTRY"));
        assertEq(registry.getActionType(), keccak256("REGISTRY_ACTION"));
        assertTrue(registry.isObservable());
        assertEq(registry.getRiskLevel(), 0);
        assertFalse(registry.isFinalized());
    }

    function test_ProtocolNeutralViews() public {
        (uint256 volumeIn, uint256 volumeOut, uint256 lockedValue) = registry.getFinancialImpact(alice);

        assertEq(volumeIn, 0);
        assertEq(volumeOut, 0);
        assertEq(lockedValue, 0);
        assertEq(registry.getBoostValue(alice), 0);

        registry.onExternalAction(alice, keccak256("TEST"));
    }

    // =====================================================
    // DAO / PAUSE
    // =====================================================

    function test_SetDAO() public {
        registry.setDAO(dao);

        assertEq(registry.dao(), dao);
        assertEq(registry.getContract(registry.KEY_MIMHO_DAO()), dao);
        assertTrue(registry.isEcosystemContract(dao));
    }

    function test_Revert_SetDAOZero() public {
        vm.expectRevert(bytes("ZERO"));
        registry.setDAO(address(0));
    }

    function test_Revert_SetDAOTwice() public {
        registry.setDAO(dao);

        vm.expectRevert(bytes("SET"));
        registry.setDAO(address(0xBEEF));
    }

    function test_ActivateDAO() public {
        registry.setDAO(dao);
        registry.activateDAO();

        assertTrue(registry.daoActivated());
    }

    function test_Revert_ActivateDAOWithoutDAO() public {
        vm.expectRevert(bytes("NO_DAO"));
        registry.activateDAO();
    }

    function test_Revert_ActivateDAOTwice() public {
        registry.setDAO(dao);
        registry.activateDAO();

        vm.expectRevert(bytes("ACTIVE"));
        registry.activateDAO();
    }

    function test_OwnerCanPauseBeforeDAOActivation() public {
        registry.pauseEmergencial();

        assertTrue(registry.paused());
    }

    function test_DAOCannotPauseBeforeActivation() public {
        registry.setDAO(dao);

        vm.prank(dao);
        vm.expectRevert(bytes("OWN"));
        registry.pauseEmergencial();
    }

    function test_DAOCanPauseAfterActivation() public {
        registry.setDAO(dao);
        registry.activateDAO();

        vm.prank(dao);
        registry.pauseEmergencial();

        assertTrue(registry.paused());
    }

    function test_OwnerCannotPauseAfterDAOActivation() public {
        registry.setDAO(dao);
        registry.activateDAO();

        vm.expectRevert(bytes("DAO"));
        registry.pauseEmergencial();
    }

    function test_Unpause() public {
        registry.pauseEmergencial();
        assertTrue(registry.paused());

        registry.unpause();
        assertFalse(registry.paused());
    }

    function test_Revert_PauseTwice() public {
        registry.pauseEmergencial();

        vm.expectRevert(bytes("ALREADY"));
        registry.pauseEmergencial();
    }

    function test_Revert_UnpauseWhenNotPaused() public {
        vm.expectRevert(bytes("NOT_PAUSED"));
        registry.unpause();
    }

    function test_WhenPausedBlocksConfigSetters() public {
        registry.pauseEmergencial();

        vm.expectRevert(bytes("PAUSE"));
        registry.setMIMHOToken(token);
    }

    // =====================================================
    // CORE SETTERS / RESOLUTION
    // =====================================================

    function test_SetMIMHOToken() public {
        registry.setMIMHOToken(token);

        assertEq(registry.getContract(registry.KEY_MIMHO_TOKEN()), token);
        assertEq(registry.mimhoToken(), token);
        assertTrue(registry.isEcosystemContract(token));
    }

    function test_Revert_SetMIMHOTokenZero() public {
        vm.expectRevert(bytes("ZERO"));
        registry.setMIMHOToken(address(0));
    }

    function test_SetEventsHub() public {
        MockEventsHub hub = new MockEventsHub();

        registry.setEventsHub(address(hub));

        assertEq(address(registry.eventsHub()), address(hub));
        assertEq(registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()), address(hub));
        assertTrue(registry.isEcosystemContract(address(hub)));
        assertGt(hub.calls(), 0);
    }

    function test_BrokenEventsHubDoesNotBreakFutureSetters() public {
        MockBrokenEventsHub brokenHub = new MockBrokenEventsHub();

        registry.setEventsHub(address(brokenHub));

        registry.setMIMHOToken(token);

        assertEq(registry.getContract(registry.KEY_MIMHO_TOKEN()), token);
    }

    function test_SetContract() public {
        registry.setContract(registry.KEY_MIMHO_STAKING(), staking);

        assertEq(registry.getContract(registry.KEY_MIMHO_STAKING()), staking);
        assertEq(registry.mimhoStaking(), staking);
        assertTrue(registry.isEcosystemContract(staking));
    }

    function test_Revert_SetContractZero() public {
        bytes32 stakingKey = registry.KEY_MIMHO_STAKING();

        vm.expectRevert(bytes("ZERO"));
        registry.setContract(stakingKey, address(0));
    }

    function test_Revert_SetContractWithSpecificCoreKeys() public {
        bytes32 daoKey = registry.KEY_MIMHO_DAO();
        bytes32 hubKey = registry.KEY_MIMHO_EVENTS_HUB();
        bytes32 tokenKey = registry.KEY_MIMHO_TOKEN();

        vm.expectRevert(bytes("USE_SPECIFIC"));
        registry.setContract(daoKey, dao);

        vm.expectRevert(bytes("USE_SPECIFIC"));
        registry.setContract(hubKey, eventsHub);

        vm.expectRevert(bytes("USE_SPECIFIC"));
        registry.setContract(tokenKey, token);
    }

    function test_Revert_SetContractWithWalletKey() public {
        bytes32 marketingWalletKey = registry.KEY_WALLET_MARKETING();

        vm.expectRevert(bytes("WALLET_KEY"));
        registry.setContract(marketingWalletKey, marketing);
    }

    function test_ReplacingContractUpdatesEcosystemRefs() public {
        address oldStaking = address(0x1111);
        address newStaking = address(0x2222);

        registry.setContract(registry.KEY_MIMHO_STAKING(), oldStaking);
        assertTrue(registry.isEcosystemContract(oldStaking));

        registry.setContract(registry.KEY_MIMHO_STAKING(), newStaking);

        assertFalse(registry.isEcosystemContract(oldStaking));
        assertTrue(registry.isEcosystemContract(newStaking));
        assertEq(registry.getContract(registry.KEY_MIMHO_STAKING()), newStaking);
    }

    // =====================================================
    // WALLETS
    // =====================================================

    function test_SetWalletsAndGetWallets() public {
        registry.setWallet(registry.KEY_MIMHO_DAO_WALLET(), daoTreasury);
        registry.setWallet(registry.KEY_WALLET_MARKETING(), marketing);
        registry.setWallet(registry.KEY_WALLET_DONATION(), donation);
        registry.setWallet(registry.KEY_WALLET_BURN(), burn);

        assertTrue(registry.checkWalletsConfigured());

        (
            address daoTreasuryRead,
            address marketingRead,
            address donationRead,
            address burnRead
        ) = registry.getWallets();

        assertEq(daoTreasuryRead, daoTreasury);
        assertEq(marketingRead, marketing);
        assertEq(donationRead, donation);
        assertEq(burnRead, burn);

        assertEq(registry.walletDAOTreasury(), daoTreasury);
        assertEq(registry.walletMarketing(), marketing);
        assertEq(registry.walletDonation(), donation);
        assertEq(registry.walletBurn(), burn);
    }

    function test_Revert_SetWalletWithContractKey() public {
        bytes32 stakingKey = registry.KEY_MIMHO_STAKING();

        vm.expectRevert(bytes("CONTRACT_KEY"));
        registry.setWallet(stakingKey, staking);
    }

    function test_Revert_SetWalletZero() public {
        bytes32 marketingWalletKey = registry.KEY_WALLET_MARKETING();

        vm.expectRevert(bytes("ZERO"));
        registry.setWallet(marketingWalletKey, address(0));
    }

    function test_WalletDoesNotCountAsEcosystemContract() public {
        registry.setWallet(registry.KEY_WALLET_MARKETING(), marketing);

        assertFalse(registry.isEcosystemContract(marketing));
    }

    // =====================================================
    // LEGACY ALIASES
    // =====================================================

    function test_LegacyAliasesResolveCorrectTargets() public {
        registry.setContract(registry.KEY_MIMHO_INJECT_LIQUIDITY(), injectLiquidity);
        registry.setContract(registry.KEY_MIMHO_STAKING(), staking);
        registry.setWallet(registry.KEY_WALLET_MARKETING(), marketing);

        assertEq(registry.getContract(registry.KEY_LP_INJECTOR()), injectLiquidity);
        assertEq(registry.getContract(registry.KEY_STAKING_CONTRACT()), staking);
        assertEq(registry.getContract(registry.KEY_MARKETING_WALLET()), marketing);
    }

    // =====================================================
    // CONFIG CHECKS
    // =====================================================

    function test_CheckCoreConfigured() public {
        assertFalse(registry.checkCoreConfigured());

        MockEventsHub hub = new MockEventsHub();

        registry.setDAO(dao);
        registry.setMIMHOToken(token);
        registry.setEventsHub(address(hub));

        assertTrue(registry.checkCoreConfigured());
    }

    function test_CheckWalletsConfigured() public {
        assertFalse(registry.checkWalletsConfigured());

        registry.setWallet(registry.KEY_MIMHO_DAO_WALLET(), daoTreasury);
        registry.setWallet(registry.KEY_WALLET_MARKETING(), marketing);
        registry.setWallet(registry.KEY_WALLET_DONATION(), donation);
        registry.setWallet(registry.KEY_WALLET_BURN(), burn);

        assertTrue(registry.checkWalletsConfigured());
    }

    // =====================================================
    // PARTNER SERVICES
    // =====================================================

    function test_SetPartnerServiceAllowed() public {
        uint64 validUntil = uint64(block.timestamp + 30 days);

        registry.setPartnerService(alice, serviceId, true, validUntil);

        assertTrue(registry.isPartnerAuthorized(alice, serviceId));

        (bool allowed, uint64 storedValidUntil) = registry.getPartnerService(alice, serviceId);

        assertTrue(allowed);
        assertEq(storedValidUntil, validUntil);
    }

    function test_PartnerServiceExpires() public {
        uint64 validUntil = uint64(block.timestamp + 30 days);

        registry.setPartnerService(alice, serviceId, true, validUntil);

        vm.warp(validUntil + 1);

        assertFalse(registry.isPartnerAuthorized(alice, serviceId));
    }

    function test_RemovePartnerService() public {
        uint64 validUntil = uint64(block.timestamp + 30 days);

        registry.setPartnerService(alice, serviceId, true, validUntil);
        registry.setPartnerService(alice, serviceId, false, 0);

        assertFalse(registry.isPartnerAuthorized(alice, serviceId));

        (bool allowed, uint64 storedValidUntil) = registry.getPartnerService(alice, serviceId);

        assertFalse(allowed);
        assertEq(storedValidUntil, 0);
    }

    function test_Revert_SetPartnerServiceZeroPartner() public {
        vm.expectRevert(bytes("ZERO"));
        registry.setPartnerService(address(0), serviceId, true, uint64(block.timestamp + 1 days));
    }

    function test_Revert_SetPartnerServiceExpiredDate() public {
        vm.expectRevert(bytes("EXP"));
        registry.setPartnerService(alice, serviceId, true, uint64(block.timestamp));
    }
}

contract RegistryHandler is Test {
    MIMHORegistry public registry;

    address public ownerSafe;

    bytes32[] private contractKeysList;
    bytes32[] private walletKeysList;

    address[] private contractValuesList;
    address[] private walletValuesList;

    constructor(MIMHORegistry registry_, address ownerSafe_) {
        registry = registry_;
        ownerSafe = ownerSafe_;

        contractKeysList.push(registry.KEY_MIMHO_STAKING());
        contractKeysList.push(registry.KEY_MIMHO_LOCKER());
        contractKeysList.push(registry.KEY_MIMHO_AIRDROP());
        contractKeysList.push(registry.KEY_MIMHO_BURN());
        contractKeysList.push(registry.KEY_MIMHO_INJECT_LIQUIDITY());
        contractKeysList.push(registry.KEY_MIMHO_MART());
        contractKeysList.push(registry.KEY_MIMHO_MARKETPLACE());

        walletKeysList.push(registry.KEY_MIMHO_DAO_WALLET());
        walletKeysList.push(registry.KEY_WALLET_MARKETING());
        walletKeysList.push(registry.KEY_WALLET_DONATION());
        walletKeysList.push(registry.KEY_WALLET_BURN());
        walletKeysList.push(registry.KEY_WALLET_TECHNICAL());
        walletKeysList.push(registry.KEY_WALLET_LP_RESERVE());

        contractValuesList.push(address(0xC001));
        contractValuesList.push(address(0xC002));
        contractValuesList.push(address(0xC003));
        contractValuesList.push(address(0xC004));
        contractValuesList.push(address(0xC005));
        contractValuesList.push(address(0xC006));
        contractValuesList.push(address(0xC007));

        walletValuesList.push(address(0xA001));
        walletValuesList.push(address(0xA002));
        walletValuesList.push(address(0xA003));
        walletValuesList.push(address(0xA004));
        walletValuesList.push(address(0xA005));
        walletValuesList.push(address(0xA006));
    }

    function actionSetContract(uint8 keySeed, uint8 valueSeed) external {
        bytes32 key = contractKeysList[keySeed % contractKeysList.length];
        address value = contractValuesList[valueSeed % contractValuesList.length];

        vm.prank(ownerSafe);
        try registry.setContract(key, value) {} catch {}
    }

    function actionSetWallet(uint8 keySeed, uint8 valueSeed) external {
        bytes32 key = walletKeysList[keySeed % walletKeysList.length];
        address value = walletValuesList[valueSeed % walletValuesList.length];

        vm.prank(ownerSafe);
        try registry.setWallet(key, value) {} catch {}
    }

    function actionSetToken(uint8 valueSeed) external {
        address value = contractValuesList[valueSeed % contractValuesList.length];

        vm.prank(ownerSafe);
        try registry.setMIMHOToken(value) {} catch {}
    }

    function actionSetEventsHub(uint8 valueSeed) external {
        address value = contractValuesList[valueSeed % contractValuesList.length];

        vm.prank(ownerSafe);
        try registry.setEventsHub(value) {} catch {}
    }

    function actionSetPartnerService(uint8 partnerSeed, uint8 serviceSeed, uint32 duration) external {
        address partner = contractValuesList[partnerSeed % contractValuesList.length];
        bytes32 serviceId = keccak256(abi.encodePacked("SERVICE", serviceSeed));

        uint64 validUntil = uint64(block.timestamp + bound(uint256(duration), 1 days, 365 days));

        vm.prank(ownerSafe);
        try registry.setPartnerService(partner, serviceId, true, validUntil) {} catch {}
    }

    function contractKeyCount() external view returns (uint256) {
        return contractKeysList.length;
    }

    function walletKeyCount() external view returns (uint256) {
        return walletKeysList.length;
    }

    function contractValueCount() external view returns (uint256) {
        return contractValuesList.length;
    }

    function walletValueCount() external view returns (uint256) {
        return walletValuesList.length;
    }

    function contractKeyAt(uint256 i) external view returns (bytes32) {
        return contractKeysList[i];
    }

    function walletKeyAt(uint256 i) external view returns (bytes32) {
        return walletKeysList[i];
    }

    function contractValueAt(uint256 i) external view returns (address) {
        return contractValuesList[i];
    }

    function walletValueAt(uint256 i) external view returns (address) {
        return walletValuesList[i];
    }
}

contract RegistryInvariantTest is Test {
    MIMHORegistry registry;
    RegistryHandler handler;

    address ownerSafe = address(this);
    address dao = address(0xDA0);

    function setUp() public {
        registry = new MIMHORegistry(ownerSafe);

        registry.setDAO(dao);

        handler = new RegistryHandler(registry, ownerSafe);

        targetContract(address(handler));
    }

    function invariant_CoreConfiguredMatchesStoredAddresses() public view {
        bool expected =
            registry.getContract(registry.KEY_MIMHO_TOKEN()) != address(0) &&
            registry.getContract(registry.KEY_MIMHO_DAO()) != address(0) &&
            registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()) != address(0);

        assertEq(registry.checkCoreConfigured(), expected);
    }

    function invariant_WalletsConfiguredMatchesStoredAddresses() public view {
        bool expected =
            registry.getContract(registry.KEY_MIMHO_DAO_WALLET()) != address(0) &&
            registry.getContract(registry.KEY_WALLET_MARKETING()) != address(0) &&
            registry.getContract(registry.KEY_WALLET_DONATION()) != address(0) &&
            registry.getContract(registry.KEY_WALLET_BURN()) != address(0);

        assertEq(registry.checkWalletsConfigured(), expected);
    }

    function invariant_LegacyAliasesRemainConsistent() public view {
        assertEq(
            registry.getContract(registry.KEY_LP_INJECTOR()),
            registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY())
        );

        assertEq(
            registry.getContract(registry.KEY_STAKING_CONTRACT()),
            registry.getContract(registry.KEY_MIMHO_STAKING())
        );

        assertEq(
            registry.getContract(registry.KEY_MARKETING_WALLET()),
            registry.getContract(registry.KEY_WALLET_MARKETING())
        );
    }

    function invariant_CompatibilityGettersMatchRegistryStorage() public view {
        assertEq(registry.mimhoToken(), registry.getContract(registry.KEY_MIMHO_TOKEN()));
        assertEq(registry.mimhoStaking(), registry.getContract(registry.KEY_MIMHO_STAKING()));
        assertEq(registry.mimhoBurn(), registry.getContract(registry.KEY_MIMHO_BURN()));
        assertEq(registry.mimhoLocker(), registry.getContract(registry.KEY_MIMHO_LOCKER()));
        assertEq(registry.mimhoAirdrop(), registry.getContract(registry.KEY_MIMHO_AIRDROP()));
        assertEq(registry.mimhoInjectLiquidity(), registry.getContract(registry.KEY_MIMHO_INJECT_LIQUIDITY()));
        assertEq(registry.mimhoMart(), registry.getContract(registry.KEY_MIMHO_MART()));
        assertEq(registry.mimhoMarketplace(), registry.getContract(registry.KEY_MIMHO_MARKETPLACE()));
    }

    function invariant_CurrentContractValuesAreEcosystemContracts() public view {
        uint256 keyCount = handler.contractKeyCount();

        for (uint256 i = 0; i < keyCount; i++) {
            address value = registry.getContract(handler.contractKeyAt(i));

            if (value != address(0)) {
                assertTrue(registry.isEcosystemContract(value));
            }
        }

        address token = registry.getContract(registry.KEY_MIMHO_TOKEN());
        address daoAddr = registry.getContract(registry.KEY_MIMHO_DAO());
        address hub = registry.getContract(registry.KEY_MIMHO_EVENTS_HUB());

        if (token != address(0)) assertTrue(registry.isEcosystemContract(token));
        if (daoAddr != address(0)) assertTrue(registry.isEcosystemContract(daoAddr));
        if (hub != address(0)) assertTrue(registry.isEcosystemContract(hub));
    }

    function invariant_WalletValuesAreNotEcosystemContractsUnlessAlsoUsedAsContracts() public view {
        uint256 walletValueCount = handler.walletValueCount();

        for (uint256 i = 0; i < walletValueCount; i++) {
            address walletValue = handler.walletValueAt(i);

            bool alsoContract = _isCurrentContractValue(walletValue);

            if (!alsoContract) {
                assertFalse(registry.isEcosystemContract(walletValue));
            }
        }
    }

    function invariant_RegistryNeverPausedInThisHandler() public view {
        assertFalse(registry.paused());
    }

    function _isCurrentContractValue(address value) internal view returns (bool) {
        uint256 keyCount = handler.contractKeyCount();

        for (uint256 i = 0; i < keyCount; i++) {
            if (registry.getContract(handler.contractKeyAt(i)) == value) {
                return true;
            }
        }

        if (registry.getContract(registry.KEY_MIMHO_TOKEN()) == value) return true;
        if (registry.getContract(registry.KEY_MIMHO_DAO()) == value) return true;
        if (registry.getContract(registry.KEY_MIMHO_EVENTS_HUB()) == value) return true;

        return false;
    }
}

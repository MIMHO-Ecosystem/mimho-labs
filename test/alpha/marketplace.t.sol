// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOMarketplace} from "src/marketplace.sol";

/*//////////////////////////////////////////////////////////////
                        MOCKS
//////////////////////////////////////////////////////////////*/

contract MockHub {
    function emitEvent(bytes32, bytes32, address, uint256, bytes calldata) external {}
}

contract MockRegistry {
    // addresses
    address public hub;
    address public mart;
    address public dao;
    address public marketing;
    address public inject;
    address public staking;

    // keys (must match Marketplace getters)
    bytes32 internal constant KEY_EVENTS_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 internal constant KEY_MART       = keccak256("MIMHO_MART");
    bytes32 internal constant KEY_DAO        = keccak256("MIMHO_DAO");
    bytes32 internal constant KEY_MARKETING  = keccak256("MARKETING_WALLET");
    bytes32 internal constant KEY_INJECT     = keccak256("MIMHO_INJECT_LIQUIDITY");
    bytes32 internal constant KEY_STAKING    = keccak256("MIMHO_STAKING");

    // simple ecosystem flag
    mapping(address => bool) public eco;

    constructor(
        address h,
        address m,
        address d,
        address mk,
        address ij,
        address st
    ) {
        hub = h;
        mart = m;
        dao = d;
        marketing = mk;
        inject = ij;
        staking = st;
    }

    function setEco(address a, bool v) external { eco[a] = v; }

    function isEcosystemContract(address a) external view returns (bool) { return eco[a]; }

    function getContract(bytes32 key) external view returns (address) {
        if (key == KEY_EVENTS_HUB) return hub;
        if (key == KEY_MART) return mart;
        if (key == KEY_DAO) return dao;
        if (key == KEY_MARKETING) return marketing;
        if (key == KEY_INJECT) return inject;
        if (key == KEY_STAKING) return staking;
        return address(0);
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return KEY_EVENTS_HUB; }
    function KEY_MIMHO_MART() external pure returns (bytes32) { return KEY_MART; }
    function KEY_MIMHO_DAO() external pure returns (bytes32) { return KEY_DAO; }
    function KEY_MARKETING_WALLET() external pure returns (bytes32) { return KEY_MARKETING; }
    function KEY_MIMHO_INJECT_LIQUIDITY() external pure returns (bytes32) { return KEY_INJECT; }
    function KEY_MIMHO_STAKING() external pure returns (bytes32) { return KEY_STAKING; }
}

contract MockERC721 {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function mint(address to, uint256 id) external {
        ownerOf[id] = to;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function safeTransferFrom(address from, address to, uint256 id) external {
        require(ownerOf[id] == from, "NOT_OWNER");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "NOT_APPROVED");
        ownerOf[id] = to;
    }
}

/*//////////////////////////////////////////////////////////////
                        TESTS
//////////////////////////////////////////////////////////////*/

contract MarketplaceAlphaTest is Test {
    MIMHOMarketplace market;
    MockHub hub;
    MockRegistry reg;
    MockERC721 nft;

    address owner = address(this);
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address dao   = address(0xD00);
    address marketing = address(0xBEEF);
    address inject = address(0x1A);
    address staking = address(0x51);

    function setUp() public {
        hub = new MockHub();
        nft = new MockERC721();

        // IMPORTANT: Registry MUST return the "mart" address; for this test we use the same NFT as Mart
        reg = new MockRegistry(address(hub), address(nft), dao, marketing, inject, staking);

        market = new MIMHOMarketplace(address(reg));

        // prepare NFT
        nft.mint(alice, 1);

        // alice approves marketplace
        vm.startPrank(alice);
        nft.setApprovalForAll(address(market), true);
        vm.stopPrank();

        // give bob BNB
        vm.deal(bob, 10 ether);
    }

    function test_Deploy_Works() public {
        assertTrue(address(market) != address(0));
        assertEq(market.owner(), owner);
    }

    function test_List_Buy_CreatesPending_And_ClaimWorks() public {
        uint256 price = 1 ether;

        // alice lists ERC721
        vm.startPrank(alice);
        uint256 id = market.listNFT(address(nft), 1, 1, price, MIMHOMarketplace.TokenStandard.ERC721);
        vm.stopPrank();

        // bob buys
        vm.prank(bob);
        market.buyNFT{value: price}(id);

        // NFT delivered to bob
        assertEq(nft.ownerOf(1), bob);

        // seller should have something pending (net after fees/royalty)
        uint256 pendingSeller = market.pendingNative(alice);
        assertTrue(pendingSeller > 0);

        // claimPending pays out
        uint256 balBefore = alice.balance;
        vm.prank(alice);
        market.claimPending();
        uint256 balAfter = alice.balance;

        assertEq(market.pendingNative(alice), 0);
        assertEq(balAfter - balBefore, pendingSeller);
    }

    function test_Pause_Unpause_DoesNotRevert() public {
        market.pauseEmergencial();
        market.unpause();
    }
}

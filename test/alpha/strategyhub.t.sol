// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/strategyhub.sol";

contract MockERC721BalanceOnly {
    mapping(address => uint256) internal _bal;
    function setBalance(address user, uint256 b) external { _bal[user] = b; }
    function balanceOf(address owner) external view returns (uint256) { return _bal[owner]; }
}

contract MockBadNFT { }

contract MockRegistry is IMIMHORegistry {
    mapping(bytes32 => address) public addrs;

    bytes32 private constant _KEY_HUB = keccak256("mIMHO_EVENTS_HUB");
    bytes32 private constant _KEY_DAO = keccak256("MIMHO_DAO");

    function getContract(bytes32 key) external view returns (address) { return addrs[key]; }
    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return _KEY_HUB; }
    function KEY_MIMHO_DAO() external pure returns (bytes32) { return _KEY_DAO; }
    function isEcosystemContract(address) external pure returns (bool) { return true; }
}

contract StrategyHubAlphaTest is Test {
    MockRegistry registry;
    MIMHOStrategyHub strategy;

    MockERC721BalanceOnly nft1;
    MockERC721BalanceOnly nft2;
    MockBadNFT badNft;

    address user = address(0xBEEF);

    function setUp() public {
        registry = new MockRegistry();
        strategy = new MIMHOStrategyHub(address(registry));

        nft1 = new MockERC721BalanceOnly();
        nft2 = new MockERC721BalanceOnly();
        badNft = new MockBadNFT();

        strategy.setNftActive(address(nft1), true);
        strategy.setNftActive(address(nft2), true);

        strategy.setNftBonus(address(nft1), 1, 500, true);
        strategy.setNftBonus(address(nft2), 1, 700, true);
    }

    function test_BonusZeroWhenNoneOwned() public {
        address[] memory list = new address[](2);
        list[0] = address(nft1);
        list[1] = address(nft2);

        uint16 bps = strategy.getUserBonusBps(user, list, 1);
        assertEq(bps, 0);
    }

    function test_CountsOwnedOnly() public {
        nft1.setBalance(user, 1);
        nft2.setBalance(user, 0);

        address[] memory list = new address[](2);
        list[0] = address(nft1);
        list[1] = address(nft2);

        uint16 bps = strategy.getUserBonusBps(user, list, 1);
        assertEq(bps, 500);
    }

    function test_BadNFTDoesNotRevert() public {
        nft1.setBalance(user, 1);

        address[] memory list = new address[](2);
        list[0] = address(nft1);
        list[1] = address(badNft);

        uint16 bps = strategy.getUserBonusBps(user, list, 1);
        assertEq(bps, 500);
    }

    function test_RevertsWhenTooMany() public {
        address[] memory list = new address[](31);
        for (uint256 i = 0; i < 31; i++) {
            list[i] = address(nft1);
        }

        vm.expectRevert(bytes("STRATEGY: too many nfts"));
        strategy.getUserBonusBps(user, list, 1);
    }
}

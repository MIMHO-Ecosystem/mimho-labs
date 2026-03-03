// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOMart} from "src/mart.sol";

/*//////////////////////////////////////////////////////////////
                        MOCKS
//////////////////////////////////////////////////////////////*/

contract MockHub {
    function emitEvent(bytes32, bytes32, address, uint256, bytes calldata) external {}
}

contract MockRegistry {
    address public hub;
    address public dao;
    address public token;
    address public staking;

    bytes32 internal constant KEY_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 internal constant KEY_DAO = keccak256("MIMHO_DAO");
    bytes32 internal constant KEY_TOKEN = keccak256("MIMHO_TOKEN");
    bytes32 internal constant KEY_STAKING = keccak256("MIMHO_STAKING");

    constructor(address h, address d, address t, address s) {
        hub = h;
        dao = d;
        token = t;
        staking = s;
    }

    function getContract(bytes32 key) external view returns (address) {
        if (key == KEY_HUB) return hub;
        if (key == KEY_DAO) return dao;
        if (key == KEY_TOKEN) return token;
        if (key == KEY_STAKING) return staking;
        return address(0);
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return KEY_HUB; }
    function KEY_MIMHO_DAO() external pure returns (bytes32) { return KEY_DAO; }
    function KEY_MIMHO_TOKEN() external pure returns (bytes32) { return KEY_TOKEN; }
    function KEY_MIMHO_STAKING() external pure returns (bytes32) { return KEY_STAKING; }
    function isEcosystemContract(address) external pure returns (bool) { return false; }
}

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amt) external {
        balanceOf[to] += amt;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        return true;
    }

    function transfer(address to, uint256 amt) external returns (bool) {
        require(balanceOf[msg.sender] >= amt, "BAL");
        balanceOf[msg.sender] -= amt;
        balanceOf[to] += amt;
        return true;
    }

    function transferFrom(address from, address to, uint256 amt) external returns (bool) {
        require(balanceOf[from] >= amt, "BAL");
        require(allowance[from][msg.sender] >= amt, "ALLOW");
        allowance[from][msg.sender] -= amt;
        balanceOf[from] -= amt;
        balanceOf[to] += amt;
        return true;
    }
}

/*//////////////////////////////////////////////////////////////
                        TESTS
//////////////////////////////////////////////////////////////*/

contract MartAlphaTest is Test {

    MIMHOMart mart;
    MockRegistry registry;
    MockHub hub;
    MockERC20 mimho;

    address alice = address(0xA11CE);
    address bob   = address(0xB0B);
    address dao   = address(0xD00);
    address staking = address(0x5151);

    function setUp() public {
        hub = new MockHub();
        mimho = new MockERC20();
        registry = new MockRegistry(address(hub), dao, address(mimho), staking);

        mart = new MIMHOMart(address(registry), "MIMHO NFT", "MNFT");

        mimho.mint(bob, 1000e18);

        vm.prank(bob);
        mimho.approve(address(mart), type(uint256).max);
    }

    function test_Deploy_Works() public {
        assertEq(mart.owner(), address(this));
        assertEq(mart.VERSION(), "1.0.1");
    }

    function test_Mint_Works() public {
        uint256 tokenId = mart.mint(address(alice), 1, "uri");
        assertEq(mart.ownerOf(tokenId), alice);
    }

    function test_List_And_Buy() public {
        uint256 tokenId = mart.mint(address(alice), 1, "uri");

        vm.startPrank(alice);
        mart.approve(address(mart), tokenId);
        mart.list(tokenId, 100e18);
        vm.stopPrank();

        vm.prank(bob);
        mart.buy(tokenId);

        assertEq(mart.ownerOf(tokenId), bob);
    }

    function test_Pause() public {
        mart.pauseEmergencial();
        vm.expectRevert();
        mart.mint(address(alice), 1, "uri");
    }
}

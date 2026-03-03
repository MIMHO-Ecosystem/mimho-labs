// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOLocker} from "src/locker.sol";

/*//////////////////////////////////////////////////////////////
                        MOCKS
//////////////////////////////////////////////////////////////*/

contract MockHub {
    function emitEvent(bytes32, bytes32, address, uint256, bytes calldata) external {}
}

contract MockRegistry {
    address public hub;
    address public mimho;
    address public marketing;
    address public inject;

    bytes32 public constant KEY_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant KEY_TOKEN = keccak256("MIMHO_TOKEN");
    bytes32 public constant KEY_MARKETING = keccak256("MIMHO_MARKETING_WALLET");
    bytes32 public constant KEY_INJECT = keccak256("MIMHO_INJECT_LIQUIDITY");

    constructor(address h, address t, address m, address i) {
        hub = h;
        mimho = t;
        marketing = m;
        inject = i;
    }

    function getContract(bytes32 key) external view returns (address) {
        if (key == KEY_HUB) return hub;
        if (key == KEY_TOKEN) return mimho;
        if (key == KEY_MARKETING) return marketing;
        if (key == KEY_INJECT) return inject;
        return address(0);
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return KEY_HUB; }
    function KEY_MIMHO_TOKEN() external pure returns (bytes32) { return KEY_TOKEN; }
    function KEY_MIMHO_MARKETING_WALLET() external pure returns (bytes32) { return KEY_MARKETING; }
    function KEY_MIMHO_INJECT_LIQUIDITY() external pure returns (bytes32) { return KEY_INJECT; }
}

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    uint256 public totalSupply = 1_000_000_000_000_000e18;

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

contract LockerAlphaTest is Test {

    MIMHOLocker locker;
    MockERC20 mimho;
    MockHub hub;
    MockRegistry registry;

    address marketing = address(0x1234);
    address inject = address(0x5678);

    address user = address(0xAAA);

    function setUp() public {
        hub = new MockHub();
        mimho = new MockERC20();
        registry = new MockRegistry(address(hub), address(mimho), marketing, inject);

        locker = new MIMHOLocker(address(registry));

        locker.initFeeParams(100e18, 10e18);

        mimho.mint(user, 1000e18);

        vm.startPrank(user);
        mimho.approve(address(locker), type(uint256).max);
        vm.stopPrank();
    }

    function test_PublicLock_Create_Works() public {
        vm.startPrank(user);

        uint64 unlock = uint64(block.timestamp + 14 days);
        uint256 lockId = locker.createPublicLock(address(mimho), 100e18, unlock);

        (
            address token,
            address owner,
            uint256 amount,
            ,
            uint64 unlockTs,
            ,
            bool released
        ) = locker.getLockInfo(lockId);

        assertEq(token, address(mimho));
        assertEq(owner, user);
        assertEq(amount, 100e18);
        assertEq(unlockTs, unlock);
        assertFalse(released);

        vm.stopPrank();
    }

    function test_Cannot_Release_Before_Time() public {
        vm.startPrank(user);
        uint64 unlock = uint64(block.timestamp + 7 days);
        uint256 lockId = locker.createPublicLock(address(mimho), 50e18, unlock);

        vm.expectRevert("NOT_UNLOCKABLE");
        locker.releasePublicLock(lockId);

        vm.stopPrank();
    }

    function test_Release_After_Time() public {
        vm.startPrank(user);
        uint64 unlock = uint64(block.timestamp + 7 days);
        uint256 lockId = locker.createPublicLock(address(mimho), 50e18, unlock);

        vm.warp(block.timestamp + 8 days);
        locker.releasePublicLock(lockId);

        (, , , , , , bool released) = locker.getLockInfo(lockId);
        assertTrue(released);

        vm.stopPrank();
    }

    function test_Pause_Blocks_Create() public {
        locker.pauseEmergencial();

        vm.startPrank(user);
        vm.expectRevert("PAUSED");
        locker.createPublicLock(address(mimho), 10e18, uint64(block.timestamp + 1 days));
        vm.stopPrank();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHORegistry} from "src/registry.sol";
import {MIMHOStaking} from "src/staking.sol";

contract MockToken {
    string public name = "MIMHO";
    string public symbol = "MIMHO";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "no balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "no balance");
        require(allowance[from][msg.sender] >= amount, "no allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract StakingAlphaTest is Test {

    MIMHORegistry registry;
    MIMHOStaking staking;
    MockToken token;

    address founder = address(0xF0);
    address user = address(0xBEEF);

    function setUp() public {

        registry = new MIMHORegistry(founder);

        token = new MockToken();

        vm.prank(founder);
        registry.setMIMHOToken(address(token));

        staking = new MIMHOStaking(address(registry));

        token.mint(user, 1_000_000 ether);

        vm.startPrank(user);
        token.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }

    function test_Stake() public {

        vm.prank(user);
        staking.stake(100_000 ether);

        (uint256 amount,,,,,,) = staking.getUser(user);
        assertEq(amount, 100_000 ether);
    }

    function test_Unstake() public {

        vm.startPrank(user);
        staking.stake(100_000 ether);
        staking.unstake(50_000 ether);
        vm.stopPrank();

        (uint256 amount,,,,,,) = staking.getUser(user);
        assertEq(amount, 50_000 ether);
    }

    function test_ClaimFailsWithoutRewards() public {

        vm.prank(user);
        staking.stake(100_000 ether);

        vm.expectRevert();
        vm.prank(user);
        staking.claim();
    }

}

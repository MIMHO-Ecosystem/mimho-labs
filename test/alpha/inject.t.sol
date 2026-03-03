// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOInjectLiquidity} from "src/injectliquidity.sol";


interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32);
    function KEY_MIMHO_TOKEN() external view returns (bytes32);
    function KEY_MIMHO_DEX() external view returns (bytes32);
    function KEY_MIMHO_VOTING_CONTROLLER() external view returns (bytes32);
}

interface IMIMHOInjectLiquidity {
    function depositTokens(uint256 amount) external;
    function setAutoInject(bool enabled) external;
    function injectLiquidity(
        uint256 tokenAmount,
        uint256 bnbAmount,
        uint256 minToken,
        uint256 minBNB,
        uint256 deadline
    ) external;

    function autoInjectEnabled() external view returns (bool);
}

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
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
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockRouter {
    function addLiquidityETH(
        address,
        uint256 amountTokenDesired,
        uint256,
        uint256,
        address,
        uint256
    )
        external
        payable
        returns (uint256, uint256, uint256)
    {
        return (amountTokenDesired, msg.value, 1000);
    }
}

contract MockRegistry is IMIMHORegistry {
    mapping(bytes32 => address) public contracts;

    function set(bytes32 key, address value) external {
        contracts[key] = value;
    }

    function getContract(bytes32 key) external view returns (address) {
        return contracts[key];
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) {
        return keccak256("MIMHO_EVENTS_HUB");
    }

    function KEY_MIMHO_TOKEN() external pure returns (bytes32) {
        return keccak256("MIMHO_TOKEN");
    }

    function KEY_MIMHO_DEX() external pure returns (bytes32) {
        return keccak256("MIMHO_DEX");
    }

    function KEY_MIMHO_VOTING_CONTROLLER() external pure returns (bytes32) {
        return keccak256("MIMHO_VOTING_CONTROLLER");
    }
}

contract InjectAlphaTest is Test {

    MockERC20 token;
    MockRouter router;
    MockRegistry registry;
    MIMHOInjectLiquidity inject;

    address owner = address(0x1);

    function setUp() public {
        token = new MockERC20();
        router = new MockRouter();
        registry = new MockRegistry();

        inject = new MIMHOInjectLiquidity(address(registry), owner);

        registry.set(registry.KEY_MIMHO_TOKEN(), address(token));
        registry.set(registry.KEY_MIMHO_DEX(), address(router));

        token.mint(owner, 1_000_000e18);

        vm.startPrank(owner);
        token.approve(address(inject), type(uint256).max);
        vm.stopPrank();
    }

    function test_Deposit_Works() public {
        vm.prank(owner);
        inject.depositTokens(1000e18);
    }

    function test_AutoInject_Enable() public {
        vm.prank(owner);
        inject.setAutoInject(true);

        assertTrue(inject.autoInjectEnabled());
    }

    function test_Inject_Reverts_When_NotAuthorized() public {
        vm.expectRevert();
        inject.injectLiquidity(1e18, 1 ether, 0, 0, block.timestamp + 100);
    }
}

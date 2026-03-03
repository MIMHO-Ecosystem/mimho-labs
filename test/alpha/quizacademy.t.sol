// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOQuiz} from "src/quizacademy.sol";

contract MockRegistry {
    address public token;
    address public hub;
    address public dao;
    address public daoWallet;

    constructor(address _token) {
        token = _token;
    }

    function setHub(address h) external { hub = h; }
    function setDAO(address d) external { dao = d; }
    function setDAOWallet(address w) external { daoWallet = w; }

    function getContract(bytes32 key) external view returns (address) {
        if (key == KEY_MIMHO_TOKEN()) return token;
        if (key == KEY_MIMHO_EVENTS_HUB()) return hub;
        if (key == KEY_MIMHO_DAO()) return dao;
        if (key == KEY_MIMHO_DAO_WALLET()) return daoWallet;
        return address(0);
    }

    function KEY_MIMHO_TOKEN() public pure returns (bytes32) {
        return keccak256("MIMHO_TOKEN");
    }

    function KEY_MIMHO_EVENTS_HUB() public pure returns (bytes32) {
        return keccak256("MIMHO_EVENTS_HUB");
    }

    function KEY_MIMHO_DAO() public pure returns (bytes32) {
        return keccak256("MIMHO_DAO");
    }

    function KEY_MIMHO_DAO_WALLET() public pure returns (bytes32) {
        return keccak256("MIMHO_DAO_WALLET");
    }

    function KEY_MIMHO_CERTIFY() public pure returns (bytes32) {
        return keccak256("MIMHO_CERTIFY");
    }
}

contract MockToken {
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
        require(balanceOf[msg.sender] >= amount, "BAL_LOW");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "BAL_LOW");
        require(allowance[from][msg.sender] >= amount, "ALLOW_LOW");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract QuizAcademyAlphaTest is Test {
    MIMHOQuiz quiz;
    MockToken token;
    MockRegistry registry;

    address user = address(0xBEEF);

    function setUp() public {
        token = new MockToken();
        registry = new MockRegistry(address(token));

        quiz = new MIMHOQuiz(address(registry));

        token.mint(address(this), 1_000_000 ether);
        token.approve(address(quiz), type(uint256).max);
        quiz.fund(500_000 ether);
    }

    function test_CompleteAndClaimFlow() public {
    // Ajusta o reward do próximo ciclo para caber no funding do teste
    quiz.setRewardPerCycle(0, 100_000 ether);

    vm.prank(user);
    quiz.completeQuiz(0);

        vm.warp(block.timestamp + 31 days);

        quiz.closeCycle(0, 1);

        vm.prank(user);
        quiz.claimReward(0, 1);

        assertTrue(true);
    }
}

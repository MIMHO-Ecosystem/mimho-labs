// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../src/staking.sol";

contract EchidnaMockERC20 {
    string public constant name = "Echidna Mock";
    string public constant symbol = "E-MOCK";
    uint8 public constant decimals = 18;

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
        require(balanceOf[msg.sender] >= amount, "BALANCE");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "ALLOWANCE");
        require(balanceOf[from] >= amount, "BALANCE");

        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}

contract EchidnaMockRegistry {
    address public token;

    bytes32 public constant KEY_TOKEN = keccak256("MIMHO_TOKEN");
    bytes32 public constant KEY_DAO = keccak256("MIMHO_DAO");
    bytes32 public constant KEY_EVENTS_HUB = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant KEY_STRATEGY_HUB = keccak256("MIMHO_STRATEGY_HUB");
    bytes32 public constant KEY_SCORE = keccak256("MIMHO_SCORE");
    bytes32 public constant KEY_SECURITY_WALLET = keccak256("MIMHO_SECURITY_WALLET");
    bytes32 public constant KEY_MART = keccak256("MIMHO_MART");
    bytes32 public constant KEY_BET = keccak256("MIMHO_BET");
    bytes32 public constant KEY_GATEWAY = keccak256("MIMHO_GATEWAY");
    bytes32 public constant KEY_VERITAS = keccak256("MIMHO_VERITAS");

    constructor(address token_) {
        token = token_;
    }

    function getContract(bytes32 key) external view returns (address) {
        if (key == KEY_TOKEN) return token;
        return address(0);
    }

    function KEY_MIMHO_TOKEN() external pure returns (bytes32) {
        return KEY_TOKEN;
    }

    function KEY_MIMHO_DAO() external pure returns (bytes32) {
        return KEY_DAO;
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) {
        return KEY_EVENTS_HUB;
    }

    function KEY_MIMHO_STRATEGY_HUB() external pure returns (bytes32) {
        return KEY_STRATEGY_HUB;
    }

    function KEY_MIMHO_SCORE() external pure returns (bytes32) {
        return KEY_SCORE;
    }

    function KEY_MIMHO_SECURITY_WALLET() external pure returns (bytes32) {
        return KEY_SECURITY_WALLET;
    }

    function KEY_MIMHO_MART() external pure returns (bytes32) {
        return KEY_MART;
    }

    function KEY_MIMHO_BET() external pure returns (bytes32) {
        return KEY_BET;
    }

    function KEY_MIMHO_GATEWAY() external pure returns (bytes32) {
        return KEY_GATEWAY;
    }

    function KEY_MIMHO_VERITAS() external pure returns (bytes32) {
        return KEY_VERITAS;
    }
}

contract EchidnaActor {
    MIMHOStaking public staking;
    EchidnaMockERC20 public token;

    constructor(MIMHOStaking staking_, EchidnaMockERC20 token_) {
        staking = staking_;
        token = token_;
        token.approve(address(staking), type(uint256).max);
    }

    function stake(uint256 amount) external {
        staking.stake(amount);
    }

    function unstake(uint256 amount) external {
        staking.unstake(amount);
    }

    function claim() external {
        staking.claim();
    }

    function setReinvest(bool enabled) external {
        staking.setReinvest(enabled);
    }
}

contract EchidnaStaking {
    EchidnaMockERC20 public token;
    EchidnaMockRegistry public registry;
    MIMHOStaking public staking;

    EchidnaActor public actorA;
    EchidnaActor public actorB;
    EchidnaActor public actorC;

    uint256 public constant MIN_STAKE = 100_000 ether;
    uint256 public constant MAX_STAKE = 500_000 ether;
    uint256 public constant INITIAL_BALANCE = 10_000_000 ether;
    uint256 public constant INITIAL_REWARD_FUND = 10_000_000 ether;

    constructor() {
        token = new EchidnaMockERC20();
        registry = new EchidnaMockRegistry(address(token));
        staking = new MIMHOStaking(address(registry));

        actorA = new EchidnaActor(staking, token);
        actorB = new EchidnaActor(staking, token);
        actorC = new EchidnaActor(staking, token);

        token.mint(address(actorA), INITIAL_BALANCE);
        token.mint(address(actorB), INITIAL_BALANCE);
        token.mint(address(actorC), INITIAL_BALANCE);

        token.mint(address(this), INITIAL_REWARD_FUND);
        token.approve(address(staking), type(uint256).max);
        staking.fundRewards(INITIAL_REWARD_FUND);
    }

    function actionStake(uint8 actorSeed, uint256 amount) external {
        EchidnaActor actor = _actor(actorSeed);
        uint256 actorBalance = token.balanceOf(address(actor));

        if (actorBalance < MIN_STAKE) return;

        uint256 maxAmount = actorBalance;
        if (maxAmount > MAX_STAKE) {
            maxAmount = MAX_STAKE;
        }

        amount = _bound(amount, MIN_STAKE, maxAmount);

        try actor.stake(amount) {} catch {}
    }

    function actionUnstake(uint8 actorSeed, uint256 amount) external {
        EchidnaActor actor = _actor(actorSeed);

        uint256 currentStake = _stakeOf(address(actor));
        if (currentStake == 0) return;

        amount = _bound(amount, 1, currentStake);

        try actor.unstake(amount) {} catch {}
    }

    function actionClaim(uint8 actorSeed) external {
        EchidnaActor actor = _actor(actorSeed);
        try actor.claim() {} catch {}
    }

    function actionSetReinvest(uint8 actorSeed, bool enabled) external {
        EchidnaActor actor = _actor(actorSeed);
        try actor.setReinvest(enabled) {} catch {}
    }

    function echidna_total_staked_is_backed_by_token_balance() external view returns (bool) {
        return token.balanceOf(address(staking)) >= staking.totalStaked();
    }

    function echidna_balance_covers_total_staked_plus_reward_reserve() external view returns (bool) {
        return token.balanceOf(address(staking)) >= staking.totalStaked() + staking.rewardReserve();
    }

    function echidna_actor_stakes_match_total_staked() external view returns (bool) {
        uint256 sum =
            _stakeOf(address(actorA)) +
            _stakeOf(address(actorB)) +
            _stakeOf(address(actorC));

        return sum == staking.totalStaked();
    }

    function echidna_reward_reserve_never_exceeds_contract_balance() external view returns (bool) {
        return staking.rewardReserve() <= token.balanceOf(address(staking));
    }

    function echidna_total_staked_never_exceeds_initial_actor_supply_plus_rewards() external view returns (bool) {
        uint256 maxPossible =
            (INITIAL_BALANCE * 3) +
            INITIAL_REWARD_FUND;

        return staking.totalStaked() <= maxPossible;
    }

    function _actor(uint8 actorSeed) internal view returns (EchidnaActor) {
        uint8 index = actorSeed % 3;

        if (index == 0) return actorA;
        if (index == 1) return actorB;
        return actorC;
    }

    function _stakeOf(address user) internal view returns (uint256 amount) {
        (amount,,,,,,) = staking.getUser(user);
    }

    function _bound(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (value % (max - min + 1));
    }
}

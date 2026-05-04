// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../src/token.sol";

contract EchidnaTokenRegistry {
    mapping(bytes32 => address) public contractsByKey;

    function set(bytes32 key, address value) external {
        contractsByKey[key] = value;
    }

    function getContract(bytes32 key) external view returns (address) {
        return contractsByKey[key];
    }
}

contract EchidnaTokenActor {
    MIMHO public token;

    constructor(MIMHO token_) {
        token = token_;
    }

    function transfer(address to, uint256 amount) external {
        token.transfer(to, amount);
    }

    function approve(address spender, uint256 amount) external {
        token.approve(spender, amount);
    }

    function transferFrom(address from, address to, uint256 amount) external {
        token.transferFrom(from, to, amount);
    }
}

contract EchidnaToken {
    MIMHO public token;
    EchidnaTokenRegistry public registry;

    EchidnaTokenActor public alice;
    EchidnaTokenActor public bob;
    EchidnaTokenActor public carol;
    EchidnaTokenActor public pair;

    address public stakingTarget = address(0x5700);
    address public marketingWallet = address(0xBEEF);

    address public constant FOUNDER = 0x3b50433D64193923199aAf209eE8222B9c728Fbd;
    address public constant LP_RESERVE = 0xb891C4e94a1F4B7Aa35d21BbA37D245909B6ad95;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant TOTAL_SUPPLY = 1_000_000_000_000 ether;
    uint256 public constant MIN_SUPPLY = 500_000_000_000 ether;
    uint256 public constant MAX_ACTION_AMOUNT = 2_000_000 ether;

    bytes32 public constant KEY_STAKING = keccak256("STAKING_CONTRACT");
    bytes32 public constant KEY_MARKETING_WALLET = keccak256("MARKETING_WALLET");

    constructor() {
        token = new MIMHO();
        registry = new EchidnaTokenRegistry();

        registry.set(KEY_STAKING, stakingTarget);
        registry.set(KEY_MARKETING_WALLET, marketingWallet);

        token.setRegistry(address(registry));

        alice = new EchidnaTokenActor(token);
        bob = new EchidnaTokenActor(token);
        carol = new EchidnaTokenActor(token);
        pair = new EchidnaTokenActor(token);

        token.transfer(address(alice), 10_000_000 ether);
        token.transfer(address(bob), 10_000_000 ether);
        token.transfer(address(carol), 10_000_000 ether);

        // Seed liquidity before AMM marking to avoid setup tax.
        token.transfer(address(pair), 100_000_000 ether);

        token.setAMMPair(address(pair), true);
        token.enableTrading();
    }

    function actionWalletTransfer(uint8 fromSeed, uint8 toSeed, uint256 amount) external {
        EchidnaTokenActor fromActor = _actor(fromSeed);
        EchidnaTokenActor toActor = _actor(toSeed);

        if (address(fromActor) == address(toActor)) return;

        uint256 bal = token.balanceOf(address(fromActor));
        if (bal == 0) return;

        uint256 maxAmount = bal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = _bound(amount, 1, maxAmount);

        try fromActor.transfer(address(toActor), amount) {} catch {}
    }

    function actionSell(uint8 actorSeed, uint256 amount) external {
        EchidnaTokenActor seller = _actor(actorSeed);

        uint256 bal = token.balanceOf(address(seller));
        if (bal == 0) return;

        uint256 maxAmount = bal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = _bound(amount, 1, maxAmount);

        try seller.transfer(address(pair), amount) {} catch {}
    }

    function actionBuy(uint8 actorSeed, uint256 amount) external {
        EchidnaTokenActor buyer = _actor(actorSeed);

        uint256 pairBal = token.balanceOf(address(pair));
        if (pairBal == 0) return;

        uint256 maxAmount = pairBal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = _bound(amount, 1, maxAmount);

        try pair.transfer(address(buyer), amount) {} catch {}
    }

    function actionApproveAndTransferFrom(
        uint8 ownerSeed,
        uint8 spenderSeed,
        uint8 toSeed,
        uint256 amount
    ) external {
        EchidnaTokenActor tokenOwner = _actor(ownerSeed);
        EchidnaTokenActor spender = _actor(spenderSeed);
        EchidnaTokenActor toActor = _actor(toSeed);

        if (address(tokenOwner) == address(spender)) return;

        uint256 bal = token.balanceOf(address(tokenOwner));
        if (bal == 0) return;

        uint256 maxAmount = bal;
        if (maxAmount > MAX_ACTION_AMOUNT) {
            maxAmount = MAX_ACTION_AMOUNT;
        }

        amount = _bound(amount, 1, maxAmount);

        try tokenOwner.approve(address(spender), amount) {} catch {
            return;
        }

        try spender.transferFrom(address(tokenOwner), address(toActor), amount) {} catch {}
    }

    function echidna_total_supply_constant() external view returns (bool) {
        return token.totalSupply() == TOTAL_SUPPLY;
    }

    function echidna_known_balances_equal_total_supply() external view returns (bool) {
        uint256 tracked =
            token.balanceOf(address(this)) +
            token.balanceOf(address(alice)) +
            token.balanceOf(address(bob)) +
            token.balanceOf(address(carol)) +
            token.balanceOf(address(pair)) +
            token.balanceOf(FOUNDER) +
            token.balanceOf(LP_RESERVE) +
            token.balanceOf(DEAD) +
            token.balanceOf(stakingTarget) +
            token.balanceOf(marketingWallet);

        return tracked == TOTAL_SUPPLY;
    }

    function echidna_circulating_supply_matches_dead_balance() external view returns (bool) {
        return token.circulatingSupply() == TOTAL_SUPPLY - token.balanceOf(DEAD);
    }

    function echidna_burn_floor_flag_matches_supply_math() external view returns (bool) {
        bool expected = (TOTAL_SUPPLY - token.balanceOf(DEAD)) <= MIN_SUPPLY;
        return token.burnFloorReached() == expected;
    }

    function echidna_trading_remains_enabled() external view returns (bool) {
        return token.isTradingEnabled();
    }

    function _actor(uint8 seed) internal view returns (EchidnaTokenActor) {
        uint8 index = seed % 3;

        if (index == 0) return alice;
        if (index == 1) return bob;
        return carol;
    }

    function _bound(uint256 value, uint256 min, uint256 max) internal pure returns (uint256) {
        if (max <= min) return min;
        return min + (value % (max - min + 1));
    }
}

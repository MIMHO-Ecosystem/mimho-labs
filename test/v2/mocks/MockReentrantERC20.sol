// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IReentrantTarget {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function claim() external;
    function fundRewards(uint256 amount) external;
}

contract MockReentrantERC20 {
    string public constant name = "Reentrant Mock";
    string public constant symbol = "REENTRANT";
    uint8 public constant decimals = 18;

    enum AttackMode {
        None,
        Stake,
        Unstake,
        Claim,
        FundRewards
    }

    AttackMode public attackMode;
    address public target;
    bool public attackEnabled;
    bool internal entered;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function setTarget(address target_) external {
        target = target_;
    }

    function setAttackMode(uint8 mode) external {
        require(mode <= uint8(AttackMode.FundRewards), "BAD_MODE");
        attackMode = AttackMode(mode);
    }

    function setAttackEnabled(bool enabled) external {
        attackEnabled = enabled;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _maybeAttack();

        require(balanceOf[msg.sender] >= amount, "INSUFFICIENT_BAL");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _maybeAttack();

        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "ALLOWANCE");
        require(balanceOf[from] >= amount, "INSUFFICIENT_BAL");

        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function _maybeAttack() internal {
        if (!attackEnabled) return;
        if (entered) return;
        if (target == address(0)) return;

        entered = true;

        if (attackMode == AttackMode.Stake) {
            try IReentrantTarget(target).stake(100_000 ether) {} catch {}
        } else if (attackMode == AttackMode.Unstake) {
            try IReentrantTarget(target).unstake(1 ether) {} catch {}
        } else if (attackMode == AttackMode.Claim) {
            try IReentrantTarget(target).claim() {} catch {}
        } else if (attackMode == AttackMode.FundRewards) {
            try IReentrantTarget(target).fundRewards(1 ether) {} catch {}
        }

        entered = false;
    }
}

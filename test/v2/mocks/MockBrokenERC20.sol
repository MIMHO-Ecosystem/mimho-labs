// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockBrokenERC20 {
    string public constant name = "Broken Mock";
    string public constant symbol = "BROKEN";
    uint8 public constant decimals = 18;

    bool public failTransfer;
    bool public failTransferFrom;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function setFailTransfer(bool status) external {
        failTransfer = status;
    }

    function setFailTransferFrom(bool status) external {
        failTransferFrom = status;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (failTransfer) return false;

        require(balanceOf[msg.sender] >= amount, "INSUFFICIENT_BAL");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (failTransferFrom) return false;

        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "ALLOWANCE");
        require(balanceOf[from] >= amount, "INSUFFICIENT_BAL");

        allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}
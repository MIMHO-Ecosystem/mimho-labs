// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC20Like {
    function transferFrom(address f, address t, uint256 v) external returns (bool);
}

contract MockRouter {
    // Captura o último call para asserts
    address public lastToken;
    uint256 public lastAmountTokenDesired;
    uint256 public lastAmountTokenMin;
    uint256 public lastAmountETHMin;
    address public lastTo;
    uint256 public lastDeadline;
    uint256 public lastMsgValue;

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        lastToken = token;
        lastAmountTokenDesired = amountTokenDesired;
        lastAmountTokenMin = amountTokenMin;
        lastAmountETHMin = amountETHMin;
        lastTo = to;
        lastDeadline = deadline;
        lastMsgValue = msg.value;

        // Simula router puxando os tokens do caller (Inject contract)
        require(IERC20Like(token).transferFrom(msg.sender, address(this), amountTokenDesired), "TF_FAIL");

        // Retorna valores previsíveis
        amountToken = amountTokenDesired;
        amountETH = msg.value;
        liquidity = 123456; // qualquer número fixo
    }
}

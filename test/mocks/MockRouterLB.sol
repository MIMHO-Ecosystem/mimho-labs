// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockFactoryLB} from "./MockFactoryLB.sol";
import {MockPairERC20} from "./MockPairERC20.sol";

contract MockRouterLB {
    address public immutable WETH_ADDR;
    MockFactoryLB public immutable FACTORY;

    // last call captures (pra asserts)
    address public lastToken;
    uint256 public lastAmountTokenDesired;
    uint256 public lastAmountTokenMin;
    uint256 public lastAmountETHMin;
    address public lastTo;
    uint256 public lastDeadline;
    uint256 public lastMsgValue;

    uint256 public constant LP_MINTED = 123456;

    constructor(address weth_, address factory_) {
        WETH_ADDR = weth_;
        FACTORY = MockFactoryLB(factory_);
    }

    function factory() external view returns (address) {
        return address(FACTORY);
    }

    function WETH() external view returns (address) {
        return WETH_ADDR;
    }

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

        // mint LP to `to` on the pair token
        address pair = FACTORY.pair();
        require(pair != address(0), "ROUTER: pair missing");
        MockPairERC20(pair).mint(to, LP_MINTED);

        // we "pretend" everything was used
        return (amountTokenDesired, msg.value, LP_MINTED);
    }
}

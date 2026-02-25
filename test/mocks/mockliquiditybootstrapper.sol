// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockLiquidityBootstrapper {
    uint256 public receivedBNB;
    uint256 public receiveCalls;

    bool public shouldRevertReceivePresale;

    event ReceivedPresaleBNB(address indexed from, uint256 amount);
    event ReceivedPlainBNB(address indexed from, uint256 amount);

    // Simula o método real
    function receivePresaleBNB() external payable {
        if (shouldRevertReceivePresale) revert("MOCK_LB_REVERT");
        receivedBNB += msg.value;
        receiveCalls += 1;
        emit ReceivedPresaleBNB(msg.sender, msg.value);
    }

    // Para o fallback "claimPendingNative" (envio nativo direto)
    receive() external payable {
        receivedBNB += msg.value;
        emit ReceivedPlainBNB(msg.sender, msg.value);
    }

    function setRevertReceivePresale(bool v) external {
        shouldRevertReceivePresale = v;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockVesting {
    // last call tracking
    address public lastBeneficiary;
    uint256 public lastTotalPurchasedTokens;
    uint16 public lastTgeBps;
    uint16 public lastWeeklyBps;
    uint64 public lastStartTimestamp;

    uint256 public calls;

    event PresaleVestingRegistered(
        address indexed beneficiary,
        uint256 totalPurchasedTokens,
        uint16 tgeBps,
        uint16 weeklyBps,
        uint64 startTimestamp
    );

    function registerPresaleVesting(
        address beneficiary,
        uint256 totalPurchasedTokens,
        uint16 tgeBps,
        uint16 weeklyBps,
        uint64 startTimestamp
    ) external {
        lastBeneficiary = beneficiary;
        lastTotalPurchasedTokens = totalPurchasedTokens;
        lastTgeBps = tgeBps;
        lastWeeklyBps = weeklyBps;
        lastStartTimestamp = startTimestamp;
        calls += 1;

        emit PresaleVestingRegistered(beneficiary, totalPurchasedTokens, tgeBps, weeklyBps, startTimestamp);
    }
}

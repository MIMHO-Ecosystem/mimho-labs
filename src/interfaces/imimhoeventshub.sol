// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IMIMHOEventsHub {
    function emitEvent(
        bytes32 module,
        bytes32 action,
        address caller,
        uint256 value,
        bytes calldata data
    ) external;
}

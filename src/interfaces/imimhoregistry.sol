// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IMIMHORegistry {
    function getContract(bytes32 key) external view returns (address);
}

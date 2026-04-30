// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockRegistry {
    address public token;

    constructor(address _token) {
        token = _token;
    }

    function getContract(bytes32) external view returns (address) {
        return token;
    }

    function KEY_MIMHO_TOKEN() external pure returns (bytes32) {
        return keccak256("TOKEN");
    }

    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) {
        return keccak256("EVENTS");
    }

    function KEY_MIMHO_STRATEGY_HUB() external pure returns (bytes32) {
        return keccak256("STRATEGY");
    }

    function KEY_MIMHO_SCORE() external pure returns (bytes32) {
        return keccak256("SCORE");
    }

    function KEY_MIMHO_SECURITY_WALLET() external pure returns (bytes32) {
        return keccak256("SECURITY");
    }

    function KEY_MIMHO_MART() external pure returns (bytes32) {
        return keccak256("MART");
    }

    function KEY_MIMHO_BET() external pure returns (bytes32) {
        return keccak256("BET");
    }

    function KEY_MIMHO_GATEWAY() external pure returns (bytes32) {
        return keccak256("GATEWAY");
    }

    function KEY_MIMHO_VERITAS() external pure returns (bytes32) {
        return keccak256("VERITAS");
    }
}
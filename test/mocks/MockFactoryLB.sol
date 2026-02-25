// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockPairERC20} from "./MockPairERC20.sol";

contract MockFactoryLB {
    address public pair; // single pair for tests

    function getPair(address, address) external view returns (address) {
        return pair;
    }

    function createPair(address, address) external returns (address) {
        MockPairERC20 p = new MockPairERC20();
        pair = address(p);
        return pair;
    }
}

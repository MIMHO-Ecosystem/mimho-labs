// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockRegistryLB {
    mapping(bytes32 => address) public get;

    bytes32 public constant K_EVENTS = keccak256("MIMHO_EVENTS_HUB");
    bytes32 public constant K_INJECT = keccak256("MIMHO_INJECT_LIQUIDITY");

    function set(bytes32 k, address v) external {
        get[k] = v;
    }

    function getContract(bytes32 key) external view returns (address) {
        return get[key];
    }

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32) { return K_EVENTS; }
    function KEY_MIMHO_INJECT_LIQUIDITY() external view returns (bytes32) { return K_INJECT; }

    function isEcosystemContract(address) external pure returns (bool) { return true; }
}

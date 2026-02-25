// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockRegistryPresale {
    mapping(bytes32 => address) public addr;

    // chaves fixas (simulando o Registry real)
    bytes32 internal constant K_EVENTS  = keccak256("MIMHO_EVENTS_HUB");
    bytes32 internal constant K_TOKEN   = keccak256("MIMHO_TOKEN");
    bytes32 internal constant K_VESTING = keccak256("MIMHO_VESTING");
    bytes32 internal constant K_LB      = keccak256("MIMHO_LIQUIDITY_BOOTSTRAPER");

    function set(bytes32 key, address a) external {
        addr[key] = a;
    }

    function getContract(bytes32 key) external view returns (address) {
        return addr[key];
    }

    // getters de KEYS (no seu protocolo você usa getter do próprio registry)
    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32) { return K_EVENTS; }
    function KEY_MIMHO_TOKEN() external view returns (bytes32) { return K_TOKEN; }
    function KEY_MIMHO_VESTING() external view returns (bytes32) { return K_VESTING; }
    function KEY_MIMHO_LIQUIDITY_BOOTSTRAPER() external view returns (bytes32) { return K_LB; }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract MockRegistry {
    mapping(bytes32 => address) public contractsMap;

    // Chaves fixas para o teste (não precisa bater com o Registry real,
    // só precisa ser CONSISTENTE dentro do mock)
    bytes32 private constant K_EVENTS = keccak256("KEY_MIMHO_EVENTS_HUB");
    bytes32 private constant K_TOKEN  = keccak256("KEY_MIMHO_TOKEN");
    bytes32 private constant K_DEX    = keccak256("KEY_MIMHO_DEX");
    bytes32 private constant K_DAO    = keccak256("KEY_MIMHO_DAO");
    bytes32 private constant K_VC     = keccak256("KEY_MIMHO_VOTING_CONTROLLER");

    function set(bytes32 key, address addr) external {
        contractsMap[key] = addr;
    }

    function getContract(bytes32 key) external view returns (address) {
        return contractsMap[key];
    }

    function KEY_MIMHO_EVENTS_HUB() external view returns (bytes32) { return K_EVENTS; }
    function KEY_MIMHO_TOKEN() external view returns (bytes32) { return K_TOKEN; }
    function KEY_MIMHO_DEX() external view returns (bytes32) { return K_DEX; }
    function KEY_MIMHO_DAO() external view returns (bytes32) { return K_DAO; }
    function KEY_MIMHO_VOTING_CONTROLLER() external view returns (bytes32) { return K_VC; }
}

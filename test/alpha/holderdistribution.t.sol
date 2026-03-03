// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {MIMHOHolderDistributionVault} from "../../src/holderdistribution.sol";

/* ---------------------------------------------
   Minimal mocks (self-contained alpha test)
---------------------------------------------- */

contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "BAL_LOW");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        require(a >= amount, "ALLOW_LOW");
        require(balanceOf[from] >= amount, "BAL_LOW");
        allowance[from][msg.sender] = a - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockRegistry {
    mapping(address => bool) public eco;

    function setEco(address a, bool v) external {
        eco[a] = v;
    }

    function getContract(bytes32) external pure returns (address) {
        return address(0);
    }

    function isEcosystemContract(address a) external view returns (bool) {
        return eco[a];
    }
}

contract DummyClaimer {
    function callClaim(address vault, uint256 amount, bytes32[] calldata proof) external {
        MIMHOHolderDistributionVault(vault).claim(amount, proof);
    }
}

contract HolderDistributionAlphaTest is Test {
    MockERC20 token;
    MockRegistry reg;
    MIMHOHolderDistributionVault vault;

    address owner = address(this);
    address alice = address(0xA11CE);

    function setUp() public {
        token = new MockERC20();
        reg = new MockRegistry();
        vault = new MIMHOHolderDistributionVault(address(reg), address(token));

        token.mint(owner, 1_000_000e18);
        token.approve(address(vault), type(uint256).max);
    }

    // helper that always returns a new empty proof array
    function getEmptyProof() internal pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    function _leaf(address user, uint256 amount, uint256 roundId) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(user, amount, roundId))));
    }

    function test_Deploy_OwnerExcludedByDefault() public {
        assertTrue(vault.excluded(owner));
    }

    function test_Deposit_Works() public {
        uint256 amt = 1000e18;
        uint256 beforeVault = token.balanceOf(address(vault));
        vault.deposit(amt);
        uint256 afterVault = token.balanceOf(address(vault));
        assertEq(afterVault - beforeVault, amt);
    }

    function test_OpenRound_AndClaim_SingleLeafProof_Works() public {
        uint256 roundTotal = 10_000e18;
        vault.deposit(roundTotal);

        uint256 roundId = vault.currentRoundId() + 1;
        uint256 claimAmt = 1234e18;
        bytes32 root = _leaf(alice, claimAmt, roundId);

        vault.openRound(root, roundTotal, 0);

        bytes32[] memory proof0 = getEmptyProof();

        uint256 beforeAlice = token.balanceOf(alice);
        vm.prank(alice);
        vault.claim(claimAmt, proof0);
        uint256 afterAlice = token.balanceOf(alice);

        assertEq(afterAlice - beforeAlice, claimAmt);
        assertTrue(vault.hasClaimed(vault.currentRoundId(), alice));
    }

    function test_Claim_Twice_Reverts() public {
        uint256 roundTotal = 10_000e18;
        vault.deposit(roundTotal);

        uint256 roundId = vault.currentRoundId() + 1;
        uint256 claimAmt = 100e18;
        bytes32 root = _leaf(alice, claimAmt, roundId);

        vault.openRound(root, roundTotal, 0);

        bytes32[] memory proof0 = getEmptyProof();

        vm.prank(alice);
        vault.claim(claimAmt, proof0);

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: already claimed"));
        vault.claim(claimAmt, proof0);
    }

    function test_ExcludedAddress_Reverts() public {
        uint256 roundTotal = 10_000e18;
        vault.deposit(roundTotal);

        vault.excludeAddress(alice);

        uint256 roundId = vault.currentRoundId() + 1;
        uint256 claimAmt = 100e18;
        bytes32 root = _leaf(alice, claimAmt, roundId);

        vault.openRound(root, roundTotal, 0);

        bytes32[] memory proof0 = getEmptyProof();

        vm.prank(alice);
        vm.expectRevert(bytes("MIMHO: excluded"));
        vault.claim(claimAmt, proof0);
    }

    function test_EcosystemContractCaller_Reverts() public {
        uint256 roundTotal = 10_000e18;
        vault.deposit(roundTotal);

        DummyClaimer dc = new DummyClaimer();
        reg.setEco(address(dc), true);

        uint256 roundId = vault.currentRoundId() + 1;
        uint256 claimAmt = 100e18;

        bytes32 root = _leaf(address(dc), claimAmt, roundId);
        vault.openRound(root, roundTotal, 0);

        bytes32[] memory proof0 = getEmptyProof();

        vm.expectRevert(bytes("MIMHO: ecosystem contract"));
        dc.callClaim(address(vault), claimAmt, proof0);
    }

    function test_Pause_Blocks_Deposit_And_Claim() public {
        uint256 roundTotal = 10_000e18;
        vault.deposit(roundTotal);

        uint256 roundId = vault.currentRoundId() + 1;
        uint256 claimAmt = 100e18;
        bytes32 root = _leaf(alice, claimAmt, roundId);

        vault.openRound(root, roundTotal, 0);

        vault.pauseEmergencial();

        vm.expectRevert("Pausable: paused");
        vault.deposit(1e18);

        bytes32[] memory proof0 = getEmptyProof();

        vm.prank(alice);
        vm.expectRevert("Pausable: paused");
        vault.claim(claimAmt, proof0);
    }
}

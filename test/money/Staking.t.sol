// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// ajuste o import conforme o seu nome real do arquivo
import "../../src/staking.sol";

/*//////////////////////////////////////////////////////////////
                        MOCK ERC20 (MINTABLE)
//////////////////////////////////////////////////////////////*/
contract MockMIMHO is ERC20 {
    constructor() ERC20("MockMIMHO", "mMIMHO") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/*//////////////////////////////////////////////////////////////
                        MOCK REGISTRY
- Implementa getContract(key)
- Implementa os KEY_* getters usados no staking
//////////////////////////////////////////////////////////////*/
contract MockRegistry is IMIMHORegistry {
    mapping(bytes32 => address) public addr;

    function set(bytes32 key, address value) external {
        addr[key] = value;
    }

    function getContract(bytes32 key) external view returns (address) {
        return addr[key];
    }

    // ---- KEYS (match staking interface) ----
    function KEY_MIMHO_TOKEN() external pure returns (bytes32) { return keccak256("KEY_MIMHO_TOKEN"); }
    function KEY_MIMHO_DAO() external pure returns (bytes32) { return keccak256("KEY_MIMHO_DAO"); }
    function KEY_MIMHO_EVENTS_HUB() external pure returns (bytes32) { return keccak256("KEY_MIMHO_EVENTS_HUB"); }
    function KEY_MIMHO_STRATEGY_HUB() external pure returns (bytes32) { return keccak256("KEY_MIMHO_STRATEGY_HUB"); }

    function KEY_MIMHO_SCORE() external pure returns (bytes32) { return keccak256("KEY_MIMHO_SCORE"); }
    function KEY_MIMHO_SECURITY_WALLET() external pure returns (bytes32) { return keccak256("KEY_MIMHO_SECURITY_WALLET"); }
    function KEY_MIMHO_MART() external pure returns (bytes32) { return keccak256("KEY_MIMHO_MART"); }
    function KEY_MIMHO_BET() external pure returns (bytes32) { return keccak256("KEY_MIMHO_BET"); }

    function KEY_MIMHO_GATEWAY() external pure returns (bytes32) { return keccak256("KEY_MIMHO_GATEWAY"); }
    function KEY_MIMHO_VERITAS() external pure returns (bytes32) { return keccak256("KEY_MIMHO_VERITAS"); }
}

contract StakingTest is Test {
    MockRegistry reg;
    MockMIMHO token;
    MIMHOStaking staking;

    address owner;
    address alice = address(0xA11CE);
    address bob   = address(0xB0B);

    uint256 constant ONE = 1e18;

    function setUp() public {
        owner = address(this);

        // 1) Deploy mocks
        reg = new MockRegistry();
        token = new MockMIMHO();

        // 2) Wire registry -> token (staking constructor REQUIRE isso)
        bytes32 KEY_TOKEN = reg.KEY_MIMHO_TOKEN();
        reg.set(KEY_TOKEN, address(token));

        // 3) Deploy staking pointing to registry
        staking = new MIMHOStaking(address(reg));

        // 4) Mint balances for tests
        token.mint(alice, 2_000_000 * ONE);
        token.mint(bob,   2_000_000 * ONE);
        token.mint(owner, 5_000_000_000 * ONE); // pra fundRewards

        // 5) Approvals
        vm.prank(alice);
        token.approve(address(staking), type(uint256).max);

        vm.prank(bob);
        token.approve(address(staking), type(uint256).max);

        token.approve(address(staking), type(uint256).max);

        // 6) Safety: deixar trading/fee do token fora disso (mock é simples)
    }

    /*//////////////////////////////////////////////////////////////
                            BASIC: stake
    //////////////////////////////////////////////////////////////*/
    function test_StakeIncreasesUserAndTotal() public {
        uint256 amt = 200_000 * ONE;

        vm.prank(alice);
        staking.stake(amt);

        (uint256 staked,,,,,,) = staking.getUser(alice);

        assertEq(staked, amt, "stake amount mismatch");
        (uint256 total,, , , ,) = staking.getStats();
        assertEq(total, amt, "totalStaked mismatch");

        // token moved to staking
        assertEq(token.balanceOf(address(staking)), amt, "staking contract should hold principal");
    }

    /*//////////////////////////////////////////////////////////////
                            BASIC: unstake
    //////////////////////////////////////////////////////////////*/
    function test_UnstakeReturnsPrincipal() public {
        uint256 amt = 200_000 * ONE;

        vm.prank(alice);
        staking.stake(amt);

        uint256 balBefore = token.balanceOf(alice);

        vm.prank(alice);
        staking.unstake(50_000 * ONE);

        uint256 balAfter = token.balanceOf(alice);
        assertEq(
    balAfter,
    balBefore + (50_000 * ONE),
    "alice balance mismatch after unstake"
);

        (uint256 staked,,,,,,) = staking.getUser(alice);
        assertEq(staked, amt - (50_000 * ONE), "remaining stake mismatch");

        (uint256 total,, , , ,) = staking.getStats();
        assertEq(total, amt - (50_000 * ONE), "totalStaked mismatch after unstake");
    }

    /*//////////////////////////////////////////////////////////////
                        fundRewards & sync reserve
    //////////////////////////////////////////////////////////////*/
    function test_FundRewardsIncreasesReserve() public {
        uint256 fund = 1_000_000 * ONE;

        staking.fundRewards(fund);

        (,uint256 reserve,,,,) = staking.getStats();
        assertEq(reserve, fund, "reserve should match funded amount");

        // contract balance = reserve (no stake yet)
        assertEq(token.balanceOf(address(staking)), fund, "staking contract should hold reward reserve");
    }

    /*//////////////////////////////////////////////////////////////
                        claim: happy path (requires you implemented)
    - stake
    - fund rewards
    - wait > minHoldToEarn
    - wait some time accrue
    - claim
    //////////////////////////////////////////////////////////////*/
    function test_ClaimPaysRewardsAfterMinHold() public {
        uint256 stakeAmt = 200_000 * ONE;
        uint256 fund = 5_000_000 * ONE;

        vm.prank(alice);
        staking.stake(stakeAmt);

        staking.fundRewards(fund);

        // minHoldToEarn default = 7 days
        vm.warp(block.timestamp + 8 days);

        // let time pass to generate some reward
        vm.warp(block.timestamp + 3 days);

        uint256 balBefore = token.balanceOf(alice);

        vm.prank(alice);
        staking.claim();

        uint256 balAfter = token.balanceOf(alice);
        assertGt(balAfter, balBefore, "claim should increase alice balance");

        // reserve should go down (unless you reinvest)
        (,uint256 reserve,,,,) = staking.getStats();
        assertLt(reserve, fund, "reserve should decrease after claim (if paid out)");
    }

    /*//////////////////////////////////////////////////////////////
                        claim: cooldown enforcement
    - claim once
    - immediately claim again -> revert
    //////////////////////////////////////////////////////////////*/
    function test_ClaimCooldownReverts() public {
        uint256 stakeAmt = 200_000 * ONE;
        uint256 fund = 5_000_000 * ONE;

        vm.prank(alice);
        staking.stake(stakeAmt);

        staking.fundRewards(fund);

        vm.warp(block.timestamp + 8 days);
        vm.warp(block.timestamp + 2 days);

        vm.prank(alice);
        staking.claim();

        // immediately again should revert if cooldown enforced
        vm.prank(alice);
        vm.expectRevert(); // message depends on your require, so generic
        staking.claim();
    }

    /*//////////////////////////////////////////////////////////////
                        weekly cap clamp
    - set weeklyLimit small
    - generate big accrued time
    - claim must not exceed weeklyLimit/maxClaimBps
    //////////////////////////////////////////////////////////////*/
    function test_WeeklyCapClampsClaim() public {
        uint256 stakeAmt = 1_000_000 * ONE;
        uint256 fund = 100_000_000 * ONE;

        vm.prank(alice);
        staking.stake(stakeAmt);

        staking.fundRewards(fund);

        // shrink weekly to make clamp visible
        // setParams(
        //  minStakeAmountNew, minHoldToEarnNew, claimCooldownNew, weeklyLimitNew,
        //  maxClaimBpsOfWeeklyNew, baseApyBpsTopNew, maxTotalApyBpsNew, maxBoostBpsNew
        // )
        staking.setParams(
            100_000 * ONE,
            7 days,
            7 days,
            1_000 * ONE,   // weeklyLimit = 1000
            500,           // maxClaimBpsOfWeekly = 5% (50 tokens max/claim)
            3500,
            4000,
            500
        );

        vm.warp(block.timestamp + 8 days);
        vm.warp(block.timestamp + 30 days); // create big accrued

        uint256 balBefore = token.balanceOf(alice);

        vm.prank(alice);
        staking.claim();

        uint256 balAfter = token.balanceOf(alice);

        // max per claim = weeklyLimit * 5% = 50 tokens
        uint256 maxPerClaim = (1_000 * ONE * 500) / 10_000;
        assertLe(balAfter - balBefore, maxPerClaim, "claim should be clamped to max per claim");
    }
}

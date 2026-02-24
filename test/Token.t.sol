// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

// Ajuste se o nome do contrato no token.sol NÃO for "MIMHO"
import "../src/token.sol";

contract TokenTest is Test {
    MIMHO token;

    // owner = deployer real (este contrato de teste)
    address owner;

    address user  = address(0xB0B);
    address user2 = address(0xC0C);
    address pair  = address(0xAA01);

    // guardamos quanto mandamos pro pair no setUp (o "seed" bruto)
    uint256 seedSent;

    function setUp() public {
        // Deployer do token = este contrato de teste, então o TOTAL_SUPPLY vem pra cá
        token = new MIMHO();
        owner = address(this);

        // Tenta habilitar trading e marcar AMM pair se existir no seu token
        _tryEnableTrading();
        _trySetAMMPair(pair, true);

        // Seed no "pair" pra simular buy (pair -> user) sem precisar de router
        // ATENÇÃO: como pair é AMM, owner->pair vira SELL e pode cobrar fee.
        seedSent = token.balanceOf(owner) / 10;
        token.transfer(pair, seedSent);
    }

    // ----------------------------
    // Tests
    // ----------------------------

    function test_InitialSupplyToOwner() public {
        // O deployer real é o contrato de teste.
        // Após o seed, o owner perdeu exatamente "seedSent" (independente de fee).
        assertEq(token.balanceOf(owner), token.TOTAL_SUPPLY() - seedSent);

        // totalSupply deve bater com TOTAL_SUPPLY
        assertEq(token.totalSupply(), token.TOTAL_SUPPLY());
    }

    function test_Transfer_Works() public {
        uint256 amt = 1_000 ether;

        token.transfer(user, amt);

        // user NÃO é AMM pair, então wallet->wallet não tem fee
        assertEq(token.balanceOf(user), amt);
    }

    function test_Approve_TransferFrom() public {
        uint256 amt = 5_000 ether;

        token.approve(user, amt);

        vm.prank(user);
        token.transferFrom(owner, user2, amt);

        // user2 NÃO é AMM pair, então wallet->wallet não tem fee
        assertEq(token.balanceOf(user2), amt);
    }

    function test_TransferZeroReverts() public {
        vm.expectRevert();
        token.transfer(address(0), 1);
    }

    function test_BuyFromPairWorksIfSeeded() public {
        // Simula um buy: pair -> user
        // Como pair é AMM, isso é BUY e cobra 1% (seu padrão).
        uint256 amt = 100 ether;

        vm.prank(pair);
        token.transfer(user, amt);

        // BUY: 1% fee => user recebe 99%
        // (em basis points: 100 bp / 10000 = 1%)
        uint256 expectedNet = amt - ((amt * 100) / 10_000);

        assertEq(token.balanceOf(user), expectedNet);
    }
       
       function test_SellLPFeeGoesToLiquidityReserveWallet() public {
    address seller = address(0xBEEF);

    // Dá tokens ao seller
    uint256 amount = 1_000 ether;
    token.transfer(seller, amount);

    // Marca "pair" como AMM
    _trySetAMMPair(pair, true);

    // Habilita trading se necessário
    _tryEnableTrading();

    uint256 reserveBefore = token.balanceOf(
        token.LIQUIDITY_RESERVE_WALLET()
    );

    // Simula SELL: seller -> pair
    vm.prank(seller);
    token.transfer(pair, amount);

    uint256 reserveAfter = token.balanceOf(
        token.LIQUIDITY_RESERVE_WALLET()
    );

    // 0.18% de 1000 = 1.8 tokens
    uint256 expectedLPFee = (amount * token.SELL_LP_BP()) / token.BP_DIVISOR();

    assertEq(
        reserveAfter - reserveBefore,
        expectedLPFee,
        "LP fee not sent to Liquidity Reserve Wallet"
    );
}      

    // ----------------------------
    // Fuzz (leve, sem quebrar por max-buy)
    // ----------------------------

    function testFuzz_TransferPreservesTotalSupply(uint96 raw) public {
        uint256 amt = uint256(raw);

        uint256 bal = token.balanceOf(owner);
        if (bal == 0) return;

        // limita pra não ficar absurdo
        if (amt > bal / 50) amt = bal / 50;
        if (amt == 0) amt = 1;

        uint256 ts0 = token.totalSupply();

        token.transfer(user, amt);
        vm.prank(user);
        token.transfer(owner, amt);

        assertEq(token.totalSupply(), ts0);
    }

    function testFuzz_ApproveTransferFrom(uint96 raw) public {
        uint256 amt = uint256(raw);

        uint256 bal = token.balanceOf(owner);
        if (bal == 0) return;

        if (amt > bal / 50) amt = bal / 50;
        if (amt == 0) amt = 1;

        token.approve(user, amt);

        vm.prank(user);
        token.transferFrom(owner, user2, amt);

        assertEq(token.balanceOf(user2), amt);
    }

    // ----------------------------
    // Helpers (best-effort)
    // ----------------------------

    function _tryEnableTrading() internal {
        (bool ok1,) = address(token).call(abi.encodeWithSignature("enableTrading()"));
        ok1;

        (bool ok2,) = address(token).call(abi.encodeWithSignature("enableTrading(uint256)", block.timestamp));
        ok2;
    }

    function _trySetAMMPair(address p, bool status) internal {
        (bool ok,) = address(token).call(abi.encodeWithSignature("setAMMPair(address,bool)", p, status));
        ok;
    }
}

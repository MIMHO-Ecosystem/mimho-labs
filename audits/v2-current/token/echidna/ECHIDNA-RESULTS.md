# MIMHO Token V2 — Echidna Results

## Status

Passed.

Echidna was executed against an isolated Token V2 workspace.

## Tool

Echidna 2.3.2

## Target

src/v2/token.sol

## Harness

audits/v2-current/token/echidna/EchidnaToken.t.sol

## Config

audits/v2-current/token/echidna/echidna.yaml

## Campaign Result

Campaign completed with all properties passing.

## Properties Tested

The following Echidna properties passed:

- echidna_circulating_supply_matches_dead_balance
- echidna_burn_floor_flag_matches_supply_math
- echidna_total_supply_constant
- echidna_trading_remains_enabled
- echidna_known_balances_equal_total_supply

## Observed Campaign Data

- Unique instructions: 3394
- Unique codehashes: 4
- Corpus size: 3
- Seed: 7580196099911583610
- Total calls: 5044
- Status: passing

## Interpretation

The Echidna property campaign did not find an invariant violation in the tested Token V2 harness.

The tested invariants focused on:

- total supply immutability
- tracked balances matching total supply
- circulating supply math
- burn floor flag correctness
- trading remaining enabled during random transfer sequences

## Notes

This Echidna result does not replace a manual audit.

It is one layer of the MIMHO V2 security-hardening process, alongside Foundry unit tests, fuzz tests, invariant handler tests, Slither, Aderyn and Mythril.

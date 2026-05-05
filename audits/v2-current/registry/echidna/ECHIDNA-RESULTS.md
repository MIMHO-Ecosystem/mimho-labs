# MIMHO Registry V2 — Echidna Results

## Status

Passed.

Echidna was executed against an isolated Registry V2 workspace.

## Tool

Echidna 2.3.2

## Target

src/v2/registry.sol

## Harness

audits/v2-current/registry/echidna/EchidnaRegistry.t.sol

## Config

audits/v2-current/registry/echidna/echidna.yaml

## Campaign Result

Campaign completed with all properties passing.

## Properties Tested

The following Echidna properties passed:

- echidna_compatibility_getters_match_storage
- echidna_legacy_aliases_remain_consistent
- echidna_wallet_config_matches_storage
- echidna_wallet_values_are_not_ecosystem_contracts_unless_also_contracts
- echidna_registry_never_paused_in_this_harness
- echidna_current_contract_values_are_ecosystem_contracts
- echidna_dao_remains_set
- echidna_core_config_matches_storage

## Observed Campaign Data

- Unique instructions: 3747
- Unique codehashes: 2
- Corpus size: 3
- Seed: 3868421856744123875
- Total calls: 5100
- Status: passing

## Interpretation

The Echidna property campaign did not find an invariant violation in the tested Registry V2 harness.

The tested invariants focused on:

- core configuration consistency
- wallet configuration consistency
- legacy alias consistency
- compatibility getter consistency
- ecosystem contract reference consistency
- wallet values not being incorrectly marked as ecosystem contracts
- DAO remaining set
- Registry not entering paused state in this harness

## Notes

This Echidna result does not replace a manual audit.

It is one layer of the MIMHO V2 security-hardening process, alongside Foundry unit tests, fuzz tests, invariant handler tests, Slither, Aderyn and Mythril.

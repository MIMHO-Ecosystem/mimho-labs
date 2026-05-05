# MIMHO Registry V2 — Final Internal Security Summary

## Status

Passed internal security hardening checkpoint.

This document summarizes the current internal security review status of the MIMHO Registry V2 contract.

## Target

src/v2/registry.sol

## Test Suite

test/v2/registryflow.t.sol

## Current Foundry Result

46 passed
0 failed

## Security Scope Covered

The Registry V2 security-hardening process currently includes:

- unit tests
- handler-based invariant tests
- Registry key resolution tests
- wallet key tests
- contract key tests
- legacy alias tests
- DAO transition tests
- pause/unpause tests
- EventsHub best-effort tests
- partner service tests
- Slither static analysis
- Slither triage
- Aderyn static analysis
- Aderyn fixes and triage
- Echidna property testing
- Mythril symbolic analysis

## Foundry Summary

Foundry test suite result:

46 passed
0 failed

The Foundry suite covers:

- constructor validation
- ownerSafe storage
- Ownable owner setup
- metadata
- protocol neutral views
- DAO setup
- DAO activation
- owner/DAO permission transition
- owner blocked after DAO activation for onlyDAOorOwner paths
- DAO blocked before activation
- pause and unpause
- setMIMHOToken
- setEventsHub
- broken EventsHub best-effort behavior
- setContract
- setWallet
- contract key validation
- wallet key validation
- core configuration checks
- wallet configuration checks
- legacy aliases
- compatibility getters
- partner service allow/remove/expiration
- ecosystem contract reference tracking
- handler-based invariant tests

## Important Design Behavior Validated

### Owner before DAO activation

Before DAO activation, the ownerSafe controls onlyDAOorOwner functions.

### DAO after DAO activation

After DAO activation, only the DAO can call onlyDAOorOwner functions.

The ownerSafe is intentionally blocked from those functions after DAO activation.

### Registry as source of truth

The Registry stores and resolves ecosystem contract addresses, wallet addresses and legacy aliases.

### EventsHub best-effort behavior

EventsHub emission is wrapped so a broken EventsHub does not break future Registry setters.

## Invariant Coverage

The Foundry invariant suite checks:

- checkCoreConfigured matches actual stored core addresses
- checkWalletsConfigured matches actual stored wallet addresses
- legacy aliases remain consistent
- compatibility getters match Registry storage
- current contract values are marked as ecosystem contracts
- wallet values are not marked as ecosystem contracts unless also used as contracts
- Registry does not enter paused state in the invariant handler
- DAO remains set during handler actions

The handler randomly exercises:

- setContract
- setWallet
- setMIMHOToken
- setEventsHub
- setPartnerService

## Slither Result

Slither completed analysis against:

src/v2/registry.sol

Initial actionable findings were fixed.

Fixed items:

- setDAO event ordering was corrected
- setDAO parameter naming was corrected

Remaining Slither findings:

- missing-zero-check
- timestamp
- pragma
- solc-version

Classification:

Remaining findings were triaged and documented.

### missing-zero-check

Accepted as dependency warning.

Reason:

The finding is inside OpenZeppelin Ownable2Step.transferOwnership, not Registry custom logic.

### timestamp

Accepted by design.

Reason:

Partner service authorization intentionally uses block.timestamp for expiration.

### pragma

Accepted as dependency warning.

Reason:

OpenZeppelin dependencies use compatible ^0.8.0 pragmas while the Registry target uses Solidity 0.8.28.

### solc-version

Accepted as dependency warning.

Reason:

The target is compiled with Solidity 0.8.28. The warning is tied to dependency pragma ranges.

## Aderyn Result

Aderyn was executed against an isolated Registry V2 workspace.

Initial observed result:

High: 0
Low: 3

Initial findings:

- centralization risk
- event missing indexed fields
- empty block

Fixes applied:

- PartnerServiceSet validUntil was indexed
- onExternalAction now explicitly returns

Final observed result after fixes:

High: 0
Low: 1

Remaining finding:

- centralization risk for trusted owners

Classification:

Accepted by design with DAO transition.

Reason:

The Registry requires owner-controlled bootstrap before DAO activation because it is the address book for the ecosystem.

Mitigations:

- ownerSafe zero address is blocked
- setDAO can only be called once
- activateDAO requires DAO to be set
- after DAO activation, only DAO can call onlyDAOorOwner functions
- ownerSafe is blocked from onlyDAOorOwner functions after DAO activation
- Foundry tests cover this transition

## Echidna Result

Echidna was executed against an isolated Registry V2 workspace.

Tool version:

Echidna 2.3.2

Campaign result:

Passed.

Properties tested:

- echidna_compatibility_getters_match_storage
- echidna_legacy_aliases_remain_consistent
- echidna_wallet_config_matches_storage
- echidna_wallet_values_are_not_ecosystem_contracts_unless_also_contracts
- echidna_registry_never_paused_in_this_harness
- echidna_current_contract_values_are_ecosystem_contracts
- echidna_dao_remains_set
- echidna_core_config_matches_storage

Observed campaign data:

- Unique instructions: 3747
- Unique codehashes: 2
- Corpus size: 3
- Total calls: 5100
- Status: passing

## Mythril Result

Mythril was executed against an isolated Registry V2 workspace.

Tool version:

Mythril v0.24.8

Final result:

The analysis was completed successfully. No issues were detected.

The successful run used:

- optimizer enabled
- optimizer runs set to 200
- viaIR enabled
- OpenZeppelin remapping configured

Classification:

Passed.

## Current Risk Classification

Current internal classification:

Registry V2 passed the internal security-hardening checkpoint.

This does not mean the contract is risk-free.

The current result means:

- Foundry tests are passing
- handler-based invariants are passing
- Echidna properties are passing
- Mythril detected no issues
- Slither findings were fixed or triaged
- Aderyn findings were fixed or triaged
- owner/DAO transition behavior was tested
- EventsHub best-effort behavior was tested
- key resolution and legacy aliases were tested

## Not a Third-Party Audit

This is an internal security-hardening summary.

This document is not a third-party audit certification.

Recommended wording:

- internal security review
- automated analysis
- security hardening
- test report
- audit artifact

Avoid wording such as:

- fully audited
- certified secure
- guaranteed safe
- risk-free

## Remaining Recommendations Before Mainnet Use

Before production deployment, recommended next steps include:

- manual line-by-line review
- final deployment checklist
- final key list review
- final legacy alias review
- final wallet/address review
- final DAO address review
- final EventsHub address review
- final BscScan verification plan
- independent third-party audit if budget allows

## Final Internal Checkpoint

Current checkpoint:

Foundry: 46 passed, 0 failed
Slither: completed, fixed and triaged
Aderyn: High 0, Low 1 after fixes
Echidna: properties passing
Mythril: no issues detected

Current recommendation:

Registry V2 can move from active test-building into final review status, while the next MIMHO V2 modules begin their own security-hardening cycle.

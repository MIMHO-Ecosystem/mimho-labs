# MIMHO EventsHub V2 — Final Internal Security Summary

## Status

Passed reduced internal security hardening checkpoint.

This document summarizes the current internal security review status of the MIMHO EventsHub V2 contract.

## Target

src/v2/eventshub.sol

## Test Suite

test/v2/eventshubflow.t.sol

## Current Foundry Result

31 passed
0 failed

## V1/V2 Equivalence

EventsHub V2 was created from the existing EventsHub V1 source.

The V1 and V2 files were compared with:

diff -u src/eventshub.sol src/v2/eventshub.sol

Initial result before V2-specific lint fixes:

No diff output.

This means the V2 baseline started as an exact copy of the working V1 EventsHub.

## Security Scope Covered

The EventsHub V2 reduced security-hardening process currently includes:

- Foundry core flow tests
- emission permission tests
- EOA blocking tests
- ecosystem emitter tests
- Registry-as-emitter tests
- blacklist tests
- pause/unpause tests
- DAO transition tests
- payload truncation tests
- canEmit tests
- Slither static analysis
- Slither triage
- Aderyn static analysis
- Aderyn fixes and triage
- Mythril symbolic analysis

## Foundry Summary

Foundry test suite result:

31 passed
0 failed

The Foundry suite covers:

- constructor validation
- zero owner rejection
- zero registry rejection
- metadata
- protocol neutral views
- ecosystem emitter emission
- Registry direct emission
- EOA emission blocking
- non-ecosystem contract blocking
- blacklisted emitter blocking
- invalid module rejection
- invalid action rejection
- invalid caller rejection
- oversized payload truncation
- PayloadTruncated telemetry
- canEmit behavior
- canEmit false when blacklisted
- canEmit false when paused
- setDAO
- activateDAO
- DAO blocked before activation
- DAO allowed after activation
- owner blocked after DAO activation
- pause blocking emitEvent
- unpause restoring emitEvent
- updateRegistry
- zero registry update rejection
- zero blacklist emitter rejection
- hubStatus smoke test

## Important Design Behavior Validated

### EOA Blocking

emitEvent blocks direct EOA calls.

Only contracts can emit HUD events.

### Ecosystem-Only Emission

emitEvent only allows:

- Registry itself
- contracts authorized by Registry as ecosystem contracts

### Blacklist Protection

blacklistedEmitters blocks specific emitter contracts even if they are ecosystem contracts.

### Payload Gas Guard

Oversized event payloads are truncated to MAX_EVENT_DATA_BYTES.

When truncation happens, PayloadTruncated is emitted.

### EventsHub Does Not Admin-Emit

Admin/governance functions do not call emitEvent recursively.

This avoids creating self-referential HUD emissions.

## Slither Result

Slither completed analysis against:

src/v2/eventshub.sol

Initial observed findings:

- assembly
- naming-convention

Fixed item:

- setDAO(address _dao) renamed to setDAO(address daoAddr)

Remaining Slither finding:

- assembly

Classification:

Accepted by design.

Reason:

The assembly block is inside _clipCalldata and is used to copy only the first MAX_EVENT_DATA_BYTES bytes from calldata into memory when the payload is oversized.

This supports the gas guard design.

Mitigations:

- MAX_EVENT_DATA_BYTES hard cap is 1024
- normal payloads bypass the assembly path
- oversized payload behavior is covered by Foundry
- PayloadTruncated telemetry is emitted

## Aderyn Result

Aderyn was executed against an isolated EventsHub V2 workspace.

Initial observed result:

High: 0
Low: 3

Initial findings:

- Event is missing indexed fields
- Modifiers invoked only once can be shoe-horned into the function
- Empty Block

Fixes applied:

- EmitterBlacklisted status was indexed
- onExternalAction was converted from an empty block into explicit no-op logic

Final observed result after fixes:

High: 0
Low: 1

Remaining finding:

- Modifiers invoked only once can be shoe-horned into the function

Classification:

Accepted as style.

Reason:

The modifiers whenNotPaused and onlyEcosystemEmitter are intentionally kept as modifiers for readability and security separation.

They make emitEvent access control easier to review.

## Mythril Result

Mythril was executed against an isolated EventsHub V2 workspace.

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

EventsHub V2 passed the reduced internal security-hardening checkpoint.

This does not mean the contract is risk-free.

The current result means:

- Foundry tests are passing
- Slither findings were fixed or triaged
- Aderyn findings were fixed or triaged
- Mythril detected no issues
- V2 started as an exact copy of the working V1 baseline
- emission authorization behavior was tested
- oversized payload behavior was tested
- DAO transition behavior was tested

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
- final Registry integration check
- final list of ecosystem emitters
- final blacklist admin process
- final DAO transition review
- final EventsHub address registration in Registry
- final HUD indexing test
- final BscScan verification plan
- independent third-party audit if budget allows

## Final Internal Checkpoint

Current checkpoint:

Foundry: 31 passed, 0 failed
Slither: completed, fixed and triaged
Aderyn: High 0, Low 1 after fixes
Mythril: no issues detected

Current recommendation:

EventsHub V2 can move from reduced active test-building into final review status.

Next recommended module: Vesting V2 or Burn Vault V2, depending on which module is closer to launch dependency.

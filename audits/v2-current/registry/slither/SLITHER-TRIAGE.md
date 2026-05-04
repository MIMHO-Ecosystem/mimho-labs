# MIMHO Registry V2 — Slither Triage

## Target

src/v2/registry.sol

## Status

Slither completed successfully.

Initial actionable findings were fixed.

Remaining findings are classified as accepted/documented items.

## Fixed During Review

### reentrancy-events

Initial finding:

setDAO emitted DAOSet after a path that could call EventsHub.

Resolution:

setDAO was updated so that:

- dao is set first
- DAOSet is emitted before Hub emission paths
- EventsHub emission remains best-effort

Classification:

Fixed.

### naming-convention

Initial finding:

setDAO(address _dao) used a parameter name not in mixedCase.

Resolution:

- _dao renamed to daoAddr

Classification:

Fixed.

## Remaining Findings

### missing-zero-check

Slither reports a missing zero-check in OpenZeppelin Ownable2Step.transferOwnership(address).

Classification:

Dependency warning / accepted.

Reason:

This finding is inside the OpenZeppelin dependency, not inside Registry custom logic.

Registry constructor validates founderSafeOwner != address(0), and the Registry uses OpenZeppelin Ownable2Step as a standard dependency.

### timestamp

Slither reports timestamp usage in partner service expiration logic.

Affected logic:

- setPartnerService()
- isPartnerAuthorized()

Classification:

Accepted by design.

Reason:

Partner service authorization intentionally depends on time-based expiration.

### pragma

Slither reports multiple pragma versions because OpenZeppelin dependencies use ^0.8.0 while Registry uses 0.8.28.

Classification:

Dependency warning / accepted.

Reason:

The project compiles with Solidity 0.8.28 for the target contract, while OpenZeppelin dependencies declare compatible ^0.8.0 pragmas.

### solc-version

Slither reports possible known issues for OpenZeppelin dependency pragmas using ^0.8.0.

Classification:

Dependency warning / accepted.

Reason:

The analyzed target is compiled with Solidity 0.8.28. The warning is tied to dependency pragma ranges, not an identified exploit in Registry custom logic.

## Current Test Evidence

Foundry Registry V2 result after Slither fixes:

46 passed
0 failed

Coverage includes:

- constructor
- metadata
- DAO setup
- DAO activation
- owner/DAO permission transition
- pause/unpause
- setMIMHOToken
- setEventsHub
- setContract
- setWallet
- legacy aliases
- checkCoreConfigured
- checkWalletsConfigured
- partner service authorization and expiration
- EventsHub best-effort behavior
- handler-based invariant tests

## Conclusion

No remaining Slither finding is currently classified as a required code fix.

The remaining findings are documented as accepted design or dependency warnings.

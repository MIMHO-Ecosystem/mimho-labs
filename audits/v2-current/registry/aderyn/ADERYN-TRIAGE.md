# MIMHO Registry V2 — Aderyn Triage

## Target

src/v2/registry.sol

## Status

Aderyn completed and generated reports.

## Initial Aderyn Summary

Initial observed result:

High: 0
Low: 3

Initial findings:

- Centralization Risk for trusted owners
- Event is missing indexed fields
- Empty Block

## Fixes Applied

### Event is missing indexed fields

Aderyn initially reported that PartnerServiceSet could index more fields.

Resolution:

validUntil was changed to indexed.

Classification:

Fixed.

### Empty Block

Aderyn initially reported an empty onExternalAction function.

Resolution:

The function now explicitly returns.

Classification:

Fixed.

## Final Aderyn Summary

Final observed result after fixes:

High: 0
Low: 1

Remaining finding:

- Centralization Risk for trusted owners

## Remaining Finding

### Centralization Risk for trusted owners

Classification:

Accepted by design with DAO transition.

Reason:

The Registry has owner-controlled setup functions before DAO activation.

This is required because the Registry is the bootstrap address book for the MIMHO ecosystem.

Mitigations:

- ownerSafe is fixed at construction
- founderSafeOwner zero address is blocked
- setDAO can only be called once
- activateDAO requires DAO to be set
- once DAO is activated, only DAO can call onlyDAOorOwner functions
- owner can no longer call onlyDAOorOwner functions after DAO activation
- Foundry tests cover owner/DAO transition behavior

Covered tests include:

- test_SetDAO
- test_ActivateDAO
- test_DAOCannotPauseBeforeActivation
- test_DAOCanPauseAfterActivation
- test_OwnerCannotPauseAfterDAOActivation

## Test Evidence

Foundry Registry V2 result after Aderyn fixes:

46 passed
0 failed

## Conclusion

No High issues were reported by Aderyn.

Two Low findings were fixed.

The remaining Low finding is accepted as a DAO-transition design item.

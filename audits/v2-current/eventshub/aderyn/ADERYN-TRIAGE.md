# MIMHO EventsHub V2 — Aderyn Triage

## Target

src/v2/eventshub.sol

## Status

Aderyn completed and generated reports.

## Initial Aderyn Summary

Initial observed result:

High: 0
Low: 3

Initial findings:

- Event is missing indexed fields
- Modifiers invoked only once can be shoe-horned into the function
- Empty Block

## Fixes Applied

### Event is missing indexed fields

Aderyn initially reported that EmitterBlacklisted could index more fields.

Resolution:

- status was changed to indexed

Classification:

Fixed.

### Empty Block

Aderyn initially reported an empty onExternalAction function.

Resolution:

- onExternalAction now uses named parameters and explicit no-op logic

Classification:

Fixed.

## Final Aderyn Summary

Final observed result after fixes:

High: 0
Low: 1

Remaining finding:

- Modifiers invoked only once can be shoe-horned into the function

## Remaining Finding

### Modifiers invoked only once can be shoe-horned into the function

Classification:

Accepted as style.

Reason:

The modifiers whenNotPaused and onlyEcosystemEmitter are intentionally kept as modifiers for readability and security separation.

They make emitEvent's access control easier to review:

- whenNotPaused enforces emergency pause behavior
- onlyEcosystemEmitter blocks EOAs, blacklisted emitters and non-ecosystem contracts

Inlining these modifiers only to satisfy a low style warning would reduce clarity and provide no security benefit.

## Test Evidence

Foundry EventsHub V2 result after Aderyn fixes:

31 passed
0 failed

## Conclusion

No High issues were reported by Aderyn.

Two Low findings were fixed.

The remaining Low finding is accepted as a style/design item.

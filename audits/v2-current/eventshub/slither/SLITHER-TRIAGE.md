# MIMHO EventsHub V2 — Slither Triage

## Target

src/v2/eventshub.sol

## Status

Slither completed successfully.

Initial actionable finding was fixed.

## Fixed During Review

### naming-convention

Initial finding:

setDAO(address _dao) used a parameter name not in mixedCase.

Resolution:

- _dao renamed to daoAddr

Classification:

Fixed.

## Remaining Findings

### assembly

Slither reports inline assembly in:

_clipCalldata(bytes,uint256)

Classification:

Accepted by design.

Reason:

EventsHub intentionally uses a small assembly block to copy only the first MAX_EVENT_DATA_BYTES bytes from calldata into memory when a payload is too large.

This is part of the gas guard design.

The function prevents oversized event payloads from causing excessive gas usage while still emitting a truncated event and PayloadTruncated telemetry.

Mitigations:

- MAX_EVENT_DATA_BYTES is hard capped at 1024
- normal payloads bypass the assembly path
- clipped payloads emit PayloadTruncated
- Foundry covers oversized payload behavior with test_PayloadIsTruncatedWhenTooLarge

## Current Test Evidence

Foundry EventsHub V2 result after Slither fix:

31 passed
0 failed

## Conclusion

No remaining Slither finding is currently classified as a required code fix.

The remaining assembly finding is documented as intentional gas-guard logic.

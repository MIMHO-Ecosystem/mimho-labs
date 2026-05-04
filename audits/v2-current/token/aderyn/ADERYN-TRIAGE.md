# MIMHO Token V2 — Aderyn Triage

## Target

src/v2/token.sol

## Status

Aderyn completed and generated a report.

Note: Aderyn printed the report successfully, then panicked with:

unexpected character 'a' while parsing major version number

The report file was still generated and reviewed.

## Final Aderyn Summary

Observed result:

High: 0
Low: 4

## Findings

### L-1: Centralization Risk for trusted owners

Classification:

Accepted by design with DAO transition.

Reason:

The token has owner-controlled launch and configuration functions before DAO activation.

Mitigation:

- setDAO requires owner
- activateDAO requires owner
- renounceIfReady requires DAO to be set and activated
- onlyDAOorOwner was corrected so DAO cannot operate before daoActivated
- Foundry includes DAO activation and pre-activation permission tests

### L-2: Unsafe ERC20 Operations should not be used

Classification:

Mitigated / accepted with validation.

Reason:

Aderyn flags the low-level ERC20 recovery helper.

The recovery path is not used for normal MIMHO transfers.

It is only for recovering non-MIMHO tokens accidentally sent to the contract.

Mitigations:

- token zero address blocked
- recipient zero address blocked
- zero amount blocked
- own MIMHO token recovery blocked
- low-level call success required
- empty return data or true return required
- Foundry recovery tests added

Covered tests:

- test_RecoverForeignERC20
- test_Revert_RecoverForeignERC20ZeroAmount
- test_Revert_RecoverOwnToken

### L-3: Event is missing indexed fields

Classification:

Accepted.

Reason:

ERC20 Transfer and Approval event signatures follow ERC20 compatibility expectations.

Additional events are acceptable as currently defined.

Changing event layouts only to satisfy a low informational warning is not required for this checkpoint.

### L-4: Large literal values multiples of 10000 can be replaced with scientific notation

Classification:

Accepted / style.

Reason:

Large numeric constants are intentionally written in full with underscores for readability and supply transparency.

This is not a security issue.

## Test Evidence

Foundry result after Aderyn recovery hardening:

45 passed
0 failed

## Conclusion

No High issues were reported by Aderyn.

Remaining Low findings are accepted, mitigated, or style/documentation items.

The Token V2 proceeds to the next security-hardening block.

# MIMHO Token V2 — Mythril Triage

## Target

src/v2/token.sol

## Tool

Mythril v0.24.8

## Status

Mythril completed analysis and reported SWC-101 integer arithmetic findings.

The findings were reviewed and tested.

## Mythril Findings Summary

Detected category:

- SWC-101: Integer Arithmetic Bugs

Observed severities:

- 1 High
- multiple Low

## High Finding

### approve(address,uint256)

Mythril reported a High SWC-101 finding in:

approve(address,uint256)

## Review

The approve function stores the allowance amount and emits an Approval event.

The reported sequence uses a very large uint256 approval value.

This is normal ERC20 behavior: approving type(uint256).max is common and should not overflow by itself.

## Validation Tests Added

The following tests were added to validate the Mythril High finding:

- test_ApproveMaxUintDoesNotOverflow
- test_ApproveMaxUintTransferFromDecrementsSafely
- test_ApproveMaxUintCanBeOverwrittenToZero

These tests validate that:

- approving type(uint256).max does not revert
- allowance is stored correctly
- transferFrom decrements the allowance safely
- max allowance can be overwritten to zero

## Low Findings

Mythril also reported SWC-101 Low findings in several public constant/getter functions, including examples such as:

- TOTAL_SUPPLY()
- MIN_SUPPLY()
- DEAD()
- ACT_FEES()
- ACT_MAX_BUY()
- ACT_AMM_PAIR()
- ACT_PAUSE()
- ACT_UNPAUSE()
- BUY_FOUNDER_BP()
- SELL_FOUNDER_BP()
- decimals()
- tradingEnabled()
- daoActivated()
- KEY_MARKETING_WALLET()

These are public constant or getter paths and are interpreted as compiler-generated / viaIR false positives.

## Classification

### approve(address,uint256)

Classification:

False positive / validated by tests.

Reason:

The approve path was tested with max uint256 allowance and safe transferFrom decrement behavior.

### Public constant/getter findings

Classification:

False positives / compiler-generated code.

Reason:

These findings target getters for constants or simple state variables and do not represent exploitable arithmetic paths in the token transfer logic.

## Test Evidence

Foundry Token V2 result after Mythril approve validation:

48 passed
0 failed

## Conclusion

No required code change was identified from the Mythril findings.

The High approve finding was specifically validated with dedicated tests.

The remaining Low findings are classified as compiler-generated false positives or non-exploitable getter/constant warnings.

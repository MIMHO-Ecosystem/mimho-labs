# MIMHO Token V2 — Slither Triage

## Target

src/v2/token.sol

## Status

Slither completed successfully.

Final actionable reentrancy and naming findings were fixed.

Remaining findings are classified as accepted/documented design items.

## Final Slither Summary

Remaining detectors:

- timestamp
- cyclomatic-complexity
- low-level-calls

## Fixed During Review

### reentrancy-no-eth

Initial finding:

transferOwnership called the EventsHub before updating owner.

Resolution:

- owner update now happens before external Hub emission
- local event is emitted after state update
- EventsHub emission is last and best-effort

Classification:

Fixed.

### reentrancy-events

Initial finding:

enableTrading emitted a local event after EventsHub call.

Resolution:

- tradingEnabled and tradingEnabledAt are updated first
- local AMMPairSet marker event is emitted before EventsHub
- EventsHub emission is last

Classification:

Fixed.

### naming-convention

Initial finding:

setDAO(address _dao) and setRegistry(address _registry) used parameter names not in mixedCase.

Resolution:

- _dao renamed to daoAddr
- _registry renamed to registryAddr

Classification:

Fixed.

### recoverNative reentrancy-events

After native recovery hardening, Slither detected local event emission after a native call.

Resolution:

- NativeRecovered event moved before the native call
- if the native call fails, the transaction reverts and the event is reverted too
- EventsHub emission remains last

Classification:

Fixed.

## Remaining Findings

### timestamp

Slither reports timestamp usage in:

- maxBuyActive()
- _transfer()

Reason:

The token intentionally uses block.timestamp to enforce the first 20-minute max-buy launch window.

This is part of the token launch design.

Using block.number would be less precise because block time can vary.

Classification:

Accepted by design.

### cyclomatic-complexity

Slither reports high cyclomatic complexity in _transfer().

Reason:

_transfer handles:

- wallet-to-wallet transfers
- AMM buy detection
- AMM sell detection
- founder fee
- LP reserve fee
- burn fee
- staking fee
- burn floor redirect
- fee exemption
- registry-resolved modules
- launch max-buy guard

The function is complex because it centralizes token transfer and fee policy.

Current decision:

Do not refactor during this checkpoint because _transfer is the most sensitive part of the token. Refactoring only to reduce the detector could introduce new bugs.

Coverage currently includes:

- unit tests
- fuzz tests
- launch edge-case tests
- invariant handler tests
- fee accounting tests

Classification:

Accepted for current version. Future refactor candidate.

### low-level-calls

Slither reports low-level call in recoverNative().

Reason:

Solidity native token recovery uses:

to.call{value: amount}("")

This is the standard compatible way to send native BNB/ETH.

Mitigations applied:

- onlyDAOorOwner access control
- zero address blocked
- zero amount blocked
- amount above balance blocked
- local NativeRecovered event
- EventsHub emission after recovery path
- dedicated Foundry tests for native recovery

Classification:

Accepted with validation.

## Current Test Evidence

Foundry Token V2 result after Slither fixes:

43 passed
0 failed

Covered areas include:

- metadata
- total supply
- wallet transfer
- approve and transferFrom
- trading lock
- enableTrading
- AMM pair setup
- buy fee
- sell fees
- fee exemption
- max-buy launch guard
- liquidity seed ordering
- DAO activation permissions
- ownership renounce guard
- native recovery validation
- invariant handler tests

## Conclusion

No remaining Slither finding is currently classified as a required code fix.

The remaining findings are documented as accepted design or validated behavior.

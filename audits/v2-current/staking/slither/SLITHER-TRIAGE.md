MIMHO Staking V2 — Slither Triage
Status
Slither was executed against:
src/v2/staking.sol
Latest Foundry result:
30 passed 0 failed
Summary
Slither completed successfully and reported multiple findings.
The findings are classified below as:
fixed
accepted by design
third-party dependency warning
pending additional adversarial testing
Fixed
unused-state
ACT_ACCRUE became unused after _emitHubEvent() was removed from _accrue() to reduce external calls inside internal accounting.
Resolution:
Removed unused ACT_ACCRUE.
Third-Party Dependency Warnings
incorrect-exp
Source:
OpenZeppelin Math.sol
Slither reports the ^ operator inside Math.mulDiv.
Classification:
third-party dependency warning
accepted
Reason:
This finding is inside OpenZeppelin Math.sol, not custom MIMHO staking logic.
divide-before-multiply
Source:
OpenZeppelin Math.mulDiv
Classification:
third-party dependency warning
accepted
Reason:
The custom staking reward formula now uses Math.mulDiv() to avoid overflow and improve precision. The remaining warning is inside OpenZeppelin implementation internals.
assembly
Source:
OpenZeppelin Math.sol
Classification:
third-party dependency warning
accepted
Reason:
OpenZeppelin Math.mulDiv() uses inline assembly internally. This is expected for full-precision arithmetic.
Accepted by Design
weak-prng
Affected functions:
_startOfWeek() _startOfYear()
Classification:
false positive / accepted by design
Reason:
These functions are not used for randomness, lottery selection or winner selection. They only round timestamps down to week/year boundaries for distribution caps.
timestamp
Classification:
accepted by design
Reason:
MIMHO Staking is time-based by design. It uses timestamps for:
minimum hold period
claim cooldown
weekly cap windows
annual cap windows
reward accrual
No randomness or winner selection depends on timestamps.
incorrect-equality
Classification:
accepted by design
Reason:
Strict equality checks such as amount == 0, lastAccrueAt == 0, and earned == 0 are state guards, not price or balance equality assumptions.
naming-convention
Classification:
accepted by protocol standard
Reason:
The Registry interface exposes uppercase key getters such as:
KEY_MIMHO_TOKEN() KEY_MIMHO_EVENTS_HUB()
This is part of the MIMHO Registry standard and intentionally differs from Solidity mixedCase naming.
cyclomatic-complexity
Affected function:
_checkLocalBoosts()
Classification:
accepted for now
may be refactored later
Reason:
The function checks multiple optional ecosystem integrations using best-effort try/catch. Complexity is higher because it supports Score, Security Wallet, Mart and Bet integrations.
events-maths
Affected functions:
setParams() setPromisedPhase()
Classification:
accepted with note
Reason:
The contract emits ConfigUpdated events through _setCfg() and also mirrors configuration changes to the MIMHO Events Hub. Slither may not fully recognize this event emission pattern because assignments and event helper calls are separated.
low-level-calls
Affected function:
rescueNative()
Classification:
accepted with note
Reason:
rescueNative() uses a low-level call to send accidentally received native currency to the authorized caller. The function is restricted by onlyDAOorOwner and reverts on failure.
pragma / solc-version
Classification:
dependency warning
Reason:
The custom Staking V2 contract uses Solidity 0.8.28. Some OpenZeppelin dependency files use ^0.8.0, which Slither reports as a version-range warning. This warning comes from dependency pragmas, not from the custom staking contract pragma.
missing-zero-check
Source:
OpenZeppelin Ownable2Step
Classification:
third-party dependency warning
accepted
Reason:
The warning is reported inside OpenZeppelin Ownable2Step, not custom MIMHO staking logic.
unindexed-event-address
Source:
OpenZeppelin Pausable
Classification:
third-party dependency warning
accepted
Reason:
The warning is reported inside OpenZeppelin Pausable, not custom MIMHO staking logic.
Pending Additional Testing
reentrancy-no-eth
Affected functions:
stake
fundRewards
Classification:
pending adversarial testing
Current mitigations:
nonReentrant
transfer failure tests
atomicity tests
state rollback tests
Next required action:
add malicious token reentrancy simulation to prove that reentrant calls into staking functions are blocked.
reentrancy-benign
Classification:
pending adversarial testing
Current mitigations:
nonReentrant
CEI-style claim flow
transfer failure rollback tests
Next required action:
add malicious token reentrancy simulation and rerun Foundry tests.


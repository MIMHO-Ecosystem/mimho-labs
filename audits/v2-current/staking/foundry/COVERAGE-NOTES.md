# MIMHO Staking V2 — Coverage Notes

## Status

Foundry coverage was attempted for the Staking V2 test suite, but the project-wide coverage compilation failed due to unrelated contracts outside the Staking V2 target.

## Attempt 1

Command:

```bash
forge coverage --match-path test/v2/stakingflow.t.sol

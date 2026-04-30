# Incident Report — MIMHO Presale V1

## Status

Deprecated.

The MIMHO Presale V1 contract is no longer recommended for production use and will not be reused in future MIMHO deployments.

## Summary

During the presale flow on 2026-04-20, the V1 presale contract encountered a critical failure in the bootstrap transfer flow.

A partial distribution occurred, but a later transfer failed after internal state had already been updated. As a result, BNB collected during the presale became locked in the contract without a safe recovery path.

## Root Cause

The V1 presale flow did not enforce sufficient atomicity between external transfers and internal state updates.

In practical terms, the contract marked the process as completed before every critical fund movement had been fully confirmed.

This created a state where the contract considered the operation finished, even though part of the fund movement failed.

## Impact

BNB collected during the V1 presale became locked in the contract.

The contract did not include a safe emergency recovery mechanism for this specific failure scenario.

## Resolution

The V1 presale and bootstrapper modules have been removed from the active MIMHO deployment plan.

MIMHO V2 contracts are being rebuilt with stronger safety requirements, including:

- pull-payment patterns where appropriate
- stronger Checks-Effects-Interactions discipline
- no state marked as complete before critical fund movements are safely completed
- explicit transfer failure simulation
- atomicity tests
- Foundry unit tests
- Foundry fuzz tests
- handler-based invariant tests
- malicious/broken token mocks
- Slither analysis
- Aderyn analysis
- Mythril analysis
- Echidna property testing
- anti-fund-lock test scenarios

## Current Status

MIMHO V2 is under active security hardening.

V1 is preserved only for transparency, historical review and public accountability.

V1 contracts should not be treated as the current recommended deployment version.

## Transparency Statement

The MIMHO project is preserving this incident report publicly to document what failed, what was learned and how V2 is being improved.

The goal of V2 is not to hide the V1 failure, but to directly address the class of issues that caused it.

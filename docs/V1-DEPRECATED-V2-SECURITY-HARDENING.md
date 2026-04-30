# MIMHO V1 Deprecated and V2 Security Hardening

## Overview

MIMHO V1 is deprecated.

MIMHO V2 is the current security-hardening version of the smart contract ecosystem.

## Why V1 Was Deprecated

The V1 presale contract suffered a critical fund-lock incident during the 2026-04-20 presale flow.

The incident showed that V1 did not sufficiently protect against a specific class of failure:

- internal state marked as completed
- later fund movement failed
- funds remained locked
- no safe recovery path existed

## V2 Direction

V2 is being rebuilt with explicit testing against this class of failure.

The V2 review process now includes:

- unit tests
- fuzz tests
- handler-based invariant tests
- broken token simulations
- transfer failure simulations
- transferFrom failure simulations
- anti-fund-lock scenarios
- static analysis
- symbolic analysis
- property-based testing

## Transparency Policy

V1 materials are preserved publicly for historical transparency.

V2 materials are maintained separately to avoid confusing deprecated contracts with current active development.

# MIMHO V1 — Deprecated Audit Artifacts

## Status

Deprecated.

This folder contains historical audit artifacts, notes and security materials related to MIMHO V1 contracts.

## Important Notice

MIMHO V1 contracts are not recommended for production use.

The V1 presale contract suffered a critical fund-lock incident during the 2026-04-20 presale flow.

The incident is documented here:

- [Incident Report — Presale V1](./INCIDENT-2026-04-20-PRESALE.md)

## Why This Folder Exists

This folder is preserved for transparency.

The MIMHO project does not intend to hide or overwrite V1 history. Instead, V1 is being clearly marked as deprecated while V2 is being rebuilt with stronger testing and safety requirements.

## V1 Lessons Learned

The V1 incident highlighted the need for:

- stronger atomicity guarantees
- safer transfer handling
- explicit failure simulation
- no premature state finalization
- anti-fund-lock tests
- handler-based invariant testing
- broader adversarial testing before deployment

## Current Direction

MIMHO V2 is the current active development and security-hardening version.

V2 security materials are maintained under:

- `audits/v2-current/`

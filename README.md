# MIMHO Labs

MIMHO Labs contains smart contracts, internal security reviews, automated analysis artifacts, testing reports and tooling for the MIMHO ecosystem.

## Current Contract Status

| Version | Status | Notes |
|---|---|---|
| V1 | Deprecated | Presale V1 suffered a critical fund-lock incident and is preserved for transparency. |
| V2 | Active Security Hardening | Current version under Foundry, Slither, Aderyn, Mythril and Echidna testing. |

## Important Notice

MIMHO V1 contracts are not recommended for production use.

The V1 presale contract suffered a critical fund-lock incident during the 2026-04-20 presale flow. The incident is documented under:

```text
audits/v1-deprecated/INCIDENT-2026-04-20-PRESALE.md
```

MIMHO V2 is the current active development version and is being rebuilt with stronger security requirements, explicit transfer failure simulation, invariant testing and anti-fund-lock checks.

## Security Review Language

The materials in this repository are internal security review artifacts and automated analysis outputs.

Unless explicitly stated otherwise, they should not be described as third-party audits or certifications.

Recommended language:

- internal security review
- automated analysis
- security hardening
- test report
- audit artifacts

---

# 🧪 MIMHO Labs — Core Tests & Tooling

This repository contains the **technical testing, auditing, and tooling environment**
for the **MIMHO Ecosystem**, built using **Foundry**.

It is used internally to validate security, behavior, and integration of contracts
**before and after deployment**.

---

## 🎯 Purpose

- Execute unit and integration tests for MIMHO contracts
- Simulate edge cases, attack vectors, and failure scenarios
- Support internal audits and security reviews
- Validate protocol assumptions before mainnet deployment

---

## 🛠️ Tech Stack

- **Solidity**
- **Foundry (forge / cast)**
- Custom test utilities and helpers

---

## 📁 Repository Structure

- `src/` — Contracts under test
- `test/` — Test suites and scenarios
- `audits/` — Internal and experimental audit reports
- `lib/` — External libraries
- `.github/workflows/` — CI pipelines

---

## 🔐 Security Note

This repository may contain:
- Experimental code
- In-progress tests
- Non-final contract versions

It **must not** be used as a deployment reference.

---

## 🔗 Official References

- **Core Specs & Documentation:**  
  https://github.com/MIMHO-Ecosystem/mimho-core

- **Website:**  
  https://mimho.io

---

## ⚠️ Disclaimer

This repository is **technical infrastructure only**.

Nothing here constitutes:
- Financial advice
- A promise of functionality
- A final implementation

---

*MIMHO — The Memecoin of the Future*  
*Tested, not trusted.*

Security Policy

Overview

The MIMHO protocol follows a security-first development philosophy.
All smart contracts are designed with strict modularity, minimal privilege,
and DAO-governed upgrade paths.

Security is enforced through:

- modular architecture via "MIMHORegistry"
- DAO takeover mechanisms ("Ownable2Step")
- emergency pause mechanisms
- reentrancy protection
- event transparency via "MIMHOEventsHub"

Responsible Disclosure

If you discover a vulnerability, please report it privately before public disclosure.

Contact:
security@mimho.com.br

Please include:

- contract affected
- description of the issue
- reproduction steps
- potential impact

Security Principles

The protocol follows these core rules:

1. No contract holds unnecessary funds
2. All cross-contract calls resolve via Registry
3. DAO takeover must be explicit
4. Emergency pause available for critical modules
5. Events emitted for all governance actions

Audit Status

The repository includes automated security checks:

- Forge unit tests
- Fuzz testing
- Slither static analysis
- Surya architecture inspection

External audits may be conducted before mainnet deployment.

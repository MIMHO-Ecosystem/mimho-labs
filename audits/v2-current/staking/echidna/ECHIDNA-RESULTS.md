MIMHO Staking V2 — Echidna Results
Status
Passed.
Echidna was executed against an isolated Staking V2 workspace.
Tool
Echidna 2.3.2
Target
src/v2/staking.sol
Harness
audits/v2-current/staking/echidna/EchidnaStaking.t.sol
Config
audits/v2-current/staking/echidna/echidna.yaml
Campaign Result
Campaign complete. Test limit reached. All properties passing.
Properties Tested
The following Echidna properties passed:
echidna_total_staked_never_exceeds_initial_actor_supply_plus_rewards
echidna_balance_covers_total_staked_plus_reward_reserve
echidna_actor_stakes_match_total_staked
echidna_total_staked_is_backed_by_token_balance
echidna_reward_reserve_never_exceeds_contract_balance
Observed Campaign Data
Echidna version: 2.3.2
Test limit: 5000
Total calls observed: 5117 / 5000
Unique instructions: 3411
Unique codehashes: 5
Corpus size: 3 sequences
Fetched contracts: 0
Fetched slots: 0
Status: passing
Interpretation
The Echidna property campaign did not find an invariant violation in the tested Staking V2 harness.
The tested invariants focused on:
total staked accounting
reward reserve backing
contract token balance backing
actor stake accounting
maximum possible stake bounds
Notes
This Echidna result does not replace a manual audit.
It is one layer of the MIMHO V2 security-hardening process, alongside Foundry unit tests, fuzz tests, invariant handler tests, malicious token tests, broken token tests, Slither and Aderyn.

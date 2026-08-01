# Project State

Last updated: 2026-08-01

This file is the continuity single source of truth for Minerlot. Any Claude
Code session — on this machine or a fresh clone elsewhere — should read this
file first. Update it whenever state changes, not only at the end of a work
session.

## What exists right now

- Documentation and repo scaffolding only: `CLAUDE.md`, this file, `README.md`,
  `.gitignore`.
- No Bitcoin node installed or configured.
- No pool software (public-pool) installed or configured.
- No Bitaxe device connected.
- No `.claude/` project skills or subagents (see "Why no `.claude/` yet"
  below).

## Key decisions and why

| Decision | Rationale |
|---|---|
| Pool software: public-pool | Purpose-built for solo home-ASIC mining (Bitaxe), has a per-device dashboard, talks to local Bitcoin Core via RPC+ZMQ, runs on modest hardware. Chosen over ckpool-solo. |
| Bitcoin Core in pruned mode (`prune=10000`, ~10GB) | Pruning discards old raw blocks after full validation; full validation and complete UTXO set are unaffected. Block-template building (`getblocktemplate`) and chain validation work identically. The node just can't serve historical blocks to peers, which doesn't matter for a personal mining backend. Makes this feasible on an 8GB RAM / 250GB SSD dev machine. |
| Non-custodial design | Payouts go to a public receiving address only. Private keys/seed phrases never touch this system. |
| No fees, solo only | No proportional/shared payout logic. A multi-user pool is a possible future project, not planned work. |
| Branching: git-flow-lite, `main` + `develop` | `main` = stable snapshots (GitHub default branch). `develop` = day-to-day integration branch, checked out locally by default. |
| Commit style: Conventional Commits, no AI attribution | Repo-wide convention; hard rule against "Co-Authored-By" or similar trailers. |
| Repo language: English | All files, code, comments, and commit messages in English regardless of conversation language. |
| GitHub default branch stays `main` even though `develop` is used day-to-day | Follows common convention (GitHub default = `main`) while git-flow-lite still treats `develop` as the integration branch. Documented here as a deliberate, smallest-reasonable choice. |

## Open questions / pending on the human

- **Payout address**: provided by Carlos on 2026-08-01, verified locally
  (bech32 checksum valid, mainnet, P2WPKH — standard single-sig segwit
  address). Deliberately NOT stored anywhere in this repo, since the repo
  is public — publishing a real payout address publicly would link it to
  Carlos's identity for no benefit. It will be wired directly into
  public-pool's local, gitignored config once that service is installed on
  the production machine. Whoever picks this up next: ask Carlos to
  re-supply it at that point if it isn't already sitting in a local
  untracked file.
- **Production machine**: decided — **Ubuntu Server 26.04 LTS** ("Resolute
  Raccoon"), headless, everything run via Docker Compose. Carlos is setting
  up the physical hardware now (in progress as of 2026-08-01). Access model:
  SSH over the home LAN only (no port forwarding / no internet-facing
  exposure) — the dev machine (this one) reaches the production box directly
  by its local IP. A dedicated ed25519 keypair was generated on the dev
  machine (`~/.ssh/minerlot_prod`) for this purpose; first contact will be
  password auth during OS install, then the pool's public key gets installed
  and password auth gets disabled.
- **Dev machine longevity**: once the production machine is reachable over
  SSH, all further Bitcoin Core / public-pool work happens there directly,
  not on this Windows dev machine. This Windows PC remains just for
  documentation/repo work and as the SSH client used to reach production.

## Next steps

1. Carlos finishes installing Ubuntu Server 26.04 LTS on the production
   machine and reports back its local IP address (in progress).
2. Connect over SSH from the dev machine, harden access (install the
   prepared public key, disable password auth), and do first system updates.
3. Install and configure Bitcoin Core in pruned mode on the production
   machine.
4. Install and configure public-pool, pointing it at the local node via
   RPC + ZMQ, wired to Carlos's payout address (kept out of git).
5. Connect one Bitaxe device and run a first end-to-end test on
   regtest/testnet before touching mainnet.

## Why no `.claude/` yet

No `.claude/` folder with project skills/subagents has been created. There
are no concrete repetitive workflows yet to justify one. Once recurring
tasks emerge — e.g. "check node sync status", "restart pool service" — they
should be turned into project skills at that point, not before.

## Where things live

- `CLAUDE.md` — project instructions auto-loaded by Claude Code each session.
- `docs/PROJECT_STATE.md` — this file.
- `README.md` — short public-facing project summary.
- `.gitignore` — ignores for Node.js, Bitcoin Core data, OS/editor cruft.

This section will grow as the Bitcoin node config, public-pool config, and
any scripts are added.

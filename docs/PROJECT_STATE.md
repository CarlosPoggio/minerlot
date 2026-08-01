# Project State

Last updated: 2026-08-01

This file is the continuity single source of truth for Minerlot. Any Claude
Code session — on this machine or a fresh clone elsewhere — should read this
file first. Update it whenever state changes, not only at the end of a work
session.

## What exists right now

- Documentation and repo scaffolding: `CLAUDE.md`, this file, `README.md`,
  `.gitignore`.
- **Production server is live and reachable**: `minerlot-node`, Ubuntu Server
  26.04 LTS, static LAN IP `192.168.1.2`, reachable over SSH (key-only) from
  the dev machine. Hardware: Intel i5-9400T, 6 cores, 14 GB RAM, 233 GB disk
  (214 GB free) — comfortably more than the original dev-machine baseline.
  Docker 29.1.3 + Compose 2.40.3 installed. UFW firewall active (deny
  incoming by default, SSH allowed, nothing else open yet). System packages
  up to date as of 2026-08-01, no reboot pending.
- No Bitcoin node installed or configured yet.
- No pool software (public-pool) installed or configured yet.
- No Bitaxe device connected yet.
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
  Raccoon"), headless, everything run via Docker Compose. Access model: SSH
  over the home LAN only (no port forwarding / no internet-facing exposure)
  — the dev machine (this one) reaches the production box directly by its
  local IP. A dedicated ed25519 keypair was generated on the dev machine
  (`~/.ssh/minerlot_prod`) and is already baked into the install as an
  authorized key (password SSH login is disabled from first boot; a local
  console password still exists as an emergency fallback — see
  `local.access.md`, gitignored, on the dev machine).
- **Unattended install USB built (2026-08-01)**: rather than a manual
  installer walkthrough, an autoinstall (cloud-init) USB was built directly
  on the dev machine — official Ubuntu Server ISO copied onto the USB,
  `user-data`/`meta-data` added at its root, and `boot/grub/grub.cfg`'s
  default entry patched with `autoinstall ds=nocloud\;s=/cdrom/` plus
  `timeout=1`, so it installs with zero keypresses once booted (only a
  one-time BIOS Secure Boot disable is needed, since the modified boot
  files aren't Canonical-signed). First network boot uses DHCP; the plan is
  to move to a static `192.168.1.2` afterward once SSH access is confirmed
  (not baked into the image). Docker + docker-compose-v2 install
  automatically via the autoinstall config's `late-commands`. Full
  credentials/build details are in `local.access.md` (gitignored, dev
  machine only — this repo is public).
- **Dev machine longevity**: once the production machine is reachable over
  SSH, all further Bitcoin Core / public-pool work happens there directly,
  not on this Windows dev machine. This Windows PC remains just for
  documentation/repo work and as the SSH client used to reach production.

## Next steps

1. Install and configure Bitcoin Core in pruned mode on the production
   machine, via Docker Compose.
2. Install and configure public-pool, pointing it at the local node via
   RPC + ZMQ, wired to Carlos's payout address (kept out of git).
3. Connect one Bitaxe device and run a first end-to-end test on
   regtest/testnet before touching mainnet.

## Done — production server bring-up (2026-08-01)

1. ~~Carlos boots the prepared autoinstall USB~~ — done, zero manual
   install steps, first try.
2. ~~Connect over SSH, harden access, first system updates~~ — done:
   key-only SSH confirmed (`sshd -T` shows `passwordauthentication no`),
   moved from DHCP to static `192.168.1.2` via netplan, UFW enabled
   (SSH-only for now), `apt upgrade` applied cleanly, no reboot required.

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

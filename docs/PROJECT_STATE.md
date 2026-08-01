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
- **Bitcoin Core and public-pool are deployed and running** on the
  production server, in `/opt/minerlot` (Docker Compose, two containers:
  `minerlot-bitcoind`, `minerlot-public-pool`). See "Bitcoin node + pool
  deployment" below for full details. Bitcoin Core is still doing its
  initial block download (started 2026-08-01) — the pool cannot produce
  valid work until that finishes.
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

1. Wait for Bitcoin Core's initial block download to finish (started
   2026-08-01; pruned mode does not make this faster — every block is
   still fully validated from genesis, only old ones get deleted
   afterward). Realistically hours, not minutes. Check progress with
   `docker exec minerlot-bitcoind bitcoin-cli -datadir=/home/bitcoin/.bitcoin -rpcuser=minerlot -rpcpassword=<see local.access.md> getblockchaininfo`.
2. Once synced, connect a real Bitaxe (guide: `docs/CONECTAR_MINERO.md`)
   and confirm shares are being accepted and the pool's `/api/info`
   endpoint reflects live hashrate.
3. Optional follow-up, not done yet: deploy `public-pool-ui` (a separate
   Angular/Caddy project) for a proper visual dashboard instead of raw
   JSON at `:3334/api/info`. Skipped for now because its backend-API
   wiring isn't clearly documented upstream and didn't seem worth the
   added moving part before a real miner is even connected — the raw API
   is enough to confirm the pool is alive. Revisit if a nicer dashboard
   becomes worth the extra container.

## Bitcoin node + pool deployment (2026-08-01)

Deployed directly to the production server at `/opt/minerlot` (not this
repo — these are runtime configs with secrets, kept off git; mirrored in
`local.access.md` on the dev machine):

- **`bitcoin/Dockerfile`**: custom image, not a third-party prebuilt one.
  Downloads the *official* Bitcoin Core 31.1 Linux binary directly from
  bitcoincore.org during build and verifies its SHA256 before using it —
  chosen over community Docker images (e.g. `lncm/bitcoind`) to avoid an
  extra layer of trust beyond Bitcoin Core's own release process, in
  keeping with the project's "don't depend on third parties" principle.
  Runs as a non-root user, wallet disabled (`disablewallet=1` — never
  needed, since payouts go to whatever address each Bitaxe supplies at
  the stratum level, not to a pool-managed wallet).
- **`bitcoin/bitcoin.conf`**: `prune=10000` (~10GB), `dbcache=4000` (speeds
  up validation given 14GB RAM), ZMQ block notifications enabled, RPC
  reachable only inside the compose-internal Docker network
  (`172.30.0.0/24`), never published to the LAN or host.
- **`public-pool`**: official upstream repo
  (github.com/benjamin-wilson/public-pool) git-cloned directly onto the
  server and built from source via its own Dockerfile — not a prebuilt
  image either. `NETWORK=mainnet`, `DEV_FEE_ADDRESS` left blank (no fees,
  per this project's core requirement). Talks to `bitcoind` over the
  internal Docker network by container name, never touches the LAN for
  that.
  - **Solo-mining payout model**: public-pool does not take a pool-wide
    payout address in its config at all. Each miner supplies its OWN
    payout address as the stratum username (optionally
    `address.workername`, confirmed by reading
    `AuthorizationMessage.ts` in the upstream source — it splits on `.`,
    validates the first part as a Bitcoin address). This is the correct,
    non-custodial behavior: whichever device's address is set on it gets
    credited if it finds a block. See `docs/CONECTAR_MINERO.md`.
  - Ports: `3333` (stratum, for Bitaxes) and `3334` (JSON status API) are
    published to the LAN. `8332` (bitcoind RPC) is never published.
- **Firewall**: UFW alone does **not** cover Docker-published ports —
  Docker manipulates iptables directly and bypasses UFW's normal rules
  for anything published via `docker-compose.yml`'s `ports:`. Fixed by
  adding an explicit `DOCKER-USER` iptables chain (via
  `/etc/ufw/after.rules`, reloaded with `ufw reload`) that only allows
  192.168.1.0/24 (the home LAN) to reach ports 3333/3334, dropping
  everything else. Verified with `iptables -L DOCKER-USER -n -v`.
- **Decision: mainnet directly, not testnet/regtest first.** The
  original plan (see git history) was to test on testnet/regtest before
  touching mainnet. In practice, running a second full node just to
  validate stratum plumbing added more moving parts than it saved, and
  the deployment itself (Docker build, RPC/ZMQ wiring, firewall) is
  identical regardless of network — testing it on mainnet costs nothing
  extra since finding a real block is astronomically unlikely during
  a quick smoke test anyway. If this ever needs revisiting, `NETWORK=`
  and `bitcoin.conf` both support a `testnet=1`/`NETWORK=testnet` swap
  with no other changes.

## Why no `.claude/` yet

No `.claude/` folder with project skills/subagents has been created. There
are no concrete repetitive workflows yet to justify one. Once recurring
tasks emerge — e.g. "check node sync status", "restart pool service" — they
should be turned into project skills at that point, not before.

## Where things live

- `CLAUDE.md` — project instructions auto-loaded by Claude Code each session.
- `docs/PROJECT_STATE.md` — this file.
- `docs/CONECTAR_MINERO.md` — Bitaxe/miner connection instructions, in
  Spanish (the one doc deliberately not in English — it's a direct runbook
  for Carlos, not an AI-continuity artifact).
- `README.md` — short public-facing project summary.
- `.gitignore` — ignores for Node.js, Bitcoin Core data, OS/editor cruft.
- `local.access.md` (dev machine only, gitignored, not in this repo listing
  on GitHub) — every credential, IP, and build detail for the production
  server.
- On the production server itself (`192.168.1.2`, not in this repo):
  `/opt/minerlot/docker-compose.yml`, `/opt/minerlot/bitcoin/` (Dockerfile
  + bitcoin.conf), `/opt/minerlot/public-pool/` (git-cloned upstream repo
  + local `.env`).

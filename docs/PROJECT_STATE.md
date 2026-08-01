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
- **Bitcoin Core, public-pool, and a monitoring dashboard are deployed and
  running** on the production server, in `/opt/minerlot` (Docker Compose,
  three containers: `minerlot-bitcoind`, `minerlot-public-pool`,
  `minerlot-monitor`). See "Bitcoin node + pool deployment" and
  "Monitoring dashboard" below for full details. Bitcoin Core is still
  doing its initial block download (started 2026-08-01) — the pool cannot
  produce valid work until that finishes.
- **Server confirmed safe to run fully headless**: no monitor, keyboard,
  or USB stick attached — it boots and runs entirely from its internal
  NVMe disk (verified via `findmnt` / `lsblk`, the OS is on `nvme0n1p2`,
  the install USB shows up as an untouched separate `sda` device). Power
  + Ethernet only is enough going forward.
- **Pending on Carlos (needs physical access, cannot be done remotely)**:
  enable "power on after AC power loss" in the BIOS, so the server
  restarts itself automatically after a power cut. This lives in
  firmware/NVRAM below the OS, so it can't be set over SSH. See "Next
  steps" for exact guidance.
- No Bitaxe device connected yet.
- No `.claude/` project skills or subagents (see "Why no `.claude/` yet"
  below).

## Key decisions and why

| Decision | Rationale |
|---|---|
| Pool software: public-pool | Purpose-built for solo home-ASIC mining (Bitaxe), has a per-device dashboard, talks to local Bitcoin Core via RPC+ZMQ, runs on modest hardware. Chosen over ckpool-solo. |
| Bitcoin Core in pruned mode (`prune=10000`, ~10GB) | Pruning discards old raw blocks after full validation; full validation and complete UTXO set are unaffected. Block-template building (`getblocktemplate`) and chain validation work identically. The node just can't serve historical blocks to peers, which doesn't matter for a personal mining backend. Makes this feasible on an 8GB RAM / 250GB SSD dev machine. |
| Non-custodial design | Payouts go to a public receiving address only. Private keys/seed phrases never touch this system. |
| No fees, solo only, for now | Current deployment has no fees, LAN only. Carlos has decided the eventual direction (2026-08-01): a public, internet-facing solo pool with a 2% fee — still not proportional/shared payout, just a fee on top of solo mining. Planned but explicitly not started; see `docs/ROADMAP_PUBLIC_POOL.md`. |
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

1. **Carlos**: go into BIOS setup (Lenovo ThinkCentre — press F1 at the
   Lenovo boot logo, unless the boot screen says otherwise) and find
   **Power → After Power Loss** (exact wording may vary slightly by BIOS
   version), set it to **Power On**. This cannot be done remotely — it's
   firmware-level, below the OS. Nothing else on the checklist depends on
   this; it's just resilience against power cuts.
2. Wait for Bitcoin Core's initial block download to finish (started
   2026-08-01; pruned mode does not make this faster — every block is
   still fully validated from genesis, only old ones get deleted
   afterward). Realistically hours, not minutes. Check progress with
   `docker exec minerlot-bitcoind bitcoin-cli -datadir=/home/bitcoin/.bitcoin -rpcuser=minerlot -rpcpassword=<see local.access.md> getblockchaininfo`.
3. Once synced, confirm the already-connected Bitaxe ("naranja", see bug
   note below) starts submitting accepted shares and shows up in the
   "Minando activamente" table on the monitoring dashboard
   (`http://192.168.1.2/`) with live hashrate.
4. **Carlos**: please open `http://192.168.1.2/` yourself and confirm the
   subtitle shows "dirección: bc1q..." and the "Minando ahora"/"En espera"
   tiles show actual numbers (not blank). While verifying this session's
   changes, the browser-automation tool used to test the dashboard
   appeared to redact/blank content that looks like a Bitcoin address (and
   possibly nearby numbers) in its own screenshots and DOM reads — almost
   certainly a deliberate safety feature of that tool (preventing the AI
   from reading sensitive-looking financial identifiers off a page it's
   driving), not something affecting what a real browser/human sees. But
   it made it impossible to fully self-verify from this session, so a
   human check is needed before trusting it's cosmetically correct.
5. Optional follow-up, not done yet: deploy `public-pool-ui` (a separate
   Angular/Caddy project) for a fancier dashboard than the custom one
   already built. Low priority now that `minerlot-monitor` covers the
   actual requirements.

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

## Monitoring dashboard (2026-08-01)

A single-screen, no-auth status page at `http://192.168.1.2/` (port 80,
`minerlot-monitor` container, plain `nginx:1.27-alpine` serving one static
file — no build step). Polls public-pool's own API every 5s client-side
(`/api/pool`, `/api/client/<address>`, `/api/info`); no separate backend
needed since public-pool already enables permissive CORS
(`app.enableCors()` in its `main.ts`).

Shows: total live hashrate, session-max hashrate (persisted in the
viewing browser's `localStorage`, not server-side — resets only if that
browser's site data is cleared), online/total miner count, blocks found,
current block height, pool uptime, and a per-worker table (status dot
from `lastSeen` recency, hashrate, IP, uptime, best difficulty, accepted
shares, blocks found by that worker, payout address).

**Deliberate small patch to upstream public-pool** to support this (files
touched, all pure-additive/nullable, on the server's own clone at
`/opt/minerlot/public-pool`, not upstreamed):
- `client.entity.ts`: added `ip` (nullable varchar) and `sharesCount`
  (int, default 0) columns. Safe because `synchronize: true` in
  `app.module.ts` auto-migrates the SQLite schema on startup.
- `StratumV1Client.ts`: captures `socket.remoteAddress` into `ip` when a
  worker's DB row is first created; increments `sharesCount` by 1 per
  accepted share (mirrors the existing `bestDifficulty` update pattern).
- `client.service.ts`: added `incrementShares()`.
- `client.controller.ts`: exposes `ip` and `sharesCount` in
  `GET /api/client/:address`'s worker list.
- Why patch instead of working around it: upstream doesn't track or
  expose per-worker IP or a running share count anywhere (confirmed by
  reading the actual source, not assumed) — there was no way to get this
  data without either patching or reverse-engineering it from raw TCP
  connections, which would've been far more fragile.
- Risk this creates: a future `git pull` on the server's public-pool
  clone would need this patch re-applied (it will conflict or silently
  disappear on update, since it's not upstream). Whoever updates
  public-pool later should check `git diff` there first, or be aware the
  dashboard's IP/shares columns will silently stop populating for new
  rows if the patch is lost.

## Bug found and fixed: public-pool crashed on every getblocktemplate error (2026-08-01)

First real Bitaxe connection attempt (worker name "naranja", from
192.168.1.15) exposed a crash bug in upstream public-pool: while
`bitcoind` is in initial block download, `getblocktemplate` correctly
returns an error (Bitcoin Core refuses to serve templates until synced —
expected, not a bug on our side). But in
`stratum-v1-jobs.service.ts`, that rejected promise from
`bitcoinRpcService.getBlockTemplate()` inside the `newMiningJob$`
RxJS pipeline (built from `combineLatest([newBlock$, refreshInterval$]).pipe(switchMap(...))`)
had no `catchError`, so it became an unhandled rejection that crashed the
entire Node process. Docker's `restart: unless-stopped` masked this as a
silent crash-loop — the container kept "running" (from `docker ps`'s
perspective, restarting every time) but never stayed up long enough to
serve a miner.

**Fix** (patched locally on the server's clone, same caveat as the
IP/shares patch above re: `git pull`): added `catchError` around the
`getBlockTemplate` call in `stratum-v1-jobs.service.ts`, logging the
error and returning RxJS `EMPTY` instead of propagating it — the next
`newBlock$` emission or 60s interval tick just retries. Verified fixed:
container now stays up (`RestartCount: 0`) through repeated
getblocktemplate failures while syncing, logging
`Skipping job update, getBlockTemplate failed: ...` instead of crashing.

**Important**: this fix makes the pool *stable* while waiting for sync,
not *functional* yet — `getblocktemplate` will keep failing (harmlessly
now) until `bitcoind`'s `initialblockdownload` flag goes false, so the
Bitaxe won't actually get real work or submit accepted shares until then.
Nothing further needs to change on the Bitaxe's config — it already
connected correctly (`bc1qv820jhzkrluuhppldtnfr43w3zrdpdnayy537p.naranja`
via `192.168.1.2:3333`) and should just start working once sync finishes.

## "Waiting miners" tracking + dashboard toggle (2026-08-01)

Requested: a way to see miners that connected successfully but can't
mine yet (blocked by the getblocktemplate/IBD situation above), separate
from ones actively producing shares.

- **public-pool patch**: `ensureClientEntity()` (previously only called
  from `handleMiningSubmission`, i.e. after a worker's first accepted
  share) is now also called from `initStratum()`, right after a worker
  is authorized and subscribed — so it gets a DB row immediately instead
  of only once it manages to mine something. A new 30s heartbeat
  interval (separate from the existing 60s `checkDifficulty` one) keeps
  `lastSeen` fresh independent of shares, so a genuinely-connected-but-
  waiting worker doesn't look "offline" after 5 minutes
  (`ClientService.killDeadClients`'s cutoff).
- **Dashboard**: workers are split client-side into "Minando activamente"
  (`sharesCount > 0`) shown in the main table, and "Conectados, en
  espera" (`sharesCount === 0`) behind a toggle button showing the count.
  No backend distinction needed beyond the sharesCount field already
  added earlier today.
- Verified working: the Bitaxe ("naranja") shows up correctly under
  "en espera" with a green "Conectado" status.

## Server deployment moved into git (2026-08-01)

Previously, `/opt/minerlot` was a set of hand-copied files with `git
clone`d subdirectories but no real tracked history of our own. Now the
server's `/opt/minerlot` **is** a clone of this repo (`develop` branch),
and `infra/` is the deployable unit. Full mechanics, secret handling, and
update workflow: `docs/DEPLOY.md`. Summary of what changed:

- `infra/public-pool` is now a proper git submodule pointing at
  `github.com/CarlosPoggio/public-pool` (a fork with our patch as real
  commits, `upstream` remote configured for pulling future upstream
  changes) — replacing what used to be an ad-hoc, never-committed clone
  directly on the server.
- Secrets (`RPC_PASSWORD`, `WALLET_ADDRESS`) live only in a gitignored
  `infra/.env` on the server, never in git. `bitcoin.conf`,
  `public-pool/.env`, and `monitor/index.html` are rendered from
  `.template` files (also gitignored once rendered) by `infra/deploy.sh`
  via `envsubst`.
- The old ad-hoc directory was preserved (not deleted) at
  `/opt/minerlot-old-adhoc` on the server as a safety net during the
  migration — safe to remove once the new setup has proven stable for a
  while.
- The `bitcoin-data` named Docker volume (`minerlot_bitcoin-data`) is
  pinned explicitly in `docker-compose.yml` (`name:` field, plus a
  top-level `name: minerlot` for the whole project) specifically so this
  kind of restructuring can never accidentally orphan it into a
  differently-named volume and appear to "lose" sync progress. Confirmed
  safe: sync progress carried through this migration without interruption.
- **Bug found during this migration and fixed**: restarting `bitcoind`
  and `public-pool` at nearly the same instant (normal on
  `docker compose up`) let public-pool's ZMQ subscriber connect before
  bitcoind's ZMQ publisher was ready. ZMQ pub/sub doesn't replay missed
  messages, and there was no fallback poll while ZMQ mode is active, so
  `newBlock$` never got its first value and `/api/pool` hung forever
  until a manual container restart. Fixed two ways (belt and suspenders):
  a 30s periodic `pollMiningInfo()` safety net alongside ZMQ (patch, in
  the public-pool fork), and a `bitcoind` healthcheck +
  `depends_on: condition: service_healthy` on `public-pool` in
  `docker-compose.yml` (so the race is much less likely to happen at
  all). Verified fixed: redeployed from scratch, `public-pool` waited for
  `bitcoind (healthy)`, and `/api/pool` worked immediately, no manual
  restart needed.

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
- `docs/DEPLOY.md` — how the `infra/` deployment works and how to ship
  updates to the production server.
- `README.md` — short public-facing project summary.
- `.gitignore` — ignores for Node.js, Bitcoin Core data, OS/editor cruft.
- `local.access.md` (dev machine only, gitignored, not in this repo listing
  on GitHub) — every credential, IP, and build detail for the production
  server.
- `infra/` — the actual deployable unit, mirrored 1:1 on the server at
  `/opt/minerlot/infra` (the server's `/opt/minerlot` is a git clone of
  this whole repo, not a separate copy). See `docs/DEPLOY.md` for the
  full layout and workflow. Briefly: `docker-compose.yml`,
  `bitcoin/Dockerfile` + `.template`, `public-pool/` (git submodule, our
  fork), `public-pool.env.template`, `monitor/index.html.template`,
  `deploy.sh`, `env.example`. Real secrets only ever exist in a
  gitignored `infra/.env` on the server.

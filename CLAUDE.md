# Minerlot — Project Instructions for Claude Code

## Read this first

Before doing any work in this repo, read `docs/PROJECT_STATE.md`. It is the
single source of truth for current status, decisions, and next steps. Update
it as state changes, not only when a task finishes.

## What this project is

Minerlot is a personal, non-custodial, solo-mining Bitcoin pool that
coordinates the owner's own Bitaxe ASIC devices. There are no external users,
no fees, and no proportional/shared payout logic. It runs its own Bitcoin
node so it can build block templates trustlessly instead of depending on a
third party.

## Hard constraints

- Solo mining only, for the owner's own hardware. Not a public pool.
- No fees, no shared/proportional payouts.
- Non-custodial: the system only ever holds a public receiving address for
  payouts. Private keys and seed phrases never touch this system.
- Must run its own Bitcoin Core node — no reliance on third-party nodes or
  block-template providers.

## Architecture decisions

- **Pool software: [public-pool](https://github.com/benjamin-wilson/public-pool)**
  (MIT, Node.js/NestJS). Chosen over ckpool-solo because it is purpose-built
  for solo-mining home ASICs like Bitaxe, ships a web dashboard per-device
  (hashrate, best difficulty), and talks to a local Bitcoin Core node via
  RPC + ZMQ to build its own block templates. Runs fine on modest hardware.
- **Bitcoin node: Bitcoin Core, pruned mode** (e.g. `prune=10000` for ~10GB).
  Pruning only discards old raw block files after validation — the node
  still fully validates every block and keeps the complete UTXO set. This
  has no effect on building block templates (`getblocktemplate`) or on
  validating the chain; it only means the node cannot serve historical
  blocks to other peers, which is irrelevant here. It was originally chosen
  so the node would fit on modest hardware (i5, 8GB RAM, 250GB SSD), and it
  remains the approach on the production server (`minerlot-node`).
- **Branch model (git-flow-lite):** `main` = stable/production-ready
  snapshots, GitHub default branch. `develop` = day-to-day integration
  branch, checked out locally by default. Feature work branches from and
  merges back into `develop`; `develop` merges into `main` for releases.
- **Commits:** Conventional Commits (`feat:`, `docs:`, `fix:`, `chore:`,
  etc.). Never add "Co-Authored-By" or any AI-attribution trailer.

## Non-goals

- A proportional/shared pool for external users is explicitly out of scope.
  It is a possible future project, not something to design or build now.

## Environment: where things run

- **Production** is `minerlot-node` (Ubuntu Server, LAN IP `192.168.1.2`).
  The stack runs with Docker Compose from `/opt/minerlot`, a git clone of
  this repo (`develop` branch). Containers: `minerlot-bitcoind`,
  `minerlot-public-pool`, `minerlot-monitor`. Dashboard:
  `http://192.168.1.2/`. Deploy workflow: `docs/DEPLOY.md`.
- **Development/admin workstation** is the `srclaude` server, with this
  repo at `~/proyectos/minerlot` (moved there from the original Windows PC
  on 2026-11-23). Reach production with the SSH alias `minerlot-node`
  (user `minerlot`, key-only); for one-off commands use
  `ssh -o BatchMode=yes minerlot-node '<command>'`.
- **Production is read-only unless Carlos explicitly approves in the
  chat.** Allowed without asking: `docker compose ps` / `logs`,
  `git status`, `git log`, `git submodule status`, `df`, `free`, `uptime`.
  Everything else (deploying, `git pull`, `build`, `up`, `restart`, editing
  files) needs his OK first. Never run `docker compose down -v`, any
  `prune`, or anything that could delete the `minerlot_bitcoin-data`
  volume: it holds the synced blockchain.
- **Never run `docker compose up` or `infra/deploy.sh` on the
  workstation.** It would start a mainnet Bitcoin Core (days of initial
  sync), take ports 80/3333/3334, and reuse production's container and
  volume names. Building a single image (`docker build infra/public-pool`)
  is fine.
- **Testing public-pool changes** (`infra/public-pool`, a git submodule
  pointing at the fork `CarlosPoggio/public-pool`):
  `cd infra/public-pool && npm ci && npm run build && npm test`.
  Known baseline (2026-11-23): build OK; 53/63 tests pass, and the 10
  failing ones are stale specs broken by our own fork patches, not by the
  environment (details in `docs/PROJECT_STATE.md`, "Dev workstation moved
  to srclaude"). Compare against that baseline rather than expecting all
  green. **Do not run `npm run lint`**: it uses `eslint --fix` and
  reformats ~70 upstream files. Check lint without changing files with
  `npx eslint "{src,apps,libs,test}/**/*.ts"` (upstream itself is not
  lint-clean either). Commits inside the submodule go to the fork, then
  the pointer is bumped in this repo.
- **Secrets**: this repo is public. `local.access.md` (repo root,
  gitignored) holds credentials and access details: never commit it and
  never print its contents. Real `.env` values exist only on the server
  (`/opt/minerlot/infra/.env`).

## Working with the human user

Carlos (the project owner) has no technical/programming background. All
explanations and questions directed at him must avoid jargon and be phrased
in plain terms.

## Language

All repo artifacts — this file, docs, code, comments, commit messages — are
written in English, regardless of the conversation language.

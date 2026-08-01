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
  blocks to other peers, which is irrelevant here. This is what makes the
  project feasible on the current dev machine (i5, 8GB RAM, 250GB SSD) and
  will remain the approach on the eventual production machine.
- **Branch model (git-flow-lite):** `main` = stable/production-ready
  snapshots, GitHub default branch. `develop` = day-to-day integration
  branch, checked out locally by default. Feature work branches from and
  merges back into `develop`; `develop` merges into `main` for releases.
- **Commits:** Conventional Commits (`feat:`, `docs:`, `fix:`, `chore:`,
  etc.). Never add "Co-Authored-By" or any AI-attribution trailer.

## Non-goals

- A proportional/shared pool for external users is explicitly out of scope.
  It is a possible future project, not something to design or build now.
- No deployment/hosting automation until the production machine is decided.

## Working with the human user

Carlos (the project owner) has no technical/programming background. All
explanations and questions directed at him must avoid jargon and be phrased
in plain terms.

## Language

All repo artifacts — this file, docs, code, comments, commit messages — are
written in English, regardless of the conversation language.

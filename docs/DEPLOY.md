# Deploying / redeploying Minerlot

Everything that runs on the production server (`minerlot-node`, currently
`192.168.1.2`) is tracked in this repo under `infra/`. The server's
`/opt/minerlot` directory is a git clone of this repo (or at least of
`infra/`) — not a set of hand-copied files — so shipping a change is:
commit here, `git pull` there, run the deploy script.

## Layout

```
infra/
  docker-compose.yml         # 4 services: bitcoind, public-pool, logs, monitor
  env.example                 # copy to .env on the server, fill in real values
  deploy.sh                   # renders templates from .env, then docker compose up -d --build
  bitcoin/
    Dockerfile                # downloads + SHA256-verifies the official Bitcoin Core binary
    bitcoin.conf.template      # rendered to bitcoin.conf (gitignored, has real RPC password)
  public-pool.env.template     # rendered to public-pool/.env (gitignored)
  public-pool/                 # git submodule -> github.com/CarlosPoggio/public-pool
                                # (our fork, upstream + a small patch, see below)
  logs-service/                 # small Node/ws server streaming bitcoind's debug.log
                                 # to the dashboard's log viewer, read-only volume mount
  monitor/
    index.html.template        # rendered to index.html (gitignored, has the real wallet address)
    nginx.conf                  # reverse proxy: /api/ -> public-pool, /logs-ws -> logs-service
```

Nothing under `infra/` that's gitignored contains real secrets in git —
only `.template`/`.example` files with placeholders are tracked. The
rendered, real-value files live only on the server.

## First-time setup on a (new) server

1. `git clone --recurse-submodules <this repo> /opt/minerlot && cd /opt/minerlot/infra`
   (if already cloned without `--recurse-submodules`, run
   `git submodule update --init` instead)
2. `cp env.example .env` and fill in `RPC_USER`, `RPC_PASSWORD` (pick a new
   long random value — don't reuse examples), and `WALLET_ADDRESS`.
3. `./deploy.sh`

## Shipping an update

1. Make the change (either directly in `infra/`, or in the `public-pool`
   submodule — see below for that case), commit, push to `develop` (or
   `main` for a release), same conventions as the rest of this repo.
2. On the server: `cd /opt/minerlot && git pull && cd infra && ./deploy.sh`.
   `docker compose up -d --build` only rebuilds/recreates containers whose
   image or config actually changed — the `bitcoind` container's data
   volume (`minerlot_bitcoin-data`, pinned by name in `docker-compose.yml`
   so it survives regardless of directory/project naming) is untouched by
   this, so recreating that container does **not** restart the blockchain
   sync from zero.
   - **When only one service actually changed** (e.g. a `public-pool`
     patch), prefer a scoped rebuild instead of the full `deploy.sh`:
     `docker compose build <service> && docker compose up -d <service>`.
     `deploy.sh` runs `docker compose up -d --build` for *every* service,
     including `bitcoind`, whose `Dockerfile` does a live `apt-get` —
     observed failing once on a transient network/DNS hiccup unrelated to
     the actual change being deployed. Scoping the build avoids that, and
     is faster besides. Confirm with `docker compose ps` afterward that
     `bitcoind` wasn't unexpectedly recreated (Compose can still restart a
     dependency of the service you touched); if it was, it comes back
     healthy on its own within `start_period` (180s) — not a problem, just
     worth noticing.

## Changing public-pool itself

`infra/public-pool` is a git submodule pointing at
`github.com/CarlosPoggio/public-pool` — a fork of the upstream project
with a small patch on top (see `docs/PROJECT_STATE.md` for exactly what
and why: crash fix for `getblocktemplate` errors during IBD, plus IP /
share-count / pre-share-connection tracking for the dashboard).

- To pull in new upstream changes: inside `infra/public-pool`,
  `git fetch upstream && git rebase upstream/master` (the `upstream`
  remote is already configured on the server's clone), resolve any
  conflicts with the patch commits, then `git push origin master` and
  bump the submodule pointer in this repo
  (`cd infra && git add public-pool && git commit`).
- To change the patch itself: edit inside `infra/public-pool`, commit
  there (conventional commits, no AI attribution, same as everywhere),
  push to `origin` (the fork), then bump the submodule pointer here the
  same way.

## Firewall reminder

UFW alone does not restrict Docker-published ports (`3333`, `3334`, `80`)
— Docker bypasses it. The actual restriction (LAN-only, `192.168.1.0/24`)
lives in `/etc/ufw/after.rules` on the server itself (not in this repo,
since it's host-level firewall config, not part of the Docker stack). See
`docs/PROJECT_STATE.md` for the exact rule. If you rebuild the server from
scratch, that rule needs to be re-added — it isn't recreated by
`deploy.sh`.

# Pending work

Single to-do list for Minerlot. When Carlos asks to "work on the pending
items", start here. Keep it current: when an item is done, delete it and
record what was done in `docs/PROJECT_STATE.md`; when new work appears,
add it here.

Last reviewed: 2026-11-23 (after moving the dev workstation to `srclaude`).

Rules that apply to every item: production (`minerlot-node`) is read-only
unless Carlos approves each change in the chat, and nothing here runs the
stack on the workstation (see `CLAUDE.md`, "Environment: where things
run").

## 1. Fix the 10 failing public-pool tests

`cd infra/public-pool && npm test` → 53 pass, 10 fail. Not an
environment problem: the unpatched upstream base (`96a9202`) passes all
63. Our own fork patches changed the code and the specs were never
updated. Production is fine.

- `src/models/StratumV1Client.spec.ts`, 9 tests, broken since `2391524`
  (`feat: track per-worker IP, share count, and pre-share connections`).
  The patch added client-service calls (`ensureClientEntity()` from
  `initStratum()`, heartbeat, share counting) that the spec's mocks do not
  provide. Failing:
  - should set difficulty
  - should send job and accept submission
  - should reject duplicate submissions
  - should reject low difficulty shares
  - should reject submissions when the job template has expired
  - should submit and persist found blocks
  - should update address best difficulty through the atomic path
  - should use the header-only fast path for non-block submissions
  - should write accepted response before share accounting finishes
- `src/controllers/client/client.controller.spec.ts`, 1 test
  (`ClientController › should be defined`), broken since `cc4b82c`
  (`feat: add per-worker blocksFound/online…`). The controller gained a
  `BlocksService` dependency the test module does not provide.

How: fix the specs (mocks/providers), not the production code, unless a
test reveals a real bug — then stop and explain it to Carlos first. The
fix is committed in the submodule (fork `CarlosPoggio/public-pool`,
branch `master`), pushed with Carlos's permission, and then the
submodule pointer is bumped in this repo. Done when `npm test` shows
63/63. No deploy needed (tests are not part of the running image).

## 2. Lint baseline for public-pool

`npm run lint` runs `eslint --fix` and rewrites ~70 upstream files (pure
Prettier formatting). Upstream is not lint-clean either (3943 errors at
the base, almost all `prettier/prettier`).

- Decide with Carlos: leave it (recommended: reformatting 70 upstream
  files makes future upstream merges painful), or lint only the files we
  changed.
- Housekeeping: on `srclaude`, `infra/public-pool` has a stash
  (`git stash list`) with that auto-reformat. It is not our work; drop it
  with `git stash drop` once Carlos agrees.

## 3. Production stopped abruptly twice (investigate)

The system journal on `minerlot-node` shows boots ending with no shutdown
sequence (the log just stops), i.e. power loss, a hard freeze or someone
holding the power button:

- 2026-11-21 ~13:40 UTC, back at 13:47.
- 2026-11-22 ~14:17 UTC, back at 14:19.
- Before that, a boot ended on 2026-09-06 08:32 UTC (not checked whether
  that one was clean).

The `srclaude` server, in the same house, did **not** restart on those
days, so it was probably not a house-wide power cut. The stack came back
by itself each time.

- Ask Carlos: did he unplug, move or power-cycle the box those days? Is
  it on a different plug or power strip than `srclaude`?
- If not: check for hardware trouble (read-only first: `journalctl -b -1`
  and `-b -2` around the end, `sensors` if installed, `dmesg` for
  thermal/MCE errors). Anything beyond reading needs Carlos's OK.
- Because it came back on its own, the BIOS "After Power Loss → Power On"
  setting (item 6) is possibly already set. Confirm with Carlos.

## 4. Firewall log noise from bitcoind (low priority)

UFW logs `[UFW BLOCK]` for UDP from `minerlot-bitcoind` (172.30.0.2) to the
Docker bridge gateway, destination port 5351. Port 5351 is the
NAT-PMP/PCP port, used for automatic router port mapping. Harmless (the
firewall blocks it, which is what we want for a LAN-only node), but it
fills the log.

- Check Bitcoin Core 31.1's docs for the option that controls NAT-PMP/PCP
  (likely `natpmp=0` in `bitcoin.conf`) before changing anything. It is a
  production config change: needs Carlos's OK and a `bitcoind` restart.

## 5. Production is behind `develop` (no action needed now)

Production runs `develop` at `8b5efb0`; GitHub `develop` is ahead only
with documentation commits. Nothing to deploy. The next real deploy
(`docs/DEPLOY.md`) will catch up.

## 6. BIOS: power on after power loss (Carlos, in person)

Go into BIOS setup on `minerlot-node` (Lenovo ThinkCentre: press F1 at the
Lenovo boot logo, unless the boot screen says otherwise), find
**Power → After Power Loss** (wording may vary) and set it to
**Power On**. Cannot be done remotely. See item 3: it may already be set.

## 7. Access and backups (from the move to `srclaude`)

- Old Windows key: `minerlot_prod` (`claude-code@minerlot-devbox`) is
  still authorized on production next to the `srclaude` key
  (`srclaude-minerlot`). Remove it from `~/.ssh/authorized_keys` on the
  server when Carlos decides to retire the Windows PC. Also delete the
  safety copy `~/.ssh/authorized_keys.bak-20261123` there. Needs Carlos's OK.
- Production-only secrets (`/opt/minerlot/infra/.env`, `bitcoin.conf`,
  which hold the RPC password) have no copy outside the server. Carlos
  keeps backups of this project's secrets in his Google Drive; ask him
  whether to copy these there too (never into this repo).

## 8. Node version parity (low priority)

The workstation has Node 22.22.1 (Ubuntu package); production builds
public-pool with `node:24.16.0-bookworm-slim`. Tests pass the same on 22,
but for exact parity run them in that image, or build it with
`docker build infra/public-pool`.

## Optional / deferred (do not start without Carlos asking)

- Deploy `public-pool-ui` (separate Angular/Caddy project) for a fancier
  dashboard. Low priority: `minerlot-monitor` already covers the needs.
- Opening the pool to the internet with a 2% fee: roadmap only, see
  `docs/ROADMAP_PUBLIC_POOL.md`.
- Flashing NerdMiner from `srclaude`: would need the fork
  `CarlosPoggio/NerdMiner_v2` (branch `minerlot`) cloned there, the device
  on USB and `carlos` in the `dialout` group. See `docs/PROJECT_STATE.md`.

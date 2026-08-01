# Roadmap: opening Minerlot to external miners with a 2% fee

**Status: planning only, not started.** Decided 2026-08-01: Carlos wants
this eventually, not now. Nothing in this document has been implemented —
it's here so a future session (or Carlos) can pick it up without
re-deriving the plan. Update `docs/PROJECT_STATE.md`'s "what exists right
now" once any of this actually gets built.

## What this changes, in one paragraph

Today, Minerlot is a personal solo-mining backend: only Carlos's own
Bitaxes connect, over the LAN, and whoever finds a block keeps 100% of
it. This roadmap turns it into a **public solo-mining pool with a 2% fee**
— anyone can point their own miner at it from anywhere on the internet,
whoever's miner finds a block keeps ~98% of the reward (not split with
other miners — this is still solo mining, not proportional/PPS/PPLNS),
and Minerlot takes a 2% cut on top. This is a real scope change from the
original "personal use only" brief — worth re-confirming with Carlos
right before starting, not just once now.

## Good news: the fee mechanism already exists upstream

public-pool already supports a dev fee natively —
`sendNewMiningJob()` in `StratumV1Client.ts` builds a `payoutInformation`
array of `{address, percent}` splits applied directly in the coinbase
transaction (verified by reading the code, not assumed):

```ts
if (this.noFee || devFeeAddress == null || devFeeAddress.length < 1) {
    payoutInformation = [{ address: this.clientAuthorization.address, percent: 100 }];
} else {
    payoutInformation = [
        { address: devFeeAddress, percent: 1.5 },
        { address: this.clientAuthorization.address, percent: 98.5 }
    ];
}
```

Two things to change to get a straight 2% fee from everyone:

1. **The split is hardcoded at 1.5% / 98.5%**, not read from an env var.
   Needs a small patch (same pattern as our other patches — see
   `docs/PROJECT_STATE.md`) to change it to 2/98, ideally reading the
   percentage from a `DEV_FEE_PERCENT` env var instead of hardcoding it
   again, so it's tunable without a rebuild next time.
2. **Fee is waived entirely below 50 TH/s** (`this.noFee` — a single
   Bitaxe is ~1-2 TH/s, so under the current logic small hobbyist miners
   would pay nothing at all). Decide deliberately whether to keep that
   threshold (fee only from serious/larger rigs) or remove it (fee from
   everyone, including tiny miners) — this is a product decision, not
   just a technical one, and changes how much revenue this could
   realistically produce.
3. Set `DEV_FEE_ADDRESS` in `public-pool/.env` (via the `.template`, not
   hardcoded — same secret-handling pattern as `WALLET_ADDRESS`) to a
   **dedicated fee-collection address**, separate from Carlos's own
   personal mining payout address, for clean accounting.

## Networking: domain, dynamic IP, port forwarding

- Buying `minerlot.com` (or similar) is straightforward and cheap
  (roughly €10-15/year for a `.com` through any registrar). DNS hosting
  itself — pointing the domain at an IP address — is free with basically
  every registrar.
- **Open question, needs Carlos to check with his ISP**: is his home
  connection's public IP static or dynamic? (Current public IP as of
  2026-08-01: `188.127.184.85` — but a single snapshot doesn't tell you
  whether it's static; that depends on the ISP's lease policy.) If
  dynamic (common and cheaper for residential connections), the DNS
  record needs to auto-update whenever the IP changes — a small **Dynamic
  DNS (DDNS)** setup, several free options exist (e.g. a small script on
  the server itself hitting the registrar's API on an interval, or a
  free DDNS provider). If static, this step is skipped entirely.
- **Router port forwarding**: Carlos's home router needs to forward the
  public stratum port to `192.168.1.2:3333` internally. This has to be
  done by Carlos in his router's own admin page — not something doable
  remotely without router-specific access. Consider forwarding a
  *different* external port than 3333 (e.g. a random high port) mapped to
  internal 3333, purely to cut down on generic internet background-noise
  scanning — cosmetic, not real security.
- **Do not forward port 80 (the dashboard) publicly as-is.** It currently
  has zero authentication by design (fine for "only my LAN"), and shows
  every connected worker's payout address. For a public pool, either:
  (a) don't expose it publicly at all and keep it as Carlos's own private
  admin view (reachable only over the VPN/LAN — see "what stays
  personal" below), or (b) redesign it before exposing it (hide/truncate
  other people's addresses, or split into a public per-miner stats page
  vs. a private admin/revenue view). This needs a decision before
  exposing anything, not an afterthought.
- **Check the ISP's terms of service** for running always-on
  internet-facing services from a residential connection — some
  residential plans technically restrict or deprioritize this. Worth
  five minutes of reading before relying on it.

## Security hardening needed once stratum is internet-facing

Today's firewall setup (`docs/PROJECT_STATE.md` — the `DOCKER-USER`
iptables rule) deliberately restricts everything to `192.168.1.0/24`. To
go public, that specific restriction needs to be relaxed for the stratum
port only (not RPC, not the dashboard unless deliberately redesigned per
above). Things worth having in place before flipping that switch:

- Rate limiting / connection limits per source IP on the stratum port
  (public-pool has `STRATUM_MAX_CONNECTIONS_PER_LISTENER`, already set,
  but that's a global cap, not per-IP — consider `fail2ban` or an
  iptables `hashlimit` rule for basic abuse protection).
- Monitoring bandwidth/connection counts, since load becomes
  unpredictable once it's not just Carlos's own known devices.
- A plan for what happens if the server gets more connections than the
  hardware comfortably handles (this is still a single home PC, not
  scaled infrastructure).

## Legal/regulatory note

Taking a fee on blocks found by other people's hardware, where the
reward pays out directly to their own address via the coinbase
transaction (never custodied by Minerlot at any point), is how existing
solo pools with fees already operate (e.g. public-pool.io itself, which
this software originally powers) and is very likely not money
transmission — but this isn't legal advice, and it's worth a real
professional opinion if this ever gets meaningful traction, not an
assumption baked into the roadmap.

## What stays personal (non-goals of this roadmap)

- This is still **not** a proportional/PPS/PPLNS pool — no reward
  splitting between multiple miners' contributed shares. Whoever's own
  hardware finds the block keeps ~98% of it; that part of the "no
  proportional pool" original decision doesn't change.
- Carlos's own Bitaxes keep working exactly as documented in
  `docs/CONECTAR_MINERO.md` regardless of whether this roadmap is ever
  built — nothing here requires changing how his own devices connect.

## Suggested order of work, when this actually starts

1. Confirm with Carlos this is still wanted, and resolve the two product
   decisions flagged above (fee threshold behavior; dashboard exposure
   approach) — don't start coding before these are settled.
2. Patch public-pool for the 2%/98% split + `DEV_FEE_PERCENT` env var
   (small, same pattern as existing patches in the fork).
3. Set up the dedicated fee-collection address and `.env` values.
4. Domain + DNS (+ DDNS if needed).
5. Security hardening (rate limiting, monitoring) — before opening the
   port, not after.
6. Router port forward + firewall rule relaxation for the stratum port
   only.
7. Dashboard decision executed (kept private, or redesigned for public
   use).
8. Soft launch, watch logs/load closely for the first while.

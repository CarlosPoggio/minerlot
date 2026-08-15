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
  DNS (DDNS)** setup. Concrete plan: Carlos already has a Cloudflare
  account/zone (`raspi.com`, used for the Loxone/Google Home bridge) —
  the same account can host a `minerlot.com` zone (or a subdomain of
  `raspi.com`, if he'd rather not buy a second domain), and a small
  script on the Minerlot server can hit the Cloudflare API on an interval
  to keep the A record pointed at the current public IP. Straightforward
  to build when this starts; not built yet.
- **The dashboard specifically can reuse the existing Cloudflare Tunnel**
  Carlos already runs for the Loxone/Google Home bridge — Cloudflare
  Tunnel is an HTTP(S)-oriented product, and the dashboard is plain HTTP,
  so this is just adding one more public-hostname route
  (`pool.raspi.com` or similar → `http://192.168.1.2:80`) to the same
  running `cloudflared` daemon, no new tunnel needed. **This does not
  extend to the stratum port** — Cloudflare Tunnel's free tier is
  HTTP-oriented; proxying an arbitrary raw-TCP protocol like stratum
  through Cloudflare requires **Spectrum, which needs an Enterprise
  plan** (verified against Cloudflare's own docs, 2026-08-01) — not a
  fit for this project. The stratum port still needs a real port-forward
  + DDNS, as above.
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
above).

**On "publishing" the port (Carlos asked, 2026-08-01)**: the stratum
port has to be publicly known for miners to connect to it — that's
unavoidable and not itself a meaningful extra risk. Automated internet
scanners (Shodan-style mass scanning) find every open port on every
public IP within hours regardless of whether anyone "announces" it, so
treating the port number as a secret buys essentially nothing. The real
risk reduction comes from defense in depth, not obscurity:
narrow exposure (only this one port, nothing else, is reachable —
RPC/dashboard/SSH stay LAN-only regardless), Docker containment (a bug
in the stratum handler compromises the container, not the host, unless
there's *also* a container-escape vulnerability), the network
segmentation above (even a fully compromised container/host still can't
reach the main LAN), and Node.js's memory-safety (rules out the
memory-corruption vulnerability class that's historically been the worst
category for internet-facing C/C++ daemons). This is the same exposure
profile as any ordinary website — port 80/443 being "known" isn't
considered a security problem for those either; what matters is what's
actually running behind it. Things worth having in place before flipping
that switch:

- Rate limiting / connection limits per source IP on the stratum port
  (public-pool has `STRATUM_MAX_CONNECTIONS_PER_LISTENER`, already set,
  but that's a global cap, not per-IP — consider `fail2ban` or an
  iptables `hashlimit` rule for basic abuse protection).
- Monitoring bandwidth/connection counts, since load becomes
  unpredictable once it's not just Carlos's own known devices.
- A plan for what happens if the server gets more connections than the
  hardware comfortably handles (this is still a single home PC, not
  scaled infrastructure).

## Network segmentation: correcting a "DMZ" assumption (2026-08-01)

Carlos asked whether putting the server in a "DMZ" would keep an
attacker who compromised it out of the rest of the home LAN. Important
correction, checked against how home routers actually implement this:
**the "DMZ" checkbox on a consumer router is not a real DMZ.** It just
forwards *every* port (not only 3333) to that one device — same LAN,
same subnet, same exposure to every other device on the network, just a
much larger attack surface than forwarding a single port. It's a
downgrade compared to what's already planned (forward only the stratum
port), not an upgrade.

A **real** DMZ is a separate, firewalled network segment: the exposed
server sits on its own VLAN/subnet, and the firewall between that
segment and the main LAN blocks the DMZ from initiating connections
inward — so even a fully compromised box can't reach Carlos's laptops,
phones, NAS, or the Loxone system. Building that for real needs either a
router with VLAN support or an extra piece of hardware (a small
VLAN-capable managed switch, or a dedicated firewall box like
OPNsense/pfSense, or even a cheap OpenWrt travel router) sitting between
the ISP router and the Minerlot server — not just a setting.

**Practical recommendation for this project's actual scale**: the real
attack surface here is narrow and well-understood (one specific
application protocol — stratum — nothing else reachable; RPC, SSH, and
the dashboard all stay LAN-only regardless). Before reaching for a full
VLAN buildout:
1. Check whether Carlos's current router/mesh system already offers a
   "guest network" or "IoT network" — many consumer routers (and most
   mesh systems) implement these with genuine client isolation from the
   main LAN, which is most of the benefit of a real DMZ without buying
   anything.
2. If not, and this becomes worth the effort, a cheap secondary
   VLAN-capable router/switch between the ISP box and the Minerlot
   server is the realistic middle ground — full pfSense/OPNsense is
   available but likely overkill for a single hobby server.
3. Either way: keep only the stratum port forwarded (never use the
   router's literal "DMZ" feature), keep the existing fail2ban/rate-limit
   plan above, and keep monitoring logs.

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

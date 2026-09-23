# amfetamin-engine (gecit)

DPI bypass engine used by amfetamin. Forked from [boratanrikulu/gecit](https://github.com/boratanrikulu/gecit).

## Routing (macOS / Windows)

Everything goes through the TUN (`utun85`, 10.0.85.1/30) and is proxied out of
the physical interface, which is detected from the default route before the
TUN is created. TLS connections to the target ports (443) get fake
ClientHellos with a low TTL; the built-in DoH server answers DNS on
127.0.0.1:53 (A records only by default — `--filter-aaaa`, since the TUN is
IPv4-only).

Game traffic can be taken out of the TUN with `--bypass-rule`:

| Spec | Effect |
|------|--------|
| `udp:4950-4955`, `tcp:6695`, `27015` | flows from/to these ports skip the tunnel |
| `udp:auto` | every UDP flow except DNS/QUIC/DoT and Discord skips the tunnel |

UDP game flows (and flows from a matching source port) are *routed around*
the TUN: the destination gets a /32 host route via the physical gateway
(Windows) or is excluded from the TUN routes (macOS). Discord destinations
always stay in the tunnel.

## Control

- `run --log-file <path>` writes a rotating log (5 MB) instead of stderr.
- Windows: `amfetamin-engine stop` (or signalling `Global\AmfetaminEngineStop`)
  shuts the engine down cleanly; a second instance refuses to start.
- `cleanup` restores DNS and removes host routes after a crash.

## Build

```bash
../scripts/build-engine.sh windows   # CGO_ENABLED=0 — Npcap is loaded at runtime
../scripts/build-engine.sh darwin    # macOS host, arm64 + amd64 (libpcap via cgo)
```

Releases are built by `.github/workflows/release.yml` from a `vX.Y.Z` tag; the
engine is bundled in both platform zips and attached with `checksums.txt`.

# Security policy

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability, leaked
credential, signing key, or privacy flaw. Use GitHub's private vulnerability
reporting/security-advisory channel for this repository, or contact the
repository maintainers through the private Calypso Systems support channel.

Include the affected version or commit, reproduction steps, impact, and any
safe mitigation. Remove credentials from the report; if a secret was exposed,
revoke or rotate it first.

## Security boundaries

- Body Flow & Go stores health records locally and does not upload them
  automatically.
- Optional feedback is a separate, user-initiated network flow. Its endpoint
  is injected at build time and must be HTTPS.
- Slack webhook URLs and gateway credentials belong on the server or in a
  managed secret store, never in this app or its Git history.
- Android signing keys and `key.properties` remain untracked.

See [docs/google_play_data_safety.md](docs/google_play_data_safety.md) for the
current data-flow review.

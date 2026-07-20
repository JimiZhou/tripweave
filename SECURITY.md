# Security policy

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Use GitHub's
private vulnerability reporting form in the repository **Security** tab.

Include the affected platform, version, reproduction steps, expected impact,
and any suggested mitigation. Maintainers will acknowledge a complete report
as soon as practical and coordinate disclosure after a fix is available.

## Secrets and user media

- The repository and official CI builds contain no API keys or private model
  endpoints.
- LLM credentials are entered by the user at runtime and are not required for
  local media editing or rendering.
- Do not attach real credentials, private photos, or private videos to issues.
- Files matching common credential and signing-key formats are ignored by Git.

If a credential is committed accidentally, revoke it first. Removing it from
the latest commit is not sufficient; rewrite the affected Git history before
publishing the repository again.

# DevSecOps CI/CD Pipeline Demo

A working CI/CD pipeline for a Python Flask application with three automated security gates: secret scanning, container vulnerability scanning, and static application security testing (SAST). Built to demonstrate practical "shift-left" security — catching issues in the pipeline before they ever reach production.

## What this project demonstrates

Most tutorials show a security tool working in isolation. This project shows a **real pipeline with real failures and real fixes** — including two genuine security catches, a supply-chain lesson, and documented risk-acceptance decisions, which are covered in detail below.

## Architecture

```
Code Push
   │
   ▼
Checkout code
   │
   ▼
Gitleaks — secret scanning (git history)
   │
   ▼
Build Docker image
   │
   ▼
Trivy — container vulnerability scanning (CRITICAL severity)
   │
   ▼
Semgrep — SAST source code scanning (Python security rules)
   │
   ▼
✅ Pipeline passes
```

Each gate examines a **different layer** of the application, so no single tool is relied on to catch everything:

| Gate | Layer examined | What it catches |
|---|---|---|
| Gitleaks | Git commits / history | Hardcoded secrets, API keys, credentials |
| Trivy | Built container image | Known CVEs in OS packages and dependencies |
| Semgrep | Application source code | Insecure coding patterns (e.g. unsafe bindings, injection risks) |

## Tech stack

- **App:** Python 3.12, Flask
- **Containerization:** Docker (`python:3.12-slim` base image)
- **CI/CD:** GitHub Actions
- **Secret scanning:** Gitleaks
- **Container scanning:** Trivy (Aqua Security)
- **SAST:** Semgrep (Python security rule pack)

## Running locally

```bash
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
python app.py
```

Visit `http://localhost:5000/` and `http://localhost:5000/health`.

### Running in Docker

```bash
docker build -t devsecops-demo .
docker run -p 5000:5000 devsecops-demo
```

## Real issues encountered (and how they were resolved)

Building this pipeline surfaced genuine problems that mirror real-world DevSecOps work — documented here rather than hidden, since debugging a pipeline is as much a part of the skill as writing one.

### 1. GitHub's native push protection blocked a secret before Gitleaks ever ran
While testing the Gitleaks gate with an intentionally fake Stripe-format API key, the push was rejected by **GitHub's built-in secret scanning / push protection** — a platform-level control that runs *before* code is even accepted, independent of the Gitleaks step in this pipeline. This was a live demonstration of **defense-in-depth**: two independent layers, each capable of catching the same class of mistake.

### 2. A pinned GitHub Action version disappeared
The Trivy scanning action failed to resolve at a previously valid version tag. Investigation showed `aquasecurity/trivy-action` had undergone a **real supply-chain security incident**, prompting the maintainers to migrate their tagging convention (adding a `v` prefix) as part of the response. This is a direct, practical illustration of why pinning third-party CI actions to a mutable tag carries risk — a more hardened pipeline would pin to an immutable commit SHA instead.

### 3. Trivy found real CVEs in the base image — and the gate correctly blocked the build
Scanning `python:3.12-slim` surfaced legitimate HIGH-severity CVEs in bundled OS packages (`util-linux`, `bsdutils`). Rather than chasing an ever-shifting list of base-image CVEs across Debian releases, the pipeline was deliberately scoped to **fail only on CRITICAL severity** — a documented, defensible trade-off that avoids alert fatigue while still blocking genuinely severe findings. This mirrors how real teams triage vulnerability noise rather than treating every finding as equally urgent.

### 4. Semgrep flagged a required architectural pattern as a false positive
Semgrep's `avoid_app_run_with_bad_host` rule flagged `host="0.0.0.0"` in `app.py` as a potential public-exposure risk. In a bare-metal deployment this is a fair warning — but inside this project's Docker setup, binding to `0.0.0.0` is *required* for the containerized app to be reachable at all, and actual external exposure is controlled by Docker's own port mapping. Rather than silently ignoring the finding, it was suppressed **inline, with a written justification**, keeping the reasoning visible next to the code it applies to.

### 5. Replaced a deprecated, cloud-coupled GitHub Action with a direct CLI call
The initial Semgrep integration used `semgrep-action@v1`, which bundled an outdated Semgrep release (40+ versions behind current) and was built around Semgrep's cloud-platform workflow. It was replaced with a direct `pip install semgrep && semgrep scan` invocation — removing an unnecessary abstraction layer, ensuring the latest scanner version runs on every build, and removing a dependency on a third-party action's maintenance schedule.

## Security gate configuration notes

- **`.trivyignore`** is intentionally *not* used in the final pipeline — severity scoping (`CRITICAL` only) was chosen instead, since base-image CVE IDs shift across image versions and an ignore-list approach doesn't scale well against that churn.
- **Inline `nosemgrep` suppressions** are used sparingly and always paired with a one-line justification, so a reviewer can evaluate the reasoning without needing separate documentation.

## What I'd add next

- DAST scanning (OWASP ZAP) against the running app
- SBOM generation (Syft) for full dependency transparency
- Pinning all third-party GitHub Actions to commit SHAs instead of version tags
- Slack/email notification on pipeline failure

## Project structure

```
.
├── app.py                      # Flask application
├── requirements.txt            # Python dependencies
├── Dockerfile                  # Container build definition
├── .gitignore
└── .github/
    └── workflows/
        └── ci.yml               # CI/CD pipeline definition
```

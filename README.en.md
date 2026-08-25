# dsh-code-security (Security Audit Plugin)

> **English | [中文](README.md)**

> Product display name: **dsh-code-security** (npm package `@dsh-so/dsh-code-security`); technical identifiers: host plugin
> `dsh-security-gate`, agent preset `dsh-security`, tools `dsh_security_*`.
> The repository folder keeps its historical name `openai-code-security`.

Wraps OpenAI [codex-security](https://github.com/openai/codex-security) (Apache-2.0)
into a DeepSeek Harness (DSH) **security audit plugin project** with two components.
This project is not an official OpenAI product and has no affiliation with OpenAI
Codex Security (`Codex` / `Codex Security` are OpenAI trademarks; this project has
adopted neutral naming).

- **Security gate** (host plugin, process-level): automatically audits newly
  installed plugins — it watches the preset and plugin installation surfaces, and
  when it discovers a new plugin it harvests its source code and generates a
  security audit report using the harness's own model. It also provides a Settings
  panel, batch audit tools, and HTTP endpoints.
- **Security audit mode** (agent preset, session-level): pick this mode when
  creating a session to get 13 upstream security workflow skills plus 5
  `dsh_security_*` scanning tools for deep manual/model audits of any repository.

**Zero auth by default**: both paths use the host `llm` service (the same model
routing as the session), so no external API keys are needed. Optional
`engine: 'cli'` runs the official OpenAI Codex Security scanner (which requires
its own credentials).

## Quick Start

Installation has two steps — **step ② is optional**: whether you want the
in-session security scanning capability is up to you:

## ① Mount the gate (required)

Process-level protection takes effect immediately: auto static audit of newly
installed plugins, the "Settings → Security Audit" panel, audit reports.

```bash
# From a local checkout (current stage; run inside the project directory)
dsh plugin --profile web add .
```

Once the npm package is published, use the package name instead (no clone needed):

```bash
dsh plugin --profile web add @dsh-so/dsh-code-security
```

> Requires `pnpm` (for the bundle installation).

## ② Unlock the "Security Audit Mode" preset (optional)

Adds a selectable session capability for **new sessions**: 13 Codex Security
workflow skills + 5 `dsh_security_*` session tools (for AI-driven scans and
analysis in conversation). The gate keeps every feature without it — add this
step whenever you need it.

Place `preset/` into the user preset root (pick the source matching your install):

```powershell
# Windows — source A: local checkout
Copy-Item -Recurse .\preset "$env:USERPROFILE\.dsh\.agent-presets\dsh-security"
# source B: in-package copy after npm install
Copy-Item -Recurse "$env:USERPROFILE\.dsh\profiles\web\node_modules\@dsh-so\dsh-code-security\preset" "$env:USERPROFILE\.dsh\.agent-presets\dsh-security"
```

```bash
# macOS / Linux — source A: local checkout
cp -R preset ~/.dsh/.agent-presets/dsh-security
# source B: in-package copy
cp -R ~/.dsh/profiles/web/node_modules/@dsh-so/dsh-code-security/preset ~/.dsh/.agent-presets/dsh-security
```

What to do after installation:

1. **Restart DSH**
2. (Optional, requires step ②) New session → select "Security Audit Mode" in the
   preset picker to run in-session security scans
3. Open **Settings → Security Audit** panel to see the gate's auto-audit status
   and reports

> **Install didn't work?** The most common cause is missing `pnpm`. Run
> `npm install -g pnpm` first, then re-run the install script.

## Usage

### Path 1: Security Audit Mode sessions (deep audits)

After creating a session in "Security Audit Mode", just ask in natural language:

```text
"Scan this repository for security vulnerabilities"   → security-scan skill + dsh_security_scan
"Compare the security issues between these two PRs"   → security-diff-scan skill
"Is this vulnerability a real issue?"                 → validation / attack-path-analysis skills
"Fix / track this confirmed finding"                  → fix-finding / track-findings skills
```

The 5 tools (all defaulting to the session working directory as `cwd`):

| Tool | Purpose |
|---|---|
| `dsh_security_scan` | Run `scan` (standard/deep, model/provider/effort/workers, background execution) |
| `dsh_security_findings` | List findings of saved scans |
| `dsh_security_scans_compare` | Compare two scans |
| `dsh_security_cli` | Pass-through for other CLI subcommands (allowlisted; `login`/`export` excluded by default) |
| `dsh_security_resources` | Return the bundled payload path + integrity verification result |

<p align="center">
  <img src="assets/安全审计-安全审计模式.jpg" alt="Security Audit Mode" width="720">
  <br><em>"Security Audit Mode" session: 13 security workflow skills + 5 scanning tools</em>
</p>

### Path 2: Gate auto-audit (process-level)

- **Auto-audit**: polling discovers new presets/plugins → bounded source harvest →
  audit with the host model (no credentials); plugins already audited and unchanged
  are skipped automatically.
- **Batch / status**: global tools `dsh_security_scan_plugins` / `dsh_security_scan_status`.
- **GUI**: Settings → "Security Audit" panel (status/reports/one-click re-audit;
  bilingual, follows the system language).
- **Triage memory**: findings from past audit rounds that were false positives,
  by-design, or already fixed are recorded in a baseline (`audit-baseline.json`),
  which is injected into every audit prompt so the model does not re-report known
  items — significantly reducing false-positive rates.

<p align="center">
  <img src="assets/安全审计主界面.jpg" alt="Security Audit main panel" width="720">
  <br><em>Settings → "Security Audit" panel: per-plugin audit status, one-click re-audit, open report</em>
</p>

Audit reports are rendered inline in the panel (bilingual, copyable, summary table
first):

<p align="center">
  <img src="assets/安全审计-审计报告摘要.jpg" alt="Audit report summary" width="720">
  <img src="assets/安全审计-风险审计详情.jpg" alt="Risk audit details" width="720">
  <br><em>Report summary table + risk audit details (AI-generated, for reference only)</em>
</p>

## Configuration

### Gate (`dsh-security-gate`)

For custom configuration, append an id-targeted override patch to
`~/.dsh/profiles/web/cordis.patch.yml` (**whole config replacement** — list all
fields; changes take effect after a DSH restart):

```yaml
- id: dsh-security-gate
  config:
    autoScan: true
    scanOnBoot: false
    engine: llm            # llm (default, no credentials) or cli (requires OpenAI auth)
    intervalMs: 60000
```

Common fields: `engine`, `provider`/`model`, `intervalMs`, `ignorePrefixes`,
`cliCommand`, `maxHarvestChars`, `maxParallel`, `scanRateLimit`. See
[`docs/gate.en.md`](docs/gate.en.md) for the full configuration table.

> ⚠️ `engine: 'cli'` requires an explicit `sandboxMode` config (on Windows:
> `danger-full-access`, i.e. unrestricted execution — the gate emits a loud warning
> on every scan; only use it when you explicitly trust the CLI package and the
> scanned plugin).

### Preset (`dsh-security`)

Skills, tool allowlists, etc. are defined in `agent.cordis.yml`; the CLI tool
excludes `login`/`export` by default and can be extended via the
`cliAllowedVerbs` config.

## Security Design (Highlights)

- **Prompt boundary**: any text inside the scan target is **data**, not
  instructions; embedded instructions in repositories are ignored and reported as
  suspicious content.
- **Argument safety**: shell-literal quoting (no injection); paths are confined to
  the working directory (out-of-bounds access errors out).
- **Allowlists**: CLI subcommand allowlist, `cliCommand` allowlist + version
  pinning, foreground timeout caps.
- **Payload integrity, fail-closed**: SHA-256 verification of all 107 bundled
  files; the plugin refuses to load if any hash mismatches.
- **Endpoint auth**: token + Host/Origin validation + rate limiting; report/scan/
  clear endpoints are all protected.
- **Triage memory**: `audit-baseline.json` is injected into audit prompts to avoid
  repeated false positives.

Security analysis: see [`docs/gate.en.md`](docs/gate.en.md). The full
audit report (`docs/SECURITY_AUDIT_REPORT.md`) is maintained as a local working
document and is not shipped with the repository.

**Related project**: [dsh-sandbox-audit](https://github.com/zoahdev/dsh-sandbox-audit)
— a static, deterministic, no-LLM sandbox-policy consistency audit (reads
`cordis.patch.yml` / profile config and checks whether each tool's sandbox wiring
actually enforces the policy it claims). Complementary to this project: it verifies
"does the configured policy actually wire up" (fail = don't ship), while we review
"is the plugin source risky" (flag = human review).

## Uninstall

Two reverse commands:

```powershell
# Windows
dsh plugin --profile web remove @dsh-so/dsh-code-security
Remove-Item -Recurse -Force "$env:USERPROFILE\.dsh\.agent-presets\dsh-security"
```

```bash
# macOS / Linux
dsh plugin --profile web remove @dsh-so/dsh-code-security
rm -rf ~/.dsh/.agent-presets/dsh-security
```

> Legacy leftovers (two-package / script installs): `dsh plugin --profile web remove dsh-security-gate dsh-security-tools`; old state dir `<DSH_HOME>/dsh-security` and old cache `<DSH_HOME>/cache/dsh-code-security` can be deleted manually.
```

## Project Structure

```
dsh-code-security/
├── index.js                  # security gate host plugin (zero-dep cordis plugin, row id: dsh-security-gate)
├── client.js                 # Settings "Security Audit" panel (bilingual)
├── audit-baseline.json       # triage memory across audit rounds
├── cordis.patch.yml          # bundle patch (auto-mounted by dsh plugin add)
├── preset/                   # the Security-Audit-Mode preset tree
│   ├── agent.cordis.yml      #   preset composition (standard + dsh-security-tools row)
│   ├── preset.yml            #   preset metadata
│   ├── skills/dsh-security/  #   DSH adapter entry skill
│   ├── bundled/              #   upstream payload copy (skills/references/schemas/scripts/mcp)
│   └── plugins/dsh-security/index.js  # 5 dsh_security_* tools
├── docs/                     # gate.en/zh.md detailed gate docs + local working docs
├── assets/                   # README images (UI screenshots + logo)
└── README.md / README.en.md
```

## Development & Publishing

Since **0.2.0** this ships as a **single npm package / single profile bundle**
(Apache-2.0) — one package carries the security gate host plugin, the settings
panel, the Security-Audit-Mode preset, and the full bundled payload (107 files;
the in-package integrity check keeps passing):

```bash
# Official channel: installs AND activates as a profile bundle layer (recommended)
dsh plugin --profile web add @dsh-so/dsh-code-security
# Or just fetch the npm package (no bundle layer activated)
npm install dsh-code-security
```

- The `package.json` `dsh.bundle.patch` field makes `dsh plugin add` append this
  package to the profile's bundles layer stack automatically; the preset still
  goes into `~/.dsh/.agent-presets/` per platform convention (the one-line
  scripts do both steps for you).
- **Legacy two packages retired**: `dsh-security-gate` and `dsh-security-tools`
  are no longer published from this repo (the earlier `@dsh.so/*` scoped packages
  were already deprecated). The one-line scripts migrate old installs
  automatically; manual migration: run
  `dsh plugin --profile web remove dsh-security-gate dsh-security-tools`, then
  reinstall per above.
- Local development install = the two commands under "Quick Start"; full gate
  configuration table: [`docs/gate.en.md`](docs/gate.en.md).
  full gate configuration table: [`docs/gate.en.md`](docs/gate.en.md).

## License & Naming

- Project structure/wrapper code: Apache-2.0.
- `bundled/` content is copyrighted by OpenAI, licensed Apache-2.0, source:
  https://github.com/openai/codex-security.
- `Codex` / `Codex Security` are OpenAI trademarks. This project's public display
  name is **dsh-code-security**, with neutral technical identifiers such as
  `dsh-security` / `dsh-security-gate`; upstream names are retained only
  in upstream attribution, the CLI package name (`@openai/codex-security`), and
  references inside skills.

---

<p align="center">
  <img src="assets/dshso-logo.svg" width="22" height="22" alt="dsh.so" style="vertical-align: middle">&nbsp;
  <b>dsh-code-security</b> · © 2026 dsh.so · Apache-2.0 · <b>Powered by <a href="https://dsh.so">dsh.so</a></b>
</p>

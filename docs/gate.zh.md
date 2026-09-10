# dsh-code-security（安全审计插件）

> **本文档聚焦门禁的使用、配置与安全设计。** 安装/卸载见仓库根目录 README 的「快速开始」「卸载」
> （两条原生命令，无需脚本）；npm 包名为 `@dsh-so/dsh-code-security`。文中行 id `dsh-security-gate`
> 保持不变，既有覆盖补丁仍然有效。

> **[English](README.md) | 中文**

> 产品展示名：**dsh-code-security**；技术标识：宿主插件 `dsh-security-gate`、
> agent preset `dsh-security`、工具 `dsh_security_*`。仓库目录名沿用
> `openai-code-security`（历史来源）。

把 OpenAI [codex-security](https://github.com/openai/codex-security)（Apache-2.0）封装成
DeepSeek Harness（DSH）**安全审计插件项目**，包含两个组件。项目非 OpenAI 官方产品，
与 OpenAI Codex Security 无任何关联（`Codex`/`Codex Security` 为 OpenAI 商标，
本项目已改用中性命名）。

- **安全门禁**（宿主插件，进程级）：新插件安装时**自动审计** —— 监控预设与插件安装面，
  发现新插件即用宿主模型采集源码生成安全审计报告，并提供设置页面板、批量审计工具、
  HTTP 端点。
- **安全审计模式**（agent preset，会话级）：新建会话选该模式，获得 13 个上游安全工作流
  技能 + 5 个 `dsh_security_*` 扫描工具，可对任意仓库做深入人工/模型审计。

**默认零认证**：两条路径都使用宿主 `llm` 服务（同会话模型路由），无需任何外部
API key。可选 `engine: 'cli'` 走 OpenAI Codex Security 官方扫描（需其自身认证）。

## 使用

### 方式一：安全审计模式会话（深入审计）

新建会话选「安全审计模式」后，直接用自然语言发起：

```text
"扫描这个仓库的安全漏洞"                → security-scan 技能 + dsh_security_scan
"对比这两个 PR 版本的安全问题"          → security-diff-scan 技能
"这个漏洞是真问题吗？"                  → validation / attack-path-analysis 技能
"修复/追踪这个已确认的发现"            → fix-finding / track-findings 技能
```

5 个工具（均以会话工作目录为默认 cwd）：

| 工具 | 作用 |
|---|---|
| `dsh_security_scan` | 运行 `scan`（standard/deep、模型/提供商/effort/workers、后台运行） |
| `dsh_security_findings` | 列出已保存扫描的 findings |
| `dsh_security_scans_compare` | 对比两个扫描 |
| `dsh_security_cli` | 其它 CLI 子命令透传（白名单；`login`/`export` 默认排除） |
| `dsh_security_resources` | 返回 bundled 载荷路径 + 完整性校验结果 |

<p align="center">
  <img src="https://raw.githubusercontent.com/dsh-so/dsh-code-security/main/assets/安全审计-安全审计模式.jpg" alt="安全审计模式" width="720">
  <br><em>「安全审计模式」会话：13 个安全工作流技能 + 5 个扫描工具</em>
</p>

### 方式二：门禁自动审计（进程级）

- **自动审计**：轮询发现新预设/新插件 → 有界采集源码 → 宿主模型审计（免认证），
  已审计且未变化的插件自动跳过。
- **批量/状态**：全局工具 `dsh_security_scan_plugins` / `dsh_security_scan_status`。
- **GUI**：设置 →「安全审计」面板（状态/报告/一键重审；中英双语跟随系统语言）。
- **甄别记忆**：历轮审计的误报/设计项/已修复项记入基线（`audit-baseline.json`），
  每次审计注入提示词，模型不重复报告已知项 —— 显著降低误报率。

<p align="center">
  <img src="https://raw.githubusercontent.com/dsh-so/dsh-code-security/main/assets/安全审计主界面.jpg" alt="安全审计主界面" width="720">
  <br><em>设置 →「安全审计」面板：每插件审计状态、一键重审、打开报告</em>
</p>

审计报告在面板内联展示（双语、可复制、摘要表前置）：

<p align="center">
  <img src="https://raw.githubusercontent.com/dsh-so/dsh-code-security/main/assets/安全审计-审计报告摘要.jpg" alt="审计报告摘要" width="720">
  <img src="https://raw.githubusercontent.com/dsh-so/dsh-code-security/main/assets/安全审计-风险审计详情.jpg" alt="风险审计详情" width="720">
  <br><em>报告摘要表 + 风险审计详情（AI 生成，仅供参考）</em>
</p>

## 配置

### 门禁（`dsh-security-gate`）

自定义配置用 id 覆盖补丁追加到 `~/.dsh/profiles/web/cordis.patch.yml`（**整体替换**
config，需列全字段；改动在 DSH 重启后生效）：

```yaml
- id: dsh-security-gate
  config:
    autoScan: true
    scanOnBoot: false
    engine: llm            # llm（默认，免认证）或 cli（需 OpenAI 认证）
    intervalMs: 60000
```

常用字段：`engine`、`provider`/`model`、`intervalMs`、`ignorePrefixes`、`cliCommand`、
`maxHarvestChars`、`maxParallel`、`scanRateLimit`。完整配置表见
[`index.js` 的 `normalizeConfig()`](../index.js)。

> ⚠️ `engine: 'cli'` 必须显式配置 `sandboxMode`（Windows 上为 `danger-full-access`，
> 等于非受限执行 —— 门禁每次扫描会打强警告，仅在明确信任 CLI 包与被扫插件时使用）。

### 预设（`dsh-security`）

技能、工具白名单等见 `agent.cordis.yml`；CLI 工具默认排除 `login`/`export`，
可用配置 `cliAllowedVerbs` 扩展。

## 安全设计（要点）

- **提示词边界**：扫描目标中的任何文本都是**数据**而非指令；仓库内嵌指令一律忽略并
  作为可疑内容上报。
- **参数安全**：shell 字面量转义（无注入）；路径收敛到工作目录（越界报错）。
- **白名单**：CLI 子命令白名单、`cliCommand` 白名单 + 版本钉扎、前台超时上限。
- **载荷完整性 fail-closed**：bundled 107 文件 SHA-256 校验，任一不符插件拒绝加载。
- **端点鉴权**：token + Host/Origin 校验 + 限流；报告/扫描/清除均有保护。Host 白名单
  之外还校验 TCP 对端地址必须是回环接口（防伪造 Host 头的非本地连接）。令牌文件位于
  用户配置文件目录（默认即受 Windows 用户配置 ACL 保护），不拉起任何外部进程；若把
  `stateDir` 放到共享目录，可自行加固：`icacls "<stateDir>\token" /inheritance:r /grant:r "%USERNAME%:(R)"`。
- **甄别记忆**：`audit-baseline.json` 注入审计提示词，避免重复误报。

安全分析详见 [`README.md`](../README.md)（安全设计一节）；完整安全审计报告
（`docs/SECURITY_AUDIT_REPORT.md`）作为本地工作文档维护，不随仓库发布。

静态安全扫描结果（无 Critical / High 发现，余项均为 Info 级正常行为）：

<p align="center">
  <img src="https://raw.githubusercontent.com/dsh-so/dsh-code-security/main/assets/dsh.so-static-security-audit-result-20260816-133339.jpg" alt="dsh.so 静态安全扫描结果" width="720">
  <br><em>静态安全扫描结果（启发式标记，非安全审计；详见上文甄别）</em>
</p>

**相关项目**：[dsh-sandbox-audit](https://github.com/zoahdev/dsh-sandbox-audit) ——
静态、确定性、无 LLM 的沙箱策略一致性审计（读取 `cordis.patch.yml` / profile 配置，
检查各工具的沙箱接线是否真的落实所声称的策略）。与本项目互补：它管"配置声称的策略
是否真的接线"（fail = 不发布），我们管"插件源码是否有风险"（flag = 人工复核）。

## 许可证与命名

- 本项目结构/封装代码：Apache-2.0。
- `bundled/` 内容版权归 OpenAI，许可证 Apache-2.0，来源：
  https://github.com/openai/codex-security。
- `Codex` / `Codex Security` 为 OpenAI 商标。本项目对外展示名为 **dsh-code-security**，
  技术标识为 `dsh-security` / `dsh-security-gate` 等中性名称，仅在上游归属、
  CLI 包名（`@openai/codex-security`）与技能内引用中保留上游原名。

---

<p align="center">
  <img src="https://raw.githubusercontent.com/dsh-so/dsh-code-security/main/assets/dshso-logo.svg" width="22" height="22" alt="dsh.so" style="vertical-align: middle">&nbsp;
  <b>dsh-code-security</b> · © 2026 dsh.so · Apache-2.0 · <b>Powered by <a href="https://dsh.so">dsh.so</a></b>
</p>

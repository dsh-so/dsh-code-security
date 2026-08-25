# @dsh-so/dsh-code-security —— DSH 安全审计

[English](README.md) | 中文

[![npm](https://img.shields.io/npm/v/@dsh-so/dsh-code-security)](https://www.npmjs.com/package/@dsh-so/dsh-code-security)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)
[![DSH](https://img.shields.io/badge/DSH-0.1.1--rc.2-blue)](https://github.com/ihuajiu/dsh-code-security)
[![dsh.so risk](https://www.dsh.so/badge/dsh-code-security.svg)](https://www.dsh.so/artifact/dsh-code-security/)
[![dsh.so install](https://www.dsh.so/badge/install/dsh-code-security.svg)](https://www.dsh.so/artifact/dsh-code-security/)

> **审计你安装的插件；武装扫描代码的会话。**
>
> **两层能力，彼此独立，一个包承载：**
>
> - **门禁**（进程级，常驻）：每个新装插件都会被自动静态审计——使用宿主自身模型，零外部凭证。
>   审计结论先进入双语设置面板与落盘报告，之后你才会带着它们启动会话。
> - **安全审计模式**（会话级，可选）：一个可选择的 agent 预设，为对话装配 13 个 OpenAI Codex
>   Security 工作流技能 + 5 个原生 `dsh_security_*` 扫描工具。
>
> **诚实边界**：门禁审计的是*进入 profile 的插件*，不监控你自己源码的运行时行为；预设只在你为
> 会话选择它时才注入能力。两层都不会自行拦截或改写任何东西。

把 OpenAI [codex-security](https://github.com/openai/codex-security)（Apache-2.0）封装成
DeepSeek Harness（DSH）安全审计插件。非 OpenAI 官方产品，与其无任何关联（`Codex` /
`Codex Security` 为 OpenAI 商标，本项目已改用中性命名）。

- 🛡 门禁配置表：[docs/gate.zh.md](docs/gate.zh.md)（英文版：[docs/gate.en.md](docs/gate.en.md)）
- 🔎 相关项目：[dsh-plugin-vet](https://github.com/wulun811/dsh-plugin-vet)——安装期的确定性静态规则扫描；
  本项目补上基于模型的行为审计与会话内深扫模式，两者是互补的纵深防御层。

---

## 架构总览

一个包，两层能力，分别活在 DSH 的不同层级：

<img src="assets/architecture.zh.svg" alt="dsh-code-security 架构：一个包同时供给进程级常驻门禁层与会话级可选的安全审计模式预设" width="880">

- 门禁走的是 **profile 组合包通道**：一条命令永久登记，每次启动都会重新应用它的补丁层。
- 预设从**用户预设根**（`~/.dsh/.agent-presets/`）发现——这是 DSH 目前唯一的预设放置点，
  所以复制动作暂时省不掉。

---

## 安装

分两步，**第 2 步可选**——是否需要会话内的安全扫描能力，由你决定：

### 1. 挂载门禁（必装）

进程级防护立即生效：新装插件自动静态审计、「设置 → 安全审计」面板、审计报告。

```bash
# 从本地 checkout 安装（当前阶段；在项目目录内执行）
dsh plugin --profile web add .
```

npm 包发布后，改用包名即可（无需克隆仓库）：

```bash
dsh plugin --profile web add @dsh-so/dsh-code-security
```

> 需要已安装 `pnpm`。生效链路：pnpm 安装 → 清单登记 `dsh.profile.bundles` → 下次启动组合
> bundles 层挂载插件（行 id `dsh-security-gate`）。

### 2. 解锁「安全审计模式」（可选）

为**新会话**增加一套可选择的会话能力：13 个 Codex Security 工作流技能 + 5 个 `dsh_security_*`
会话工具。不装不影响门禁的任何功能；想用时随时补这一步。

把 `preset/` 放入用户预设根（复制源按你的安装方式二选一）：

```powershell
# Windows —— 源 A：本地 checkout
Copy-Item -Recurse .\preset "$env:USERPROFILE\.dsh\.agent-presets\dsh-security"
# 源 B：npm 安装后的包内副本
Copy-Item -Recurse "$env:USERPROFILE\.dsh\profiles\web\node_modules\@dsh-so\dsh-code-security\preset" "$env:USERPROFILE\.dsh\.agent-presets\dsh-security"
```

```bash
# macOS / Linux —— 源 A
cp -R preset ~/.dsh/.agent-presets/dsh-security
# 源 B
cp -R ~/.dsh/profiles/web/node_modules/@dsh-so/dsh-code-security/preset ~/.dsh/.agent-presets/dsh-security
```

---

## 使用

### 方式一：安全审计模式会话（深入审计）

<img src="assets/安全审计-安全审计模式.jpg" alt="安全审计模式" width="720">

新建会话选择该预设，然后即可要求整仓扫描、diff 扫描、发现甄别、威胁建模、加固建议……
5 个 `dsh_security_*` 工具在严格护栏下执行 `@openai/codex-security` CLI（字面量参数引用、
工作目录约束、子命令白名单、超时上限）。

### 方式二：门禁自动审计（进程级）

<img src="assets/安全审计主界面.jpg" alt="安全审计主界面" width="720">

<img src="assets/安全审计-审计报告摘要.jpg" alt="审计报告摘要" width="720">

<img src="assets/安全审计-风险审计详情.jpg" alt="风险审计详情" width="720">

---

## 安全设计（要点）

- **默认零认证**：两条路径都使用宿主 `llm` 服务（同会话模型路由），无需外部 API key；可选
  `engine: 'cli'` 委托官方扫描器（需其自身认证）。
- **Fail-closed 载荷完整性**：bundled 载荷带 107 条 SHA-256 清单，任一失配即禁用工具而非加载。
- **路径围栏**：scan/findings 目标必须经符号链接规范化后落在会话工作目录内；拒绝 `file://` 与远程
  URL；绝对路径默认不暴露（`dsh_security_resources` 返回无路径虚拟清单）。
- **注入安全的 CLI 调用**：字面量参数引用、管理员级 `cliCommand` 字符白名单、子命令白名单、
  5 分钟前台超时上限。
- **甄别记忆**：audit-baseline 跨轮次抑制已复核误报。
- **无障碍面板**：双语 UI 跟随 DSH 主题令牌；全部状态胶囊达 WCAG AA 对比度。

完整分析见 [docs/gate.zh.md](docs/gate.zh.md)。

---

## 卸载

两条反向命令：

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

> 旧版（双包 / 脚本安装）残留清理：`dsh plugin --profile web remove dsh-security-gate dsh-security-tools`；旧状态目录 `<DSH_HOME>/dsh-security`、旧缓存 `<DSH_HOME>/cache/dsh-code-security` 可手动删除。

---

## 项目结构

```
dsh-code-security/
├── index.js                  # 安全门禁宿主插件（零依赖 cordis 插件，行 id: dsh-security-gate）
├── client.js                 # 设置页「安全审计」面板（双语）
├── audit-baseline.json       # 历轮审计甄别记忆
├── cordis.patch.yml          # bundle 补丁（dsh plugin add 自动挂载）
├── preset/                   # 「安全审计模式」预设树
│   ├── agent.cordis.yml      #   预设组合（standard + dsh-security-tools 行）
│   ├── preset.yml            #   预设元数据
│   ├── skills/dsh-security/  #   DSH 适配入口技能
│   ├── bundled/              #   上游载荷拷贝（技能/references/schemas/scripts/mcp）
│   └── plugins/dsh-security/index.js  # 5 个 dsh_security_* 工具
├── docs/                     # gate.zh/en.md 门禁详细文档
├── assets/                   # README 配图
└── README.md / README.zh.md
```

---

## 开发与发布

自 0.2.0 起为单一 npm 包（Apache-2.0）：一个工件同时携带门禁宿主插件、设置面板、「安全审计
模式」预设与完整 bundled 载荷（107 文件，包内完整性校验照常通过）。`package.json` 声明
`dsh.bundle.patch`，`dsh plugin add` 自动把它追加进 profile bundles 层栈；预设仍按平台规范
放入 `~/.dsh/.agent-presets/`（即上方第 2 步）。

旧包 `dsh-security-gate` / `dsh-security-tools` 已退役：卸载旧包后加装本包即完成迁移。

---

## 许可证与命名

- 本项目结构/封装代码：Apache-2.0。
- `preset/bundled/` 内容版权归 OpenAI，许可证 Apache-2.0，来源
  [openai/codex-security](https://github.com/openai/codex-security)。

<div align="right">
  <img src="assets/dshso-logo.svg" width="22" height="22" alt="dsh.so" style="vertical-align: middle">&nbsp;
  <b>dsh-code-security</b> · © 2026 <a href='https://dsh.so'>dsh.so</a> · Apache-2.0
</div>
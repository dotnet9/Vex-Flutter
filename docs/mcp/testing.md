# MCP Inspector 与测试验证

## 验证记录

2026-10-18，在 Windows 上使用 **官方 `@modelcontextprotocol/inspector` 2.11.0、Node 25.2.1**，通过它的正式 launcher `--cli` 入口完成：

- 协议初始化、工具发现及 `tools/list --strict` 参数模式检查。
- 全部 35 个工具的真实外部 HTTP 调用，检查返回值及正文/章节/界面状态。
- 双补丁修改、CRLF/表情文本、统一撤销重做、保存和文件打开。

测试启动真实 Vex `WorkspaceMcp` 与 HTTP 服务，文件和凭据采用隔离的测试替身，使用临时令牌，不读取个人笔记。**这不是已安装发行版与所有客户端/系统的完整验收**，也不是系统凭据库或真机输入法的验证。

另以 Windows 原生 Flutter 程序执行 `integration_test/mcp_native_test.dart`，使用独立临时凭据键验证平台安全存储写入、重建仓库后的读取、令牌轮换、旧令牌拒绝以及停止监听；不读写用户的正式 MCP 令牌。这补充了 Windows 系统凭据验证，但不替代其他系统或图形界面的人工验收。

拒绝确认、越界路径、过期修改、请求体上限、错误参数和关闭竞态由仓库 HTTP/业务回归测试验证。Inspector 在本机 Node 24/25 下遇到显式失败退出时，曾在已经输出错误后触发 libuv 断言；因此不把该异常退出计为 Inspector 负向用例通过。直接运行内部 `clients/cli/build/index.js` 还会在成功退出时碰到此问题，使用官方 launcher 即可完成成功路径测试。

## 图形界面试验

先用副本文档开启 Vex MCP 服务，保留修改确认，再运行：

```powershell
$env:MCP_INSPECTOR_SECRET_STORE = 'memory'
npx --yes @modelcontextprotocol/inspector@2.11.0
```

Node 需符合 Inspector 要求（2.11.0 要求至少 22.19.0）。该命令会下载官方 npm 工具；首次运行需要联网。按终端显示的本机链接打开 Inspector，不公开它的会话密钥。

选择 Streamable HTTP，填写 Vex 的本机 URL，并在请求头中填 `Authorization: Bearer <Vex访问令牌>`。通过 Inspector 本地代理连接；不要关闭 Vex 的 Origin 检查。

建议按顺序检查：

1. Connect 后查看服务器名称、协商版本与 tools 能力。
2. List Tools，先执行 `vex_get_capabilities`、`vex_get_document`、`vex_get_outline`。
3. 用当前 ID 与 revision 发起一次小范围 `vex_apply_edits`，在 Vex 确认后检查正文。
4. 执行 `vex_undo`，确认原文恢复。
5. 在测试副本中检查拒绝确认、过期版本、目录外文件拒绝；不要用真实私密文件作测试。
6. 关闭 Vex 服务，确认客户端无法继续调用，测试结束后清除客户端配置、剪贴板并轮换测试令牌。

Inspector 自身可能保存配置和密钥；`MCP_INSPECTOR_SECRET_STORE=memory` 让该次进程的秘密只驻留内存，不替代对配置文件、截图和终端历史的检查。

## CLI 连接实际应用

下面为 PowerShell 用法。交互读取令牌避免将真实值直接写进命令历史；但请求头仍可能在本机子进程参数中可见，建议仅用临时测试令牌。

```powershell
$env:MCP_INSPECTOR_SECRET_STORE = 'memory'
$secret = Read-Host 'Vex 访问令牌' -AsSecureString
$token = [Net.NetworkCredential]::new('', $secret).Password

try {
  npx --yes @modelcontextprotocol/inspector@2.11.0 --cli `
    --server-url http://127.0.0.1:17891/mcp/ --transport http `
    --header "Authorization: Bearer $token" `
    --method tools/list --strict --stored-auth-only --format json

  npx --yes @modelcontextprotocol/inspector@2.11.0 --cli `
    --server-url http://127.0.0.1:17891/mcp/ --transport http `
    --header "Authorization: Bearer $token" `
    --method tools/call --tool-name vex_get_document `
    --stored-auth-only --format json
} finally {
  $token = $null
  $secret.Dispose()
}
```

JSON 输出包在 `result` 下；工具业务错误会产生非零退出码。不要只看终端有没有文字，应同时检查退出码、`isError` 和实际文档内容。不要把含正文的终端输出直接粘贴到公开问题报告。

## 复现仓库自动测试

在仓库根目录运行基础回归，不依赖 npm 或真实令牌：

```powershell
flutter test apps/vex/test/mcp_test.dart `
  apps/vex/test/mcp_protocol_test.dart apps/vex/test/mcp_api_test.dart
```

官方 Inspector 集成测试为显式启用，不在普通 Flutter 单元测试中自动下载 npm 依赖：

```powershell
$toolRoot = Join-Path $env:TEMP 'vex-mcp-inspector'
npm install --prefix $toolRoot --no-save @modelcontextprotocol/inspector@2.11.0
$env:VEX_MCP_INSPECTOR_CLI = Join-Path $toolRoot 'node_modules/@modelcontextprotocol/inspector/clients/launcher/build/index.js'

try {
  flutter test apps/vex/test/mcp_inspector_test.dart --reporter expanded
} finally {
  Remove-Item Env:VEX_MCP_INSPECTOR_CLI -ErrorAction SilentlyContinue
}
```

可选 `VEX_MCP_NODE` 指向符合要求的 Node 可执行文件。测试随机分配本机端口、自动生成临时令牌并注入内存凭据，退出后停止服务；不需要改自己的 Vex 设置。测试断言覆盖到的工具集合必须等于实际工具列表，接口新增后漏测会失败；接口参考也有名称契约检查。

| 测试 | 覆盖 |
| --- | --- |
| `mcp_test.dart` | 应用内连接测试、平台开关、用户确认、修改撤销和路径边界 |
| `mcp_protocol_test.dart` | 实际 HTTP、协议协商、鉴权/Host/Origin、令牌轮换、范围、并发启停及请求大小 |
| `mcp_api_test.dart` | 接口文档契约、参数模式、UTF-16、批处理原子性、异步文档切换、凭据失败关闭 |
| `mcp_inspector_test.dart` | 官方外部客户端、strict schema、35 个工具逐一调用 |
| `integration_test/mcp_native_test.dart` | 原生系统安全存储与令牌鉴权、轮换、关闭；Windows 已验证 |

## 尚需人工验收

- [ ] 用待发布的原生 Windows 安装包完成 Inspector 图形界面确认弹窗流程。
- [ ] macOS Keychain/沙箱目录与 Linux Secret Service 的实际存取、重启与锁定失败。
- [ ] 目标编辑器/AI 客户端各自的配置、超时和错误提示；Inspector 通过不代表它们全部兼容。
- [ ] 正式发行版更换令牌后旧客户端失效，重启后令牌可用，关闭服务无残余监听。

报告问题只提供系统/版本、脱敏错误、使用的工具名与最小复现，不提供真实令牌、个人正文或整个配置目录。

# 贡献指南

感谢参与维刻 Vex。当前仍是开发版本，实际状态以 [实现与验收](docs/实现验收.md) 为准，不将浏览器原型、控件测试或 CI 构建通过视为所有平台验收完成。

## 开发环境

使用根目录 `.flutter-version` 固定的 Flutter stable 版本，以及该版本附带的 Dart。仓库采用 Pub workspaces，保留并提交根目录 `pubspec.lock`，不要为各包另建锁文件。

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-pub
```

应用入口位于 `apps/vex/lib/main.dart`。桌面在应用目录运行 `flutter run -d windows`，macOS、Linux 替换设备名称。Android 必须显式选择开发 flavor：

```powershell
cd apps/vex
flutter run --flavor preview -d <设备编号>
```

Android 工具链与签名边界见 [Android 构建](docs/Android构建.md)。不要使用 production 包名试验数据迁移，也不要提交私钥、密码、令牌、个人文档或本地路径配置。

## 代码边界

- `apps/vex` 负责应用界面、平台服务与工作流，沿用现有 View/ViewModel、Repository/Service 分层和 provider。
- `packages/vex_markdown_core` 保持纯 Dart；编辑器和导图通过 controller、callback 接入宿主，不反向依赖应用。
- Markdown 原文是唯一数据来源；修改必须保留 CRLF、Unicode、选区位置和统一撤销历史。输入法候选期间避免改写缓冲，异步操作必须验证文档及版本是否仍有效。
- 优先复用现有主题令牌、本地化、图标和控件；支持键鼠、触控、焦点、语义和减少动态效果。界面文案维护 ARB，并运行 `flutter gen-l10n`。
- 只提交与任务相关的变更，避免无关格式化、生成物或依赖升级。保留他人的未提交修改。

## 验证

在各目录运行对应测试：

| 目录 | 命令 |
| --- | --- |
| `packages/vex_markdown_core` | `dart test --coverage=coverage` |
| `packages/vex_editor` | `flutter test --no-pub --coverage` |
| `packages/vex_mindmap` | `flutter test --no-pub --coverage` |
| `apps/vex` | `flutter test --no-pub --coverage` |
| 仓库根目录 | `python -m unittest discover -s scripts/tests -v` |

修改 Dart 后运行 `dart format`，提交前使用 `git diff --check`。CI 对已跟踪的 Dart 文件执行只读格式检查，并保存覆盖率文件；测试数量和覆盖率都不是视觉、性能或原生兼容性的验收结果。

原型无需第三方 Node 依赖。运行 `design/scripts/verify*.cjs` 下的全部脚本；脚本检查数据与交互契约，不是浏览器像素对比。界面改动应附同尺寸、同字体、同场景的原型及原生截图，注明主题、缩放、语言与平台；未经完整对照不得宣称达到 98%。

原生集成测试位于 `apps/vex/integration_test`。例如在应用目录执行：

```powershell
flutter test --no-pub integration_test/typing_test.dart -d windows
flutter test integration_test/touch_selection_test.dart --flavor preview -d <Android设备编号>
```

合成中文候选、模拟触控和窄窗口检查不能替代系统输入法、物理设备及软键盘验收。请明确列出未测项目。

## 资源与发布

品牌源为根目录 `logo.svg`、`logo.png`、`logo.ico`，通过 `python scripts/sync_brand_assets.py` 同步，需要 Pillow。不要手动修改派生图标。原型与应用的内置 Markdown、版本信息及第三方许可通过现有同步脚本维护。

安装包与标签流程见 [安装包与自动发布](docs/安装包与自动发布.md)。iOS IPA、HarmonyOS HAP 在签名与适配条件具备前暂缓发布，不使用未签名文件或便携压缩包代替安装包，不绕过发布校验。

提交和 PR 应说明修改目的、验证命令、实际测试平台及剩余限制。安全问题按照 [安全政策](SECURITY.md) 私下报告，不附在公开 Issue 或 PR 中。

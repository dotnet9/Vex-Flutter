# Android 构建与预览

使用 Flutter 3.47.7 stable、Android SDK 36、NDK 28.2、JDK 21。Gradle 使用仓库 Wrapper。首次执行 `flutter doctor -v` 检查本机工具链。

```powershell
cd apps/texweft
flutter pub get
flutter run --flavor preview -d <设备编号>
flutter test integration_test/mobile_workspace_test.dart --flavor preview -d <设备编号>
flutter build apk --release --flavor preview --split-per-abi --target-platform android-arm64,android-x64
```

Android 命令显式指定 preview，包名 `com.codewf.texweft.preview`，应用名带“预览”，使用开发证书。应用不设置全局默认 flavor，避免影响桌面构建。ARM64 APK 用于通常的 Android 手机；x86_64 APK 用于对应模拟器。它们是可安装的开发预览包，不能作为正式签名发行版本。

production 使用包名 `com.codewf.texweft`，签名读取本机忽略的 `android/key.properties`：`storeFile`（相对 android 目录）、`storePassword`、`keyAlias`、`keyPassword`。正式构建必须配置发行证书，不回退到开发签名。证书及密码不得提交到仓库。

```powershell
flutter build apk --release --flavor production --split-per-abi --target-platform android-arm64
```

Windows 上仓库与 Pub 缓存位于不同盘符时，Kotlin 2.4 增量缓存不能正确处理相对路径，因此项目暂时禁用 Kotlin 增量编译，并使用进程内编译策略。若本机 JDK 的 Unix domain socket 临时路径过长，可为当前终端设置较短的 `-Djdk.net.unixdomain.tmpdir`，无需改动系统设置。

已在 Android 14 / API 34 x86_64 模拟器上通过原生工作区集成测试，并安装启动 release 正式入口预览 APK。尚未进行 Android 真机、完整输入法、系统文件提供程序与所有导出格式验收。

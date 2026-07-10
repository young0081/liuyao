# 玄机 · 六爻卦象

一款玄学卜卦应用,采用 Flutter 构建,同时支持 Windows 桌面与 Android/iOS 移动端。
核心是京房纳甲六爻装卦引擎:摇卦或手排后,自动完成排盘并给出参考性解读。
桌面端为无边框自绘窗口,移动端为页签式触摸界面,两端共用同一套卦象引擎。

## 功能

- **无边框窗口**：使用 `window_manager` 隐藏系统标题栏,自绘标题栏支持拖拽、最大化、关闭。
  移动端自动切换为普通顶栏 + 「起卦 / 排盘 / 断卦」三页签的触摸布局。
- **起卦**：三钱摇卦(密码学安全随机)与手动排爻两种方式;可填写所问之事。
- **京房纳甲引擎**：由六爻自动生成
  - 六十四卦名(依上下经卦查表)
  - 八宫归属与世应(本宫 / 一世 ~ 五世 / 游魂 / 归魂)
  - 纳甲地支、五行、六亲(父母 / 兄弟 / 子孙 / 妻财 / 官鬼)
  - 六神(依日干起青龙)
  - 伏神(卦中缺失六亲从本宫纯卦补出)
  - 动爻与变卦
- **干支历**：由公历推算年、月建、日干支及旬空。
- **断卦要点**：世应生克、动爻去向、旬空提示,均为参考静思,不作宿命断言。
- **AI 解卦**：可接入第三方 OpenAI 兼容供应商(OpenAI / DeepSeek / Moonshot / 智谱 / 通义 / 本地 Ollama 等),
  将排盘数据整理为提示词发送给模型,返回结构化参详。标题栏齿轮进入配置界面,填写接口地址、
  密钥、模型与温度,并支持一键测试连通性。密钥仅以 `shared_preferences` 存于本机,不会明文回显。
- **位置与时事参照**：用户主动启用并授权后,读取前台位置,获取行政区、实时天气和近期公开事件,
  将当次环境快照随卦例保存并加入 AI 提示词。外部资料只作辅助取象,不改变六爻随机值和排盘结果。
  AI 输出按核心判断、过去印证、现在局势、未来演变与行动建议组织,并明确区分卦理、公开资料和综合推断。
- **动效**：面板结果淡入上移、状态切换过渡,AI 等待时以旋转太极加载动画呈现。
- **跨平台一致**：桌面/移动共用 `lib/domain` 卦象引擎,仅界面层按屏幕宽度自适应;
  排盘六爻表在窄屏下可横向滚动,保证六神、伏神、纳甲、世应、变爻、旬空各列完整可见。
- **应用图标**：太极 + 八卦 + 鎏金深色主题图标,通过 `flutter_launcher_icons` 生成
  Windows `.ico` 与 Android/iOS 各密度图标。

## 技术选型

| 关注点 | 选择 |
| --- | --- |
| 框架 | Flutter 3.44 (Windows / Android / iOS) |
| 无边框(桌面) | `window_manager`(仅桌面按平台条件启用) |
| 状态管理 | `flutter_riverpod` (`StateNotifier`) |
| AI 调用 | `http`(OpenAI 兼容 `/chat/completions`) |
| 前台定位 | `geolocator`(用户主动授权) |
| 地区上下文 | BigDataCloud / Open-Meteo / GDELT / Google News RSS / Bing News RSS / 60s 日报 |
| 配置持久化 | `shared_preferences` |
| 图标生成 | `flutter_launcher_icons` |
| 字体 | `google_fonts`(思源宋体) |
| 主题 | 深墨底 + 鎏金 + 朱砂的自定义暗色主题 |

## 目录结构

```
lib/
  domain/            核心领域逻辑(与 UI 解耦,含单元测试)
    five_element.dart      五行 / 天干 / 地支
    trigram.dart           八卦纳甲参数表
    hexagram_names.dart    六十四卦名表
    models.dart            六亲 / 六神 / 爻 / 卦模型
    hexagram_engine.dart   八宫装卦引擎(世应/六亲/伏神/六神)
    ganzhi_calendar.dart   干支历
    casting.dart           三钱起卦 + 变卦
    interpreter.dart       解读要点生成
    ai_provider.dart       AI 供应商配置模型 + OpenAI 兼容调用
    location_context.dart  当次位置、天气、地区资料与近期事件快照
  services/location_context_service.dart  定位授权与联网环境资料聚合
  state/app_state.dart     Riverpod 控制器与状态
  state/ai_state.dart      AI 配置 / 调用状态(含持久化)
  state/location_state.dart  位置授权、刷新与失败降级状态
  ui/                      无边框界面(标题栏 / 起卦 / 排盘 / 断卦)
                           widgets/taiji_loader.dart   太极加载 + 淡入动画
                           widgets/ai_settings_dialog.dart  AI 供应商配置对话框
  ui/platform.dart         平台判断(桌面 / 移动)
  main.dart                入口(初始化无边框窗口)
test/engine_test.dart      引擎单元测试
test/ai_provider_test.dart AI 配置与提示词单元测试
test/location_context_test.dart 位置、天气、事件解析与降级测试
```

## 位置数据与隐私

- 应用不会在启动时直接弹出定位权限；只有用户在起卦页开启「位置与时事参照」后才会申请前台位置权限。
- 坐标用于请求 BigDataCloud 的行政区资料和 Open-Meteo 的实时天气；新闻检索只发送城市、区县名称,
  不会把所问内容发送给地图、天气或新闻服务。
- 保存到历史卦例的坐标限制为四位小数,并附带定位精度、采集时间、来源和未取得项。
- 关闭位置参照后不再发起新请求；既有卦例中的快照仍随该卦保留,可通过清除历史删除。
- GDELT 与新闻 RSS 可能因网络、地区或限流不可用。检索均不可用时会降级到 60s 日报并明确标为
  「本地匹配」或「全国背景」；全部失败则标记缺失,不会生成虚假的近期事件。

## 运行与构建

```powershell
flutter pub get
flutter test          # 运行引擎单元测试
flutter run -d windows # 开发运行
```

### 构建 Windows 发行版

Flutter 的 MSVC/CMake 工具链无法读取含非 ASCII 字符的项目路径(本目录含中文)。
因此提供了构建脚本,会先复制到纯 ASCII 临时目录再构建并把产物拷回:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_windows.ps1
```

产物位于 `build\windows\x64\runner\Release\liuyao.exe`。

### 构建 Windows 正式安装程序

安装程序基于自定义 Flutter 安装器界面,带 GUI 向导、圆角无边框窗口、应用图标、开始菜单/桌面快捷方式。
它会检测本机已安装的任意版本,默认路径指向旧安装目录;若安装包版本高于已装版本会显示为更新,
低于已装版本会显示为回退,相同版本显示为重新安装。
安装程序产物是单个 `liuyao-setup-<version>.exe`;双击后第一屏即为 Flutter GUI 安装界面,
不会出现 zip/7z 解压器窗口。为满足单文件分发,安装器内部会临时展开 Flutter 运行所需文件,
这个过程静默完成,用户可见界面仍是自定义安装器。

```powershell
powershell -ExecutionPolicy Bypass -File .\build_installer.ps1
powershell -ExecutionPolicy Bypass -File .\build_installer.ps1 -SkipAppBuild # 复用现有 Windows Release 产物
```

产物位于 `dist\liuyao-setup-<version>.exe`。

### 构建 Android 发行版

同样地,Android(Gradle/AGP)工具链无法处理含非 ASCII 字符的项目路径。
提供了对应脚本,先复制到纯 ASCII 临时目录再构建并把 APK 拷回:

```powershell
powershell -ExecutionPolicy Bypass -File .\build_android.ps1          # release 包
powershell -ExecutionPolicy Bypass -File .\build_android.ps1 -Debug   # debug 包
```

脚本会保留 Flutter 默认 APK,并额外输出带版本与构建类型的安装包,例如
`build\app\outputs\flutter-apk\liuyao-v1.1.0-6-android-release.apk`。

> 说明:当前 release 使用 debug 签名以便直接装机测试;正式分发前请在
> `android/app/build.gradle.kts` 配置你自己的 keystore 签名。

### 重新生成应用图标

图标源图为 `assets/icon/app_icon.png`(由 `tools/make_icon.py` 以纯几何方式绘制)。
如需重绘或调整,可执行:

```powershell
python tools\make_icon.py           # 重绘 PNG 与 .ico
dart run flutter_launcher_icons     # 按 pubspec 配置写入 Windows 图标
```

> 说明:卦象解读仅供参照静思,趋吉避凶终由己心。

## 许可

本项目以 [MIT License](LICENSE) 开源。

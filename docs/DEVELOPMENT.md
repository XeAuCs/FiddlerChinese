# 开发与测试

需要 Windows、Windows PowerShell 5.1 及本机安装的 Fiddler Classic。使用 Windows 自带的 .NET Framework C# 编译器，无需另装 SDK。仓库不分发 Fiddler.exe 或 Telerik 依赖。

在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1 -FiddlerPath 'E:\Fiddler'
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test.ps1 -FiddlerPath 'E:\Fiddler'
```

标准安装可省略 FiddlerPath，便携版需指定实际目录。构建输出位于 bin；测试结果位于 test-output。统一测试入口依次验证真实控件、安装器和生成的 Release 包。

只检查安装器（不需要 Fiddler 或已编译 DLL）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Installer.ps1
```

## 代码职责

- src/Plugin.cs：实现 IFiddlerExtension，添加中文界面菜单及加载/卸载逻辑。
- src/Localization.cs：词典匹配、控件遍历、动态更新、悬浮提示、重新加载和英文恢复。
- installer/Installer.Common.ps1：共享的 Fiddler 路径识别；安装器和构建脚本使用同一份实现。
- tests/Tests.cs：词典与真实 WinForms/Fiddler 控件回归。
- tests/Test-Installer.ps1：模拟下载、复制故障、备份与还原；测试模拟状态只留在独立测试进程。
- tests/Test-Release.ps1：检查生成的 ZIP 布局、校验文件及实际安装/还原夹具。

插件只改变 UI 显示。输入框、脚本、请求响应正文、会话数据不翻译；固定下拉框仅改变显示，保持原始选项和选择值。不会接收请求/响应回调或修改代理、证书设置。

本次目录整理未改变插件运行逻辑。移除了重复译文、已编译 DLL 及旧源码目录的安装回退分支，译文由 translations 单独维护，发布包按需生成。
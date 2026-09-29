# Fiddler 中文界面插件 2.0

已验证版本：Fiddler Classic 6.0.20261.7291 / Windows / .NET Framework。

本次交付是独立重写的插件。保留旧版“原文==译文”格式，增加上下文匹配、动态控件处理和可恢复英文。无需替换 Fiddler.exe。

## 使用

### 一条命令安装

先安装 Fiddler Classic 并关闭它，然后在 Windows PowerShell 中粘贴以下命令。无需安装 Git、开发工具或手动解压。

项目仓库：[XeAuCs/FiddlerChinese](https://github.com/XeAuCs/FiddlerChinese)。命令从本仓库下载最新正式版。

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/XeAuCs/FiddlerChinese/main/install-online.ps1?v=2').Content)) -Repository 'XeAuCs/FiddlerChinese'
```

命令会通过 GitHub 的公开 Release 下载链接取得最新正式版并校验安装包，不查询 GitHub API，也无需 GitHub 登录或令牌。随后自动寻找 Fiddler Classic，备份已有汉化文件并安装插件。Fiddler 正在运行时会停止安装并提示关闭，不会强制结束进程。安装到受保护的 Program Files 目录可能需要在管理员 PowerShell 中运行。

便携版或有多个安装目录时，在同一条命令末尾加上 `-FiddlerPath 'D:\Fiddler'`。需要固定版本时再加 `-Version 'v2.0.0'`。

### 下载后双击安装

也可以将 Release 安装包完整解压，关闭 Fiddler，然后双击“一键安装.cmd”。安装器会自动识别安装目录。看到安装成功后重新打开 Fiddler，即可启用中文。

请保留“一键安装.cmd”、Install.ps1、Installer.Common.ps1 和 Scripts 文件夹的相对位置，不要只复制安装入口。安装到其他目录时，可把包含 Fiddler.exe 的文件夹拖到“一键安装.cmd”上。

首次启动：Fiddler 6 会对新扩展执行信任检查。此 DLL 在本机编译，未使用商业代码签名。若出现关于 Scripts/FiddlerChinese.dll 的提示，请核对路径和本包后自行决定是否允许。插件不能在被允许之前显示中文。安装脚本不会更改信任设置。

工具 → 中文界面：可取消“启用中文界面”临时恢复英文，或选择“重新加载翻译表”。启用状态不持久化，下次启动默认中文。

安装文件：
- Scripts/FiddlerChinese.dll
- Scripts/FiddlerChinese/FiddlerTexts.txt
- Scripts/FiddlerChinese/FiddlerTexts.context.txt

要撤销安装：下载并解压 Release 安装包，关闭 Fiddler，在该文件夹打开 PowerShell，运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\Restore.ps1`。便携版可追加 `-FiddlerPath 'D:\Fiddler'`。它按安装记录恢复上一次安装前的文件，同时备份当前翻译，不删除其他插件或整个目录。安装备份位于 Fiddler 目录下的 localization-backups。重复安装会保留多层备份，每次还原回退一层。

发布者操作见 [PUBLISH.md](PUBLISH.md)。普通使用者只需上面的一条安装命令。首次启用时，Fiddler 本身的扩展信任提示仍可能需要点击确认。

## 本版覆盖

- 主菜单、规则/工具/会话右键菜单、会话列表标题。
- 主窗口中各页签的标准标签/按钮；Filters 的标签和固定下拉项。
- 常规、HTTPS、连接、上游代理、外观、脚本、扩展、性能、工具设置页中的已收录文字。
- 后续打开的 WinForms 窗口，以及新增/更新的标准文字控件。
- 工具栏按钮、已发现的 ToolTip 和菜单弹出时新增的项目。
- 补充 21 条工具栏悬浮提示，包括 WinConfig、重发、流式传输、解码、进程筛选等。已有安装仅更新译文表后，点击“工具 → 中文界面 → 重新加载翻译表”即可生效。

技术名如 HTTP、JSON、URL、TLS 保留；未收录的文字保留原文。自绘控件、原生系统弹窗、复杂富文本内容、某些动态组合文字仍可能显示英文。不是全量汉化。

## 数据保护和边界

插件仅实现 IFiddlerExtension，不接收请求/响应回调，不更改代理、证书、网络或授权设置。

文本框（包括只读文本框）、脚本编辑器、请求/响应正文、列表行、树节点、可编辑下拉框内容不翻译。固定下拉框仅通过 Format 事件改变显示，不修改 Items、SelectedIndex 或绑定数据。

译文保持菜单助记键和快捷键说明。对固定尺寸控件保守处理，不任意移动布局；长文字可通过悬浮提示查看。个别 DPI 或第三方控件仍需实际目视检查。

## 翻译维护

文件为 UTF-8，一行一条：
```
File==文件
```

换行写成 [LF]，制表符写成 [TAB]。// 开头是注释。重复原文以后面的条目为准，空译文不应用。不存在精确条目时，可去除助记键和快捷键说明匹配无歧义的条目；不会模糊翻译或在线翻译。

上下文表优先级更高，格式：
```
Fiddler.frmOptions|btnCancel|Text|Cancel==取消
```

字段依次为完整窗体/插件 UserControl 类型名、控件 Name、属性名、完整原文。常用属性：Text、ToolTip、ToolTipText、CueText、Item。列表列标题使用 列表Name/列序号。

默认不收集未知文字。需要补词时，在 Scripts/FiddlerChinese 内创建 collect-missing.enabled 空文件并重新加载翻译表。新词单独写入 FiddlerTexts.missing.txt，不回写已审核的翻译。采集排除输入框、URL 和路径等常见数据，但界面动态标签仍可能含个人信息，请在分享采集文件前检查。删除开关文件并重新加载即可停止采集。

错误和启动记录保存在同目录 FiddlerChinese.log；日志只保留有限大小。

## 源码和验证

- Localization.cs：词典、控件遍历、动态更新、英文恢复。
- Plugin.cs：Fiddler 插件入口和中文菜单。
- build.ps1：使用 Windows 自带 .NET Framework C# 编译器。
- Tests.cs / test.ps1：隔离回归测试，使用本机真实 Fiddler 和 SimpleFilter 控件。
- test-output：本地运行测试时生成的记录和离屏布局预览，不随仓库分发。

该插件采用运行时 UI 属性替换。Fiddler 更新后界面名称和结构可能变化，需重新验证。

当前验证结果见 VALIDATION.md。已在实际运行的 Fiddler 中确认插件加载，并通过其 8888 端口完成本机 POST 转发及响应一致性测试。HTTPS 解密、高 DPI 和全部第三方扩展界面没有逐项测试。

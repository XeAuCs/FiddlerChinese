# 发布到 GitHub

本项目采用“仓库保存安装入口，Release 提供编译后的插件”的方式。上传源码后还需要发布一次 Release，使用者才能通过一条命令下载和安装；仅上传源码不足以启用在线安装。

## 首次发布

1. 本项目仓库为 [XeAuCs/FiddlerChinese](https://github.com/XeAuCs/FiddlerChinese)，默认分支为 `main`。
2. 上传整理好的项目目录内容。`install-online.ps1` 必须位于仓库根目录，不能多套一层文件夹。项目自带 `package/Scripts/FiddlerChinese.dll`，使用者不需要自己编译。
3. README 已配置本仓库地址。发布到其他仓库时，将命令中的两个 `XeAuCs/FiddlerChinese` 都替换成新的 `用户名/仓库名`；默认分支不是 `main` 时，也要更改原始文件链接。
4. 在项目目录运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\New-Release.ps1`。生成 `release/FiddlerChinese.zip` 和 `release/FiddlerChinese.zip.sha256`。
5. 在 GitHub 的 Releases 页面创建一个正式发布，例如标签 `v2.0.0`，上传这两个文件并发布。不要使用 GitHub 自动生成的 Source code ZIP 代替安装包。保持附件名称不变，安装器依赖这两个名称。
6. 把 README 中的一条命令提供给使用者。默认安装最新正式版；草稿和预发布版不会被默认选中。

用户命令模板（Windows PowerShell 5.1 或 PowerShell 7）：

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/XeAuCs/FiddlerChinese/main/install-online.ps1').Content)) -Repository 'XeAuCs/FiddlerChinese'
```

## 更新插件或译文

- 只修改译文：修改根目录的 FiddlerTexts.txt / FiddlerTexts.context.txt，然后重新运行 New-Release.ps1。
- 修改插件源码：在安装了 Fiddler Classic 的 Windows 上运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -FiddlerPath 'D:\Fiddler'`，再运行 `powershell -NoProfile -ExecutionPolicy Bypass -File .\New-Release.ps1 -PluginPath .\bin\FiddlerChinese.dll`。
- 以新标签发布新的 ZIP 和对应 SHA-256 文件。使用者重新运行原来的安装命令即可更新，原有译文会先备份。
- SHA-256 用来检查下载文件是否与发布包一致，并非开发者签名。安装命令执行的脚本与插件来自指定仓库，发布者应审核自己上传的产物。

## 验证与范围

`Test-Installer.ps1` 在临时夹具中验证目录识别、运行中拒绝安装、备份/还原、失败回滚、校验失败拦截、解压路径检查和带空格路径。在线部分用模拟 GitHub 响应测试；首次公开发布后仍需实际运行安装命令，确认公开下载链路。

该项目不包含 Fiddler.exe、Telerik 官方依赖、抓包数据或反编译产物。编译时引用用户本机安装的 Fiddler.exe；安装器不改动它。

实现依据：[GitHub Release API](https://docs.github.com/en/rest/releases/releases)、[发布文件下载链接](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)、[PowerShell 下载接口](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/invoke-webrequest?view=powershell-5.1)。

# 发布到 GitHub

仓库：[XeAuCs/FiddlerChinese](https://github.com/XeAuCs/FiddlerChinese)，默认分支 main。根目录 install-online.ps1 的地址保持稳定。

## 生成安装包

在仓库根目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-Release.ps1 -FiddlerPath 'E:\Fiddler'
```

默认先从 src 编译插件，再从 translations 读取译文，输出：

- release/FiddlerChinese.zip
- release/FiddlerChinese.zip.sha256

标准安装可省略 FiddlerPath。需要使用自己已构建的 DLL 时，可显式传入 `-PluginPath .\bin\FiddlerChinese.dll`。

源码目录与发行包目录不同。发行包仍在根目录保留 Install.ps1、Restore.ps1、Installer.Common.ps1 和“一键安装.cmd”，并包含 Scripts/FiddlerChinese.dll 与译文，因此现有在线和离线安装方式不变。DLL 和 ZIP 不提交到源码仓库。

## 发布

创建新的正式 Release 并上传两个输出文件，附件名称必须保持不变。不要使用 GitHub 自动生成的 Source code ZIP 代替安装包。草稿和预发布版本不会被默认选中。

用户按 README 执行安装命令即可使用最新正式版；`-Version 'v2.0.0'` 可固定版本。若两个下载之间恰好更换了最新发布，校验不一致会终止安装，用户可以重试或指定版本。

修改译文时只编辑 translations，然后重新生成安装包；修改源码后默认打包流程会重新编译。不要手工维护安装包内的副本。

SHA-256 用来校验下载文件与发布包一致，不是开发者签名。在线安装通过公开附件直链完成，不依赖 GitHub API。发布后应检查公开下载及校验，并运行测试确认安装包结构。

参考：[GitHub 发布文件链接](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)。
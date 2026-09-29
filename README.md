# Fiddler 中文界面

Fiddler Classic 中文汉化插件，包含 372 条译文，覆盖常用菜单、设置、过滤器及工具栏悬浮提示。支持切换英文和重新加载译文，不修改 Fiddler.exe 或抓包内容。

已验证：Windows / Fiddler Classic 6.0.20261.7291。未收录的文字保留英文。

## 安装

关闭 Fiddler，在 PowerShell 中运行：

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/XeAuCs/FiddlerChinese/main/installer/install-online.ps1').Content)) -Repository 'XeAuCs/FiddlerChinese'
```

安装器通过公开 Release 链接下载文件，不查询 GitHub API，也无需登录 GitHub。自动识别安装目录，校验下载并安装文件，相同文件自动跳过；不会强制关闭正在运行的 Fiddler。

- 便携版或多个安装位置：在命令末尾追加 `-FiddlerPath 'E:\Fiddler'`。
- 固定版本：追加 `-Version 'v2.0.1'`。
- 安装到 Program Files 等受保护目录时，可能需要管理员 PowerShell。

也可以从 [Releases](https://github.com/XeAuCs/FiddlerChinese/releases/latest) 下载 **FiddlerChinese.zip**，完整解压后双击“一键安装.cmd”。请下载发布附件，不要用 Source code ZIP 安装。

首次启动时，Fiddler 可能要求确认加载 `FiddlerChinese.dll`。本插件未经商业代码签名，安装器不会绕过扩展信任检查。

从 v2.0.1 起不再自动备份、不创建 localization-backups 或安装历史。更新会直接覆盖本插件及译文；需要保留的自定义译文请自行保存。

## 使用与卸载

安装后打开 Fiddler，通过 **工具 → 中文界面** 切换语言或重新加载翻译表。下次启动默认启用中文。

编辑安装目录中的 `Scripts/FiddlerChinese/FiddlerTexts.txt` 可补充译文，随后重新加载。格式和上下文用法见 [翻译维护](docs/TRANSLATIONS.md)。

要卸载：关闭 Fiddler，在解压后的安装包目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

便携版可追加 `-FiddlerPath 'E:\Fiddler'`。卸载会移除本插件和两份译文，不会移除其他插件。

## 项目结构

| 目录 | 用途 |
| --- | --- |
| `src/` | 插件入口与汉化逻辑 |
| `translations/` | 唯一维护的译文表 |
| `installer/` | 在线安装、离线安装、卸载和双击入口 |
| `scripts/` | 构建、测试、打包入口 |
| `tests/` | 插件、安装器和发布包测试 |
| `docs/` | 开发、发布和验证说明 |

公开安装入口位于 `installer/install-online.ps1`，请使用上面的新命令；旧的根目录脚本链接已移除。编译 DLL、安装包和测试输出由脚本生成，不放进源码目录；使用者直接下载 Release 即可。

[开发与测试](docs/DEVELOPMENT.md) · [发布步骤](docs/PUBLISH.md) · [验证范围](docs/VALIDATION.md)
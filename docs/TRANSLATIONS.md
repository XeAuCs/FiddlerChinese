# 翻译维护

源码译文仅保存在 translations/FiddlerTexts.txt 和 translations/FiddlerTexts.context.txt。打包脚本自动复制到发布包，无需再同步 package/Scripts 副本。

用户安装后的文件位于 Fiddler 的 Scripts/FiddlerChinese 目录。修改后点击“工具 → 中文界面 → 重新加载翻译表”，无需重新编译 DLL。

## 格式

文件为 UTF-8，一行一条：

```text
File==文件
```

换行写成 [LF]，制表符写成 [TAB]。// 开头是注释。重复原文以后面的条目为准，空译文不应用。精确匹配失败时，可去除助记键和快捷键说明，匹配无歧义条目；不会在线翻译或模糊替换。

上下文表优先级更高：

```text
Fiddler.frmOptions|btnCancel|Text|Cancel==取消
```

字段是完整窗体或 UserControl 类型、控件 Name、属性名、完整原文。属性包括 Text、ToolTip、ToolTipText、CueText、Item。列表列标题使用“列表Name/列序号”。

## 未翻译文字

默认不采集。在已安装的 Scripts/FiddlerChinese 中创建 collect-missing.enabled 空文件并重新加载，可收集未翻译的界面文字。结果单独写入 FiddlerTexts.missing.txt，不覆盖已有译文。删除开关并重新加载即可停止。

采集排除输入框、URL、路径等常见数据，但动态标签仍可能包含个人信息，分享前请检查。错误日志位于同目录 FiddlerChinese.log，大小受限制。

## 覆盖范围

常用菜单、设置页、Filters 标准控件、固定下拉项、工具栏悬浮提示及后续新增的标准控件。HTTP、JSON、URL 等技术名保留。自绘控件、原生弹窗、复杂富文本和部分动态组合文字仍可能是英文。

固定尺寸控件不会被任意移动；长文字可通过悬浮提示查看。不同 DPI 与第三方界面需单独检查。
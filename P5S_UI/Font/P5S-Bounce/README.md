# P5S Bounce — 标准版 1.000

成品：`../P5S-Bounce-Regular.ttf`；内部字体族：`P5S Bounce`。

基于 Chewy Regular 1.001 制作，保留圆润、手绘感的原始笔形。A–Z、a–z、0–9 共 62 个字符按逐字角度表旋转；沿用 P5S Showtime 从参考字体整理的左右倾斜节奏，不是把整行统一设为斜体。正角度表示顶部向右，负角度表示顶部向左。角度表为光学设计参数，并非参考字体内存储的精确旋转数据；Chewy 原生笔画的不规则形态保留。

Chewy 本身没有 Fugaz One 的统一右斜，所以本版直接旋转，不做整体去斜。旋转后保留每字原来的最低点，标准版每侧留白限制为 25–49/1024 em，扩大字符步进容纳倾斜后的轮廓；受影响的原始负字偶距按至少 25 单位边界间隙限制。数字使用比例字宽。本轮不制作紧凑版。

其他字符的轮廓和基础字宽保持；先展开组合字再修改，避免重音字的基字自动变化。字体映射仍为原有 228 字符，不含中文；旧 hinting 已移除，实际小字号描边仍需客户端测试。

## 许可与发布

原始文件 SHA256：`7cf75ea288f82fd20badea8ab4da7a656a96a7277c170811e813b3d3d6294147`，已与 2026-10-11 下载的 [Google Fonts 原文件](https://github.com/google/fonts/tree/main/apache/chewy) 逐字节核对一致。原字体版权属于 Font Diner, Inc DBA Sideshow，设计者 Squid，采用 Apache License 2.0。

本修改版沿用 Apache 2.0，可随 P5S 插件上传、打包分发。发布时必须随字体保留本目录的 `LICENSE.txt` 和 `NOTICE.txt`，保留字体内版权、归属与修改说明；建议整个说明目录一起打包。修改说明已经写入 TTF 的 name ID 10。P5S 专用名称和设计不代表获得原字体的独占版权，也不能声称原作者为修改版背书。

`LICENSE.txt` 原文来自 https://raw.githubusercontent.com/google/fonts/main/apache/chewy/LICENSE.txt 。Google Fonts 对应目录未附单独 NOTICE，本目录 NOTICE 是本次整理的来源与修改声明。

此许可仅覆盖这款字体及其 Chewy 来源，不覆盖插件中其他图片、声音或字体。`Font/微软雅黑粗体.ttf`、`Media/微软雅黑粗体.ttf` 都不是本修改版的一部分；未取得对应分发授权时应排除于发布包，并在发布前处理使用它们的默认配置。当前任务没有移除旧文件或修改代码。

## 复现与验证

需要 Python 与 `fonttools`；在本目录运行 `python build.py`。输入只有原始 Chewy TTF 和 `tilt-map.json`，不需要参考字体。版本校验拒绝意外的源文件；固定字体时间戳，输出摘要与逐字参数记录在 `build-report.json`。

字体尚未加入 `/p5s` 的静态清单，单纯复制文件不会自动出现新菜单项。本次交付独立字体标准版，正式服加载、HP/SP 与数字、小字号描边、重启及切换表现均待接入后验证。

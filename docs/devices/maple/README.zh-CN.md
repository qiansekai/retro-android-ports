# Sony Xperia XZ Premium G8141/G8142（`maple`）

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

![Sony Xperia XZ Premium](device.jpg)

*图片来源：[Deoma12](https://commons.wikimedia.org/wiki/File:Xperia_XZ_Premium.png)，CC BY-SA 4.0，via Wikimedia Commons。*

XZ Premium 是 Sony 2017 年的旗舰，采用 Qualcomm 的 **Snapdragon 835
（MSM8998）**：4×2.45 + 4×1.9 GHz Kryo（ARM64）+ Adreno 540，4 GB RAM，
64 GB UFS，microSD，5.5 英寸 3840×2160 HDR 面板（日常使用按 1080p /
密度 410 渲染），USB-C。它出厂搭载 **Nougat 7.1.1**；
`maple` 是单卡版 G8141，`maple_dsds` 是双卡版 G8142。我们的移植
使其运行 **KitKat 4.4.4** —— 一个 32 位、2013 年的用户空间。

## 状态

### KitKat 4.4.4 — AOSP `android-4.4.4_r2`（KTU84Q）— 启动到 UI

| 方面 | 状态 |
| --- | --- |
| 启动 | 启动到桌面（`sys.boot_completed=1`，75 个 binder 服务），所有分区已挂载 |
| 桌面 / UI | 可用；持续动画约 26–35 fps |
| 触摸 | 可用（Clearpad，全量程坐标，导航栏 + gpio 按键） |
| 显示 | 可用，经 glrenderd 输出 1080×1920，作为唯一的 fb0 翻转者 |
| GPU | **Adreno 540 上的硬件 GL/GLES 3.2**，经 [glrenderd](../../advanced/software/glrenderd.zh-CN.md) |
| USB | adb 可用（configfs gadget，`18d1:4ee7`） |
| 灯光 | 亮度 + 休眠经移植的 lights HAL（两个 backlight 节点） |
| 存储 | 模拟内部存储可用（`/sdcard`）；microSD 仍未测试 |
| WiFi | feature + supplicant 服务已就位；驱动能加载但**没有 wlan0** —— locator（SERVREG_LOC）现由树内 `pdserve` 提供，PDR 链（icnss）也注册了它的 notifier，但 modem 根 PD 每约 41 秒崩溃一次，wlan_pd/WLFW 来不及启动；modem 稳定性（keepalive/rild）是未解的阻塞项 |
| 音频 | mixer 控制已在探测到的 tasha 声卡上验证；**尚无听得见的播放** —— 卡在 ADSP 里的 PREPARED（`msm_pcm_playback_copy` 等待超时）；属保护域/守护进程工作线 |
| 蜂窝网络 | 本移植没有 RIL 库 —— 不可用 |
| 相机 / GPS / BT / 指纹 | 未开始（专有 HAL） |

已知的设备怪癖：偶发的**用户空间之前启动挂死**（卡在 Sony 开机画面，
**完全无 USB** —— 重新刷机前先用一次 TWRP 往返恢复）；keyguard 窗口把熄屏
限制在约 10 秒（官方 KitKat 行为，电源键可唤醒）；本移植里 `screencap`
返回固定图像（改为 dump fb0）。细节见 [怪癖](quirks.zh-CN.md)。

**版本发布：** maple 镜像在本地构建 —— 尚无公开 zip；见
[为 maple 构建 KitKat](../../advanced/build/kitkat.zh-CN.md)。cooper 的 zip
位于 [GitHub Releases](https://github.com/pukikiko/retro-android-ports/releases)。

## 文档与链接

- [**设备怪癖**](quirks.zh-CN.md) —— 硬件快照、分区布局、完整的
  TEST 1–41 打通日志、阻塞清单与已验证的修复。
- [KitKat 4.4.4 移植笔记](../../advanced/porting-notes/kitkat.zh-CN.md) ——
  本次移植产出的通用实战手册。
- [为 maple 构建 KitKat](../../advanced/build/kitkat.zh-CN.md)。
- [设备树](../../../devices/maple/kitkat/)（`devices/maple/kitkat/`）
  与 [AOSP 补丁](../../../patches/kitkat/README.zh-CN.md)（`patches/kitkat/`）。
- 此处用到的工具：[glrenderd](../../advanced/software/glrenderd.zh-CN.md)。

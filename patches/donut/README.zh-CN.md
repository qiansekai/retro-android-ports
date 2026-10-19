# patches/donut

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

本移植对干净 AOSP Donut（`android-1.6_r2`）检出所做的改动。
分步构建：[`docs/advanced/build/donut.zh-CN.md`](../../docs/advanced/build/donut.zh-CN.md)；
实战教训：[`docs/advanced/porting-notes/donut.zh-CN.md`](../../docs/advanced/porting-notes/donut.zh-CN.md)。
每个 `.patch` 都是针对所列仓库项目的 `git diff`，在该项目根目录下应用：

```sh
cd aosp-donut/system/core && git apply ../../patches/donut/system-core.patch
```

| Patch | 项目 | 内容 |
| --- | --- | --- |
| `system-core.patch` | `system/core` | init：cooper STL 卷扫描打通（`do_insmod_inner`），maple 打通进度日志写到 `/cache`（`init.c`/`init.h`/`util.c` —— `progress_init()` 在 ueventd 存在之前就自己 mknod 出 cache 节点；`property_service.c` 里的 `ashmem` mknod 回退）；adb：拆分管道实现的 shell（此 bionic 上没有 `socketpair()`），以及 `shell:`/`reboot:` 服务参数的生命周期修复（`strdup`）—— Donut 把栈上的数组传给了服务线程，于是 `adb shell <cmd>` exec 出来的是个裸 `/system/bin/sh`，一直等 stdin |
| `frameworks-base.patch` | `frameworks/base` | `preloaded-classes`：去掉专有的 `com.google.common.*`/`masf.*`（修复 zygote 崩溃循环）；`DatabaseHelper`：预置 `device_provisioned`（修复 HOME 键） |
| `bootable-recovery.patch` | `bootable/recovery` | updater：接受 API 3、裸块 `write_raw_image` 回退方案、`run_program` 向后移植 |
| `hardware-libhardware_legacy.patch` | `hardware/libhardware_legacy` | `wifi.c`：AR6003/ath6kl 驱动加载（`WIFI_DRIVER_*`） |
| `external-wpa_supplicant.patch` | `external/wpa_supplicant` | 面向 ath6kl 栈的 wext/cfg80211 兼容性调整 |
| `packages-providers-CalendarProvider.patch` | `packages/providers/CalendarProvider` | 测试需链接 `vendor/googlelogin` 桩 |
| `mkbootimg-pagesize.patch` | `system/core` | mkbootimg：`--pagesize` + 8K 填充缓冲（2048 的硬编码会损坏 4096 输出） |
| `bionic-binder-uapi-64bit.patch` | `bionic` | 64 位 binder UAPI（协议 8）：`binder_size_t`/`binder_uintptr_t` 为 64 位、24 字节的 `flat_binder_object`、48 字节的 `binder_write_read`（ioctl `0xc0306201`）、`binder_handle_cookie` —— maple 的 4.4 内核没有 32 位协议。从 KitKat 移植的 `patches/kitkat/bionic-binder-uapi-64bit.patch` 搬来 |
| `frameworks-base-binder-64bit.patch` | `frameworks/base` | 同一 ABI 变更的用户空间那一半：`Parcel`（`mObjects` 64 位偏移，`writePointer`/`readPointer`）、`IPCThreadState`（`BR_ACQUIRE`/`BC_*_DONE`/`BC_FREE_BUFFER`/死亡通知上的指针载荷，64 字节的 `binder_transaction_data`）、C 版 `servicemanager`（`binder_txn`/`binder_object`/`binder_io` 与 64 位 ABI 对齐） |
| `system-core-adbd-ffs.patch` | `system/core` | 面向只有 configfs 的 4.4 内核（没有 `/dev/android_adb`）的 adbd FunctionFS 传输：从 KitKat 的 `usb_linux_client.c` 回移；`adb.c` 在 `/dev/usb-ffs/adb` 存在时选 USB。blob 头用的是**这个内核的古老 magic 值**（descriptors `1`、strings `2`），不是现代的 `0x502`/`0x503` |
| `system-core-devices-major-minor.patch` | `system/core` | ueventd：去掉 8:8 的 major/minor 上限，改用 glibc 的 32 位 `dev_t` 编码 —— 不然每个现代块节点（`sde46` system、`sda15` data，major 259）都会被静默跳过，所有挂载都失败；另外加上 maple 打通用的 `progress()` 行（节点创建与 coldboot 步骤） |
| `frameworks-policies-keyguard-touch-unlock.patch` | `frameworks/policies/base` | `LockScreen`：点击即解锁（`onTouchEvent` → `mCallback.goToUnlockScreen()`，与 MENU 键用的是同一个回调）—— maple 没有 MENU 键，Donut 的非安全 keyguard 也没有别的解锁输入；安全 keyguard 仍走它自己的 `UnlockScreen` |
| `frameworks-policies-orientation.patch` | `frameworks/policies/base` | `PhoneWindowManager`：翻盖保护套的 hall 传感器（bu520x1nvx）上报 SW_LID，而 Donut 把「lid 打开」当成滑盖键盘被拉开 -> 开机时强制横屏（rotation 90）。给 lid-open->landscape 分支加上 `!KEYBOARD_ALWAYS_HIDDEN` 守卫，并设 `KEYBOARD_ALWAYS_HIDDEN = true`（maple 没有滑盖键盘），于是默认方向是竖屏（1080x1920）。修掉了这台硬件上「卡在横屏」的问题 |
| `frameworks-base-keyguard-touch-unlock.patch` | `frameworks/base` | `framework-res`：keyguard 提示串现在读作「Tap to unlock.」/「Tap to unlock or place emergency call.」（Donut 原文让用户按一个这台手机没有的 MENU 键） |
| `build-kcm-file-mode.patch` | `build` | 宿主工具 `kcm`：创建 `.kcm.bin` 文件时权限为 0660（`root:root`），于是应用进程（uid `app_*`）读不到它们；`KeyCharacterMap::load()` 随之返回 NULL，libui 在任何加载键字符映射的应用（Settings、Launcher）里 SIGSEGV（fault addr 4）。改为 0644。maple 还在 `build-maple-donut-image.py` 里再归一化一次权限，双保险 |
| `files/vendor/googlelogin/` | 新增树 `vendor/googlelogin` | 专有 `com.google.android.googlelogin` 的极小桩，`CalendarProvider/tests` 需要它（复制进 `aosp-donut/vendor/`） |

说明：
- `system-core-adbd-ffs.patch` 把 FunctionFS 的 magic 值硬编码成 `1`/`2`，
  因为 whatawurst 的 msm8998 4.4 树在
  `include/uapi/linux/usb/functionfs.h` 里保留了古老的枚举（`DESCRIPTORS=1`、
  `STRINGS=2`、`V2=3`）；写 `0x502` 会让 `__ffs_data_got_descs` 在解析任何
  内容之前就返回 `-EINVAL`（没有 `ffs_do_descs` 日志 —— 唯一可见的症状是
  adbd 反复 `write descriptors errno=22`）。把这个文件搬到别的树之前，
  先重查目标内核的 uapi 头 —— 见 maple
  [`quirks.md` TEST 42](../../docs/devices/maple/quirks.zh-CN.md)。
- `files/` 是以 AOSP 根为基准的纯复制 overlay：
  `cp -a files/vendor aosp-donut/vendor/`。
- 工作树里的 `adb/usb_linux_client.c` 带着 TEMP 打通诊断（`ffs_dbg()`
  往 `/cache/adbd-ffs.log` 追加），`system-core-adbd-ffs.patch` 故意不含它们。
  重新生成该补丁（`git diff > …`）前先删掉它们，并保留补丁里关于
  magic 值的注释措辞。
- Patch 对应的是产出经启动验证的 cooper zip 的那棵树
  （以及四个 maple 补丁对应的、经启动验证的 maple 镜像）；它们都是
  纯 diff（无 commit 元数据），因此能经受重复 sync。
- 四个 maple 补丁（binder 64 位 ×2、adbd FFS、ueventd major/minor）
  是纯增量：cooper 仍走它一直用的 32 位路径。
- keyguard 解锁这一对是同一主题落在两个项目上，仅 maple：
  `frameworks-policies-keyguard-touch-unlock.patch`（从
  `aosp-donut/frameworks/policies/base` 应用）让非安全 keyguard 点击即解锁，
  `frameworks-base-keyguard-touch-unlock.patch`（从
  `aosp-donut/frameworks/base` 应用）改掉提示串。背景：maple
  [`quirks.md` TEST 44](../../docs/devices/maple/quirks.zh-CN.md)。

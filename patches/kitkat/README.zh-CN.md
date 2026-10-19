# patches/kitkat

> 中文译文。英文原文见 [README.md](README.md)。技术名词、代码、路径、命令与日志一律保留原文。

本移植对干净 AOSP KitKat（`android-4.4.4_r2`）检出所做的改动。
分步构建：
[`docs/advanced/build/kitkat.zh-CN.md`](../../docs/advanced/build/kitkat.zh-CN.md)；
实战教训：
[`docs/advanced/porting-notes/kitkat.zh-CN.md`](../../docs/advanced/porting-notes/kitkat.zh-CN.md)。
布局与 [`patches/donut/`](../donut/README.zh-CN.md)相同：每个
`.patch` 都是针对所列仓库项目的 `git diff`，在该项目根目录下应用：

```sh
cd aosp-kitkat/system/core && git apply ../../patches/kitkat/<name>.patch
```

图形栈本身**不需要任何 AOSP 补丁**：Adreno 540 驱动经 [libhyb](../../docs/advanced/software/libhyb.zh-CN.md) 在进程内运行，
它的 loader/EGL/gralloc/fbpresentd 源码在设备树里
（`devices/maple/kitkat/`），暂存后的闭包在
`vendor/sony/maple-hyb`，NDK 构建出的 `fbpresentd` 在
`vendor/sony/maple-bin`。

| Patch | 项目 | 内容 |
| --- | --- | --- |
| `build-jdk-openjdk6.patch` | `build` | `core/main.mk`：接受 OpenJDK 6（Oracle JDK 6 在 2026 年已装不上）；其下的版本检查仍强制 1.6.x |
| `bionic-binder-uapi-64bit.patch` | `bionic` | `libc/kernel/common/linux/binder.h` 作为 64 位 binder abi（协议 8），它是 4.4 kernel 唯一能说的一种 |
| `frameworks-native-binder-64bit.patch` | `frameworks/native` | libbinder 与 servicemanager 走该 abi，kernel 看到的每个指针与偏移都是 64 位。取代 `binder-uapi-64bit.patch`；应用前先 reset 这两个项目 |
| `system-core-liblog-kmsg-fallback.patch` | `system/core` | `liblog/logd_write.c`：4.4 内核没有 logger 驱动（`/dev/log`），所以每条 `ALOG*` 都写成 `/dev/kmsg` 里的 `<level>Tag[pid]: msg` 行（`dmesg`）。libhyb 加载的较新 32 位库也从这里打日志。Taimen 移植。**该节点必须对调用方可写**：内核把 `/dev/kmsg` 以 `0600 root` 拉起，liblog 的 `open()` 一旦 EACCES 就静默丢掉每一行 —— 设备树的 `init.rc` 把它 chmod 成 `0622`（见移植笔记） |
| `system-core-liblog-kmsg-terminator.patch` | `system/core` | 总是用 `\n` 终结 kmsg 记录 —— 否则内核会把下一条消息接到上一行。要在回退补丁**之后**应用。Taimen 移植 |
| `system-core-elapsedrealtime-boottime.patch` | `system/core` | `libutils` 的 `elapsedRealtime()` 改从 `CLOCK_BOOTTIME` 取（KitKat 的 `/dev/alarm` 在这个内核上不存在）+ `init/util.c` 读取完整的 4 KiB 内核 cmdline（maple 上原来被截断：`slot_suffix`、`serialno` 丢失）。Taimen 移植 |
| `system-core-fsmgr-ext4-project-quota.patch` | `system/core` | `fs_mgr` 在挂载前清掉 `/data` 超级块里的 `RO_COMPAT_PROJECT` —— 较新的 ROM（slot B 上的 Lineage）可能开过 project-quota 特性，4.4 内核会拒绝；带 `metadata_csum` 时跳过（那需要重算校验和）。Taimen 移植 |
| `dalvik-zygote-capset-v3.patch` | `dalvik` | Zygote 的 `setCapabilities` 改用 `capset` ABI v3（64 位掩码），这样 `system_server` 能保住 `CAP_WAKE_ALARM`/`CAP_BLOCK_SUSPEND`（bit 35/36）—— v1 ABI 会把它们截掉。与下面那个时间补丁配套。Taimen 移植 |
| `frameworks-base-time-without-dev-alarm.patch` | `frameworks/base` | `AlarmManagerService` 跑在 `*_ALARM` timerfd 上，并用 `settimeofday` 设时钟，而不是 KitKat 的 `/dev/alarm`；另外还有 `SystemClock`、`ZygoteInit` 的 cap 列表和 `rtc-restore` 服务钩子。Taimen 移植 |
| `frameworks-base-disable-atlas.patch` | `frameworks/base` | 回移 Lollipop 的 `config.disable_atlas`：asset atlas 假定走 GPU 渲染，建不出来时会把 `system_server` 弄死（即回退渲染路径）。Taimen 移植 |
| `frameworks-base-hwui-gles2-cap.patch` | `frameworks/base` | `libs/hwui/Extensions.cpp`：把上报的 GL 版本封顶在 ES 2.0 —— KitKat 的 hwui 只针对 ES2 行为测过；较新的驱动会宣称 3.2。Taimen 移植 |
| `frameworks-base-input-dispatch-freeze-thaw.patch` | `frameworks/base` | `services/input/InputDispatcher.cpp/.h`：解除超过 10 秒的分发冻结（WMS 会在窗口切换前后冻结；一次永不结束的切换让 dispatcher 沉睡、UI 不再接受触摸） |
| `frameworks-base-keyguard-scrim-no-input.patch` | `frameworks/base` | `policy/.../KeyguardServiceDelegate.java`：绝不显示崩溃遮罩，并让它 `FLAG_NOT_TOUCHABLE`/`FLAG_NOT_FOCUSABLE` —— 死掉的 keyguard 不能一边留着最后一帧、一边吞掉所有输入（glrenderd 时代之后保留：它仍是一张廉价的兜底安全网） |
| `frameworks-base-systemui-wallpaper-canvas-fallback.patch` | `frameworks/base` | `packages/SystemUI/.../ImageWallpaper.java`：EGL 没有 ES2 config 时回退到 canvas 壁纸而不是抛异常（纯软件 GLES；该崩溃让 systemui 循环崩溃，并留下一个吞掉所有触摸的僵尸 KeyguardScrim） |
| `hardware-libhardware-gralloc-fb-stride.patch` | `hardware/libhardware` | `modules/gralloc/gralloc.cpp`：为 `HW_FB` 缓冲上报 kernel 的 `line_length` 步幅（mdss 把 1080 宽的 RGBA 行补齐到 1088；按 align-4 上报 1080 会让每一行被剪切成平行四边形）。`gralloc.default` 回退仍在用它；`gralloc.maple` 自己上报 QTI 步幅 |
| `packages-apps-settings-kernel-version.patch` | `packages/apps/Settings` | `DeviceInfoSettings`：`/proc/version` 的正则接受任何编译器 —— maple 的内核是 clang 构建的，只认 GCC 的模式会让「关于手机」显示「Unknown」。Taimen 移植 |
| _（预计还有更多）_ | — | init/vold/adbd/HAL 加固，待 maple 上实测后加入（参照 `patches/donut/` 先例）。注意：原先预计需要的 mkbootimg `Image.gz-dtb`/base-0 回移并不需要（几何已验证） |

说明：

- glrenderd 时代的补丁（`device-generic-goldfish-glrenderd`、
  `frameworks-native-egl-glrenderd`、
  `frameworks-native-glconsumer-glgeterror-bound`、`sdk-glrenderd`、
  `system-core-glrenderd-fs-config`）以及它们需要的 `files/` overlay
  （`RenderdStream.{cpp,h}`）在图形栈转向 libhyb 时已于 **2026-10-18 删除**：
  官方 KitKat 的 loader（`checkGlesEmulationStatus`）本来就是 EGL 补丁恢复的东西，
  而模拟 GL 库如今已完全不构建。被删的补丁在 git 历史里，
  且仍与保留旧设计的 poplar 移植相关。
- Patch 对应的是产出经启动验证的 maple zip 的那棵树；
  它们是纯 diff（无 commit 元数据），因此能经受重复 sync。
- 绝不要提交 blob 或完整 AOSP 树；`aosp-kitkat/` 已 gitignore。

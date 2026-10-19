# raphael 怪癖（Redmi K20 Pro）

KitKat 4.4.4 与 Froyo 2.2 在 Redmi K20 Pro（`raphael`，SM8150）上的逐条坑点：症状 → 根因 → 修法，附实测证据。设备页在 [README.md](README.md)；通用方法论见 [KitKat 移植笔记](../../advanced/porting-notes/kitkat.md)。标注 `[MEASURED]` 的都在本机验证过，`[TODO]` / `verify-me` 的是未验证推断。现场台账（boot 镜像、串口日志、pstore）在本地 `dumps/`（gitignore，不入库）。

## 平台与引导

- **没有 fbdev，显示必须自带 presenter。** [MEASURED] 内核 `CONFIG_FB_MSM` 关、`CONFIG_DRM_FBDEV_EMULATION` 关，`/dev/graphics` 不存在，只有 `/dev/dri/card0` + `renderD128`。修法两层：① `hwcomposer.raphael`（HWC 1.1）**绝不** `eglSwapBuffers`（HWC 的 set 收到 `dpy/sur = 0xdeadbeef`），而是把 `HWC_FRAMEBUFFER_TARGET` 经 goldfish framebuffer HAL（`framebuffer_open` → `fbDev->post`）提交，即 rcFBPost → glrenderd；② glrenderd 的 DRM 后端把 SurfaceFlinger 的帧上屏。前 30 分钟的黑屏就是缺第 ① 层。
- **DRM presenter 的四个必做细节。** [MEASURED] dumb buffer 必须导成 dma-buf：32 位用户态 mmap 不了 `MAP_DUMB` 返回的 4 GiB 伪偏移，`mmap(dma_buf_fd, 0)` 才行；`SETCRTC` 只在启动时做一次（mode + connector）；每帧只走 `PAGE_FLIP`；flip 事件**只读一次**，循环 read 会把 presenter 堵死。证据：`flip` 3–6 ms/帧、`frame 60 → 420` 连续增长、`dmesg` 无 DRM 报错、用户确认无撕裂。
- **`import /init.raphael.rc` 必须钉死。** [MEASURED] 小米 bootloader 往 cmdline 追加 `androidboot.hardware=qcom`，所以 KitKat 的 `${ro.hardware}` 会去 import 一个不存在的文件；在 `init.rc` 里写死 `import /init.raphael.rc`。
- **binderfs 在 4.4 上挂不上。** [MEASURED] 从 4.4 用户态 mount binderfs 返回 ENOENT（C 探针确认）。修法：内核 `CONFIG_ANDROID_BINDERFS=n` + `CONFIG_ANDROID_BINDER_DEVICES="binder"`，KitKat 拿到 misc 的 `/dev/binder`。
- **`merge_config.sh -O out out/.config fragments` 会删掉基础选项**（`ARCH_QCOM` 等）。[MEASURED] 改成把 fragments 追加进 `out/.config` 再跑 `olddefconfig`。
- **`rsync -a` 保留 mtime，改了源码也不重编。** [MEASURED] `hwcomposer.o` 必须强制删；另外 `rsync --delete` 会顺手删掉 `vendor/<vendor>/<device>/kernel` 这个被 gitignore 的内核 blob，下一次 `make bootimage` 直接报 "No rule to make target"。上游 2026-10-19 已在 `scripts/sync-device-tree.sh` 加 `--exclude kernel`，fork 跟随。
- **KitKat toolbox 是个贫民窟。** [MEASURED] 没有 `tail`/`wc`/`printf`/`head`/`sed`/`pidof`，adb 一行命令只能用 `grep`/`cat`/`ls`/`ps`；`pkill -f` 会连自己的 `bash -c` 外壳一起杀，用精确 PID。
- **内核 sysfs 会撒谎。** [MEASURED] `/sys/class/drm/card0-DSI-1/enabled` 在帧正常扫描时也读 "disabled"；`status` 读 "connected" 才可信。
- **帧计数器停住不等于卡死。** [MEASURED] 静态 Launcher 不产生新帧（KitKat 的 SurfaceFlinger 只在 dirty 时提交）。下结论前先 `dumpsys power | grep mWakefulness`。
- **唤醒键有讲究。** [MEASURED] `KEYCODE_WAKEUP`(224) 唤不醒面板，`KEYCODE_POWER`(26) 可以；解锁 `input keyevent 82` + 滑动。
- **`/cache` 在 glrenderd 的 chroot 里不可见。** [MEASURED] 日志别 `fopen("/cache/...")`，走宿主 shell 重定向的 stderr，或 init 服务里 `2>/dev/kmsg`。
- **glrenderd 必须早于 SurfaceFlinger 的首个 EGL/gralloc。** [MEASURED] `init.raphael.rc` 在 `on post-fs-data` 里 `start glrenderd`；服务是 `disabled`，只有显式 start 才会拉起。
- **缺 emulated-storage 环境变量会让 zygote 死在 `Debug.<clinit>`**（NPE）。[MEASURED] `init.raphael.rc` 里补 `EXTERNAL_STORAGE` + emulated-storage 相关 env。

## Froyo 2.2

- **TLS 崩溃在 init 的第一条指令附近。** [MEASURED] pstore 记 `Kernel panic - not syncing: Attempted to kill init! exitcode=0x0000000b`（11 = SIGSEGV）；`qemu-arm-static -strace` 复现为 `si_addr=0x00000008`。根因：`bionic/libc/private/bionic_tls.h:102` 在未定义 `HAVE_ARM_TLS_REGISTER` 时用旧 ARM kuser helper 页 `0xffff0ff0`，ARM64 内核不映射该页 → TLS 恒 0。修法：`BoardConfig.mk` 加 `ARCH_ARM_HAVE_TLS_REGISTER := true`（影响所有 native 编译单元，需 `make clean` 全量重编）。
- **binder 的 64 位 UAPI 必须按内核实测改。** [MEASURED] 本内核 `CONFIG_ANDROID_BINDER_IPC_32BIT=n` 下 `struct binder_write_read` 是 48 字节、ioctl `0xc0306201`（KitKat 文档里的 `0xc0286201` 不适用）。Froyo 侧 bionic/libbinder/servicemanager 三层都要按 64 位布局重写，protocol 版本 8。
- **`binder_write: ioctl failed (Bad address)` 的怪因。** [MEASURED] `memset(&bwr, 0, sizeof(bwr))` 被编译器优化掉（随后逐字段赋值），`binder_uintptr_t` 之间的 4 字节 padding 留着栈垃圾 `0xffffffff`，内核按 8 字节读成 `0xffffffffffc57de0` → copy_from_user 失败。修法：用 `volatile unsigned char*` 逐字节清零；所有指针转发加 `(unsigned int)(unsigned long)` 中转。
- **ueventd 只建 `sda1`–`sda15`，`sda16`–`sda31` 全缺。** [MEASURED] 两个叠加原因：Froyo coldboot 靠内核 netlink，在 4.14 上 socket 溢出丢事件；`make_device()` 里 `if (major > 255 || minor > 255) return;` 加旧 8:8 编码，现代 UFS 分区（major 259）被直接丢弃。修法：`coldboot_block_direct()` 直接读 `/sys/class/block/*/uevent` 自己 mknod，dev_t 用 glibc 新编码 `(minor & 0xff) | (major << 8) | ((minor & ~0xff) << 12)`；另外 4.14 没有 `/sys/class/misc/kmsg`，init 要自己 `mknod /dev/kmsg`，否则 init 日志全丢。
- **genext2fs 产出的 rev0 / 1KB block ext2 在 4.14 上挂不上。** [MEASURED] `mount` 返回 EINVAL（`CONFIG_EXT4_USE_FOR_EXT2=y` 也救不了）。修法：`mke2fs -t ext4 -b 4096 -d <system> -F system-ext4.img` 生成标准 4K ext4 再刷。
- **system_server SIGILL 在固定地址。** [MEASURED] core dump 解出指令 `e1010090 = SWP`：`atomics_arm.S` 被编译成 swp 分支，而内核不支持。修法：强制 LDREX/STREX + `dmb`。
- **goodix 只说协议 B，Froyo 只认协议 A。** [MEASURED] 触摸硬件本身正常（`getevent` 有 MT tracking id/X/Y/BTN_TOUCH），但 Froyo 的 `KeyInputQueue` 只处理 `SYN_MT_REPORT`。修法：驱动里显式发 `input_event(dev, EV_SYN, SYN_MT_REPORT, 0)`，帧尾补一条空同步（`!touch_num` 时）让 Froyo 合成 `ACTION_UP`；同时**删掉** `pressure<=0` 强置 1 的兜底，否则抬手帧也被算成指针，永远没有 `ACTION_UP`（表现为「点了像拖动、对话框点不动」）。
- **熄屏时 `EV_ABS` 被整包丢弃。** [MEASURED] `WindowManagerService.KeyQ.preprocessEvent` 的 `case EV_ABS` 在 `screenIsOff` 下 `return false`，调用点 `if (!send) continue;` 在 MTABS 日志之前 → 坐标恒 0、只有 `MTSYNC` 打印。根因：Froyo 的 power HAL 往 `/sys/power/state` 写 `"on"`，4.14 只接受 freeze/mem/disk，`mPowerState` 永远缺 `SCREEN_ON_BIT`。修法：`EV_ABS` 分支改为无条件 `return true`（本移植面板由 `fbmirror` 常亮，不需要按电源状态过滤触摸）。
- **fb0 的行跨度不是 `line_length`。** [MEASURED] PixelFlinger 按 `width*4` 写（1080×4），内核报的 `line_length` 是 16384；用错会把 2160 行压到顶部 1/4。另外 32 位进程 mmap fb0 会 SIGBUS → 改 `lseek` + `read` 逐行取。
- **fb0 只有 2160 行，面板是 2340。** [MEASURED] `drm_fb_helper_fill_var()` 按 DSI mode 设了 `yres=2160`，但 framebuffer 实际分配了 `yres_virtual=2340`（`smem_len = 4096*2340*4`）。修法：`msm_fbdev.c` 里 `fbi->var.yres = fbi->var.yres_virtual;`，之后 1:1 拷贝、goodix 也不用再按 2160/2340 缩放。
- **`touchbridge` 会造成"幽灵滑动"。** [MEASURED] 系统重启后 init 重新拉起 `/sbin/touchbridge`，无触摸也持续转发残留事件（每几秒坐标从中下往上一滑）。`stop touchbridge` 后 `getevent` 两秒零事件；改用 goodix 原生协议 A，把它从 init.rc 移除。
- **`screencap` 在这个移植上不可用**（返回恒定图像）；截图走 fb0 dump：`fbshot`（scale 4/8/16，BMP + base64 经串口回传）。

## 未解

- **netd 卡在启动。** [TODO] `/data/netd.log` 只有 `Netd 1.0 starting`，主线程停在 `hrtimer_nanosleep`；`system_server` 的 ServerThread 阻塞在 `Tethering.enableUsbIfaces → NetworkManagementService.listInterfaces → NativeDaemonConnector.doCommand`（`wchan=binder_ioctl`），会拖慢 Activity 并可能触发 Launcher ANR。方向：把该查询移出主线程或给 netd 命令加超时。
- **本屏触摸偶发断触。** [TODO] goodix 固件在滑动中偶发上报 `touch_num=0`，Froyo 的协议 A 解析把它当抬手，表现为断触/重复触发。当前可用替代是串口投屏点击/拖动；KitKat 侧同源问题待验。
- **RTC/时区未对时。** [TODO] 状态栏时钟不准。
- **`/dev/alarm` 缺失的时间路子。** verify-me：Froyo 的 `CLOCK_*_ALARM` 在 4.14 上不可用，参考 Taimen 移植的做法是 `CLOCK_BOOTTIME` + capset v3 保 `CAP_WAKE_ALARM`/`CAP_BLOCK_SUSPEND`，并用 `/data/system/time/rtc_offset` 恢复 RTC —— raphael 上尚未逐项验证。

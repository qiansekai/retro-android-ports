# poplar 怪癖（Sony Xperia XZ1）

> 中文译文。英文原文见 [quirks.md](quirks.md)。技术名词、代码、路径、命令与日志一律保留原文。

`poplar` 上的 KitKat 4.4.4（`maple` 的 yoshino/MSM8998 姊妹设备）。
先看[设备页](README.zh-CN.md)，再看 [KitKat 移植笔记](../../advanced/porting-notes/kitkat.zh-CN.md)
与 [构建 KitKat](../../advanced/build/kitkat.zh-CN.md)。

状态：**已启动，可日常使用（2026 年 10 月）** —— Sony 4.4 内核上的完整 KitKat
用户空间：`sys.boot_completed=1`，1080x1920 的桌面 + 导航栏，触摸、USB adb，以及
Adreno 540 上经 `glrenderd` 的硬件 GL
（[poplar GPU 修复](../../advanced/poplar-kitkat-gpu-fixes.zh-CN.md)）—— 该设计 maple
已于 2026-10-18 弃用并改用 [libhyb](../../advanced/software/libhyb.zh-CN.md)；poplar 那份
工具/补丁副本在 git 历史里。未解：没有
蜂窝/音频/相机/GPS/WiFi/BT，且渲染器在持续负载下仍会卡住。
Donut/cooper 方法参考：[Donut 移植笔记](../../advanced/porting-notes/donut.zh-CN.md)；
姊妹设备：[maple 怪癖](../maple/quirks.zh-CN.md)。

- **差异警告（已验证 2026-10-16）。** 这棵已提交的树早于 maple
  TEST 36–37 —— 它缺少 wifi supplicant/p2p/dhcpcd 服务 + `/data/misc/wifi`
  目录、音频用的 `boot_adsp` + 固件暂存、双节点（`lcd-backlight`
  + `wled`）lights HAL，以及 `service_locator.enable=0`。不要把 poplar 的 init/
  BoardConfig 当成比 maple 更新；请从 `devices/maple/kitkat/` 前移，
  并用回读重新验证。

## 硬件

- MSM8998（SD835，Kryo 280 ARM64）+ Adreno 540，4 GB LPDDR4X，64 GB UFS，microSDXC。
- 5.2 英寸 1080x1920 IPS LCD，约 424 ppi，单 DSI **command-mode** 面板（`dsi_cmd_mode`，
  4 lanes，`non_burst_sync_event`）。
- 原厂：Oreo 8.0 -> Pie 9。参考：`sony-msm8998/android_device_sony_poplar`（10/11）
  + `yoshino-common`，4.4 内核（`Image.gz-dtb`）。
- `poplar`（G8341）/ `poplar_dsds`（G8342）；运营商变体 `poplar-kddi`（SOV36）—— DT
  报告 `SoMC Poplar-KDDI(MSM8998 v2.1)`、`somc,poplar-kddi`。

## poplar vs maple

同平台、同内核、同 init 接线 —— 只有移植差异：

| | poplar | maple |
| --- | --- | --- |
| 面板 | 5.2 英寸 1080x1920 IPS | 5.5 英寸 3840x2160 4K HDR（按 1080p 渲染） |
| 面板节点 | `somc,9_panel`（活动）+ `somc,6_panel` | `somc,6_panel` 系列 |
| fb stride | 4352 B（1088 px） | 4352 B（1088 px） |
| boot | `sda38` | `sde35` |
| system / userdata | `sda65` / `sda66` | `sde46` / `sda15` |
| cache / persist | `sda53` / `sda33` | `sda5` / `sda4` |
| 密度 | 430 | 410 |

其余全部（`BOARD_KERNEL_BASE 0`、pagesize 4096、`Image.gz-dtb`、GPT/ext4、
`TARGET_BOARD_PLATFORM := <device>` 而非 `msm8998`、configfs USB gadget、`lights` HAL、
`@glrenderd`）完全相同。一台上的修复就是另一台的候选修复 —— 用回读验证。

## 平台

- boot/recovery 64 MB，`BOARD_FLASH_BLOCK_SIZE 131072`，处处 ext4
  （`TARGET_USERIMAGES_USE_EXT4`，否则 KitKat 会静默构建出 yaffs2 的 system.img）。Fastboot
  `flash boot`；没有 BML 那套折腾。**每次刷写都用回读验证** —— 这个 bootloader 没有
  `fastboot fetch`。
- 按裸节点的块映射，位于 `/dev/block/platform/soc/by-name/`（KitKat ueventd 没有
  `/dev/block/bootdevice/`）：boot `sda38`，system `sda65`，userdata `sda66`，cache
  `sda53`，persist `sda33`（vendor/oem `sda64`/`sda63`，未挂载）。
- 内核是**预编译的 4.4 blob**（`device/sony/poplar/kernel`，15,828,088 B，
  `Image.gz-dtb`），从 boot 分区 dump 出来，不入 git。此处的一切都不需要重建内核。
  **没有 `CONFIG_ANDROID_LOGGER` -> `logcat` 不可用**；日志走文件
  （`/dev/kmsg`、`/data/misc`、dropbox、tombstones、`dump-boot-log.sh`）。
- 面板：`somc,9_panel` 由 `somc,lcd-id-adc` 选中（`panel_name=9`、`lcdid_adc=228`）；
  两块面板都是 1080x1920@60。`fb0` stride 是 **4352 B（1088 px）** —— gralloc 必须上报
  内核 stride 而非 1080，否则每一行都会错切 8 px（maple TEST 28）。基础显示
  不需要 DTB/驱动改动。`somc,change-fps-*` 是 Sony 的面板重定时钩子，不是
  刷新率开关 —— 驱动接受了某个值并不证明面板变了。

## init 接线

全部都在 boot 镜像里（`make bootimage`）—— 没有一项能用 `adb push` 送进去。

- **一条失败的 init 命令会静默中止它所在的整个 action** —— 因此每个
  `on init` 只做一次挂载。
- 先 `mkdir` 挂载点：挂到不存在的目录会静默失败 `ENOENT`，而
  官方 init.rc 既不创建 `/cache` 也不创建 `/persist`。
- KitKat 挂载语法：空格分隔的标志，**一个**尾部 options 参数。没有
  `wait_for_coldboot_done`（不是 KitKat 命令 —— 会中止 action）。
- 设备 rc 只 `import` 一次（第二次 import 会重复解析它，并为每个服务刷
  "ignored duplicate"）。
- 打通期用 `setenforce 0` —— enforcing 会引发拒绝风暴（曾有一次 audit-backlog 的 D-state
  风暴把负载顶住好几分钟、CPU 毫无进展）。
- 手写挂载时用 `class main`，不用 `late_start`。由
  `PRODUCT_COPY_FILES` 拷进来的脚本要 `chmod 0755`（它们落地时是 644，init 不会执行它们）。
- adb：`import /init.poplar.usb.rc` —— 没有它 `usbudc` 对 init 是未知的，
  于是**完全没有 USB**；`usbudc.sh` 构建 configfs gadget + ffs，执行
  `ctl.stop/start adbd` 让 adbd 接上 ffs，在绑定 UDC 前等待（否则主机
  看到 code 43），并在循环里重新绑定（KitKat 的 adbd 在断开时会关闭 ep0，从而解绑
  UDC）；在 `on boot` 里 `start usbudc`，**不要**用 `on property:sys.usb.config=adb`。
- 渲染器：在 `post-fs-data` 里 `write /sys/module/firmware_class/parameters/path /vendor/firmware` 然后
  `start glrenderd` —— 渲染器在框架之前，只有一个翻转者。

## 显示 —— 亮度与休眠

- 官方树**没有 `lights.*` HAL**，所以框架从不熄屏，
  亮度也不起作用。`lights/lights.c` -> `lights.poplar` 写
  `/sys/class/leds/lcd-backlight/brightness`。没有 lights HAL = 无休眠也无唤醒。
- 不要用 `stay_on_while_plugged_in=3` + keep-awake 定时器糊过去 —— 那会得到
  「熄屏后不保持熄灭」。改用启动时一次性执行 `displaytune.sh`，不用定时器。
- `::send(..., 0)` 会触发 `SIGPIPE`，进而杀掉 SurfaceFlinger -> `MSG_NOSIGNAL`。

## 输入

- 触摸：`clearpad` 在 init（`post-fs-data`）写入 `post_probe_start` 之前不产生任何事件，
  Lineage 也是如此。很容易漏掉 —— 输入设备一直会注册并
  出现在 `/proc/bus/input/devices` 里。固件的全量程坐标 1:1 映射。
  `clearpad.idc` + `gpio-keys.kl`（与 maple 相同）。
- 派发：渲染器死掉会冻结合成，而卡住的 `InputDispatcher`
  （`DispatchFrozen: 1`）是第二种、独立的冻结 —— 10 秒自解冻，见
  [poplar GPU 修复](../../advanced/poplar-kitkat-gpu-fixes.zh-CN.md)。

## 真机已验证

```
ro.product.device poplar   ro.product.model G8341   ro.product.name full_poplar
ro.sf.lcd_density 430      ro.opengles.version 131072   ro.hardware poplar
ro.build.version.sdk 19    ro.build.id KTU84Q           ro.boot.verifiedbootstate orange
fb0 modes U:1080x1920p-60  fb0 stride 4352
```

## 怪癖

- KitKat 的 toolbox 缺少 `head`/`tail`/`wc`/`sort`/`pkill`/`pidof` —— 推一个静态 busybox。
- toolbox 的 `grep` 管道到提前退出的读者会 SIGPIPE 进 tombstones —— 改为写文件。
- 设备时钟读出 1972，所以 dropbox 时间戳无用；`/proc/<pid>/stat` 第 22 字段
  （start ticks）才是进程启动时刻的可靠标识。
- `adb pull` 读不了块设备 —— 先 `dd` 成文件，再 pull。

## 刷写验证

```sh
adb shell /data/local/tmp/busybox dd if=/dev/block/platform/soc/by-name/boot \
    of=/data/local/tmp/b.img bs=4096 count=3947      # 16166912 B = one image
adb shell /data/local/tmp/busybox md5sum /data/local/tmp/b.img   # == the flashed boot.img
```

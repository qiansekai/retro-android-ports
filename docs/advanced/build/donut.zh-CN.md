# 为 cooper 构建 Donut 1.6

> 中文译文。英文原文见 [donut.md](donut.md)。技术名词、代码、路径、命令与日志一律保留原文。

经启动验证的 cooper Donut 移植的分步构建：干净 AOSP
`android-1.6_r2` → 时代匹配的 chroot → 打过补丁的树 + 设备树 → 可刷入的
CWM/TWRP zip。关于每一步为何存在，以及途中踩到的每一个坑，
请读 [Donut 移植笔记](../porting-notes/donut.zh-CN.md) 与
[cooper 怪癖](../../devices/cooper/quirks.zh-CN.md)。

## 1. 时代匹配的 chroot（唯一的硬性前提）

Donut 需要 **Java 5**（`build/core/main.mk` 会检查版本；现代
JDK 无法为 1.5 字节码生成目标码）以及老版本的宿主 GCC（当前 GCC 在
Donut 的宿主工具上直接崩掉）。受支持的路线是时代匹配的 chroot：

- Ubuntu 8.04（Hardy）i386，从 `old-releases.ubuntu.com` 用
  `debootstrap --arch=i386 hardy` 安装
- Sun `sun-java5-jdk`（1.5.0_15）、GCC 4.2.3、Make 3.81、Python 2.5
- 我们使用的挂载点：`/srv/donut-hardy`；AOSP 树以 bind mount 挂入其中
- 宿主上需装 32 位 loader 库，Donut 的 `arm-eabi-4.2.1` 工具链
  二进制才能运行

Chroot/apt/debootstrap 的坑点（缺少 `unzip`、`secure_path` 与
`bzip2`、apt 流水线、Sun 许可预先接受、端点固定）全部记录在
[porting-notes/donut.md § Chroot 坑点](../porting-notes/donut.zh-CN.md#chroot-gotchas-hardy-on-a-modern-host)。

## 2. 获取源码

```sh
repo init -u https://android.googlesource.com/platform/manifest -b android-1.6_r2
repo sync                                # -> aosp-donut/ (gitignored)
```

`AOSP_DIR` 可为下面的脚本选择另一个检出目录。

## 3. 应用移植

```sh
# patches: one git diff per AOSP project, applied from that project's root
# (full table + what each does: patches/donut/README.md)
cd aosp-donut
( cd system/core                       && git apply ../../patches/donut/system-core.patch )
( cd system/core                       && git apply ../../patches/donut/mkbootimg-pagesize.patch )
( cd frameworks/base                   && git apply ../../patches/donut/frameworks-base.patch )
( cd bootable/recovery                 && git apply ../../patches/donut/bootable-recovery.patch )
( cd hardware/libhardware_legacy       && git apply ../../patches/donut/hardware-libhardware_legacy.patch )
( cd external/wpa_supplicant           && git apply ../../patches/donut/external-wpa_supplicant.patch )
( cd packages/providers/CalendarProvider && git apply ../../patches/donut/packages-providers-CalendarProvider.patch )
cd .. && cp -a patches/donut/files/vendor aosp-donut/vendor/   # googlelogin stub overlay

# device tree -> $AOSP_DIR/vendor/samsung/cooper
scripts/sync-device-tree.sh cooper donut
```

## 4. 构建

在 chroot 内、树已挂载的情况下：

```sh
source build/envsetup.sh
lunch full_cooper-eng
make -j8
```

值得先读的坑点：`lunch` 不能接管道（它在子 shell 中运行，`make` 会静默
构建 `generic`），且 Donut 的 `make` 不跟踪 `BoardConfig.mk` 的开关变更 ——
改过开关之后，要删除受影响的 `out/.../obj/..._intermediates` 再重建
（[完整清单](../porting-notes/donut.zh-CN.md#donut-build-system-surprises)）。

## 5. 打包

在仓库根目录执行（`python3`）：

```sh
python3 scripts/build-cooper-donut-full.py       # full system zip
python3 scripts/build-cooper-donut-skeleton.py   # small preview zip
```

| 脚本 | 产出 | 说明 |
| --- | --- | --- |
| `build-cooper-donut-full.py` | `out/full_cooper-1.6.DRD35-UNOFFICIAL-FULL-<date>.zip` | 完整系统，BML 感知的 CWM/TWRP 安装器（API-3 + 裸块 + `run_program` 垫片，51 个 toolbox 符号链接都是真实符号链接）。用 `tools/mkbootimg-cooper` 按 cooper 的几何重新打包 `boot.img`。 |
| `build-cooper-donut-skeleton.py` | `out/full_cooper-1.6.DRD35-UNOFFICIAL-<date>.zip` | 小体积预览 zip；它同时会编译 `tools/mkbootimg-cooper`（完整打包脚本期望它已存在）。 |

脚本中的两项验证都基于真实内容断言（APK 数量、
`build.prop`、`ANDROID!` 头部字段）—— 脚本失败即视为构建失败。

## 6. 刷入与验证

- 从 CWM/TWRP 刷入该 zip。**BML 上的 boot 必须先擦除再写入，
  经 `/sbin/erase_image boot` + `/sbin/flash_image boot`**（对 BML 的裸写
  会静默不生效）—— 安装器会这么做，且每次刷入都应按裁剪后的回读验证
  （`dd if=/dev/block/bml8 ...` 与镜像比对；
  整分区 md5 永远不可能匹配）。
- 首次启动需要 **10–20 分钟**（32 个 APK 的 dexopt）；观察
  `/data/dalvik-cache` 增长，而不是假定它卡死。
- 实践建议：保持电池充电（负载下 USB 供电跟不上），并且
  电量低于约 50% 时绝不要刷 boot。

recovery 交互笔记、手动刷入时的符号链接/权限坑点，
以及完整的设备端验证历史见
[cooper 怪癖](../../devices/cooper/quirks.zh-CN.md)。

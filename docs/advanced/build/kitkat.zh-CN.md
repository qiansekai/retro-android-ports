# 为 maple 构建 KitKat 4.4.4

> 中文译文。英文原文见 [kitkat.md](kitkat.md)。技术名词、代码、路径、命令与日志一律保留原文。

maple KitKat 移植的分步构建：干净 AOSP
`android-4.4.4_r2` → Trusty/JDK 6 容器 → 打过补丁的树 + 设备树 +
导出的 4.4 kernel → TWRP 刷入的镜像。途中踩到的每一个坑，
连同设备端证据，都在
[KitKat 移植笔记](../porting-notes/kitkat.zh-CN.md)与
[maple 怪癖](../../devices/maple/quirks.zh-CN.md)的打通日志中。glrenderd
（硬件 GL）有独立的[工具页](../software/glrenderd.zh-CN.md)。

如果你在远程宿主上构建，请先读
[构建服务器运行手册](../build-server.zh-CN.md) —— 其中有服务器
布局、后台启动的坑点与刷入流程。

## 1. 宿主容器

KitKat 需要 **JDK 6** 和 Trusty 时代的用户态。配方位于
[`containers/kitkat/`](../../../containers/kitkat/)：

```sh
docker build -f containers/kitkat/Dockerfile -t retro-kitkat:4.4.4 containers/kitkat
docker run --rm -it \
  -v <local aosp-kitkat>:/srv/aosp-kitkat \
  -v ~/ccache-kitkat:/srv/ccache-kitkat \
  retro-kitkat:4.4.4
```

镜像只提供工具链（`lib32stdc++6 lib32z1`、一个 `python`
符号链接、`openjdk-6-jdk`）；树是 bind mount 进去的，从不打进镜像。

## 2. 获取源码（浅克隆！）

```sh
repo init -u https://android.googlesource.com/platform/manifest \
    -b android-4.4.4_r2 --depth=1
repo sync -c --no-tags -j6                  # -> aosp-kitkat/ (~14 GB)
```

全历史 sync 会膨胀到 150 GB 以上 —— 绝不要裸跑 `repo sync`。

## 3. 应用移植

```sh
# patches: one git diff per AOSP project, applied from that project's root
# (full table + what each does: patches/kitkat/README.md)
cd aosp-kitkat
( cd build             && git apply ../../patches/kitkat/build-jdk-openjdk6.patch )
( cd bionic            && git apply ../../patches/kitkat/bionic-binder-uapi-64bit.patch )
( cd frameworks/native && git apply ../../patches/kitkat/frameworks-native-binder-64bit.patch )
( cd frameworks/native && git apply ../../patches/kitkat/frameworks-native-egl-glrenderd.patch )
( cd frameworks/native && git apply ../../patches/kitkat/frameworks-native-glconsumer-glgeterror-bound.patch )
( cd device/generic/goldfish && git apply ../../patches/kitkat/device-generic-goldfish-glrenderd.patch )
( cd sdk               && git apply ../../patches/kitkat/sdk-glrenderd.patch )
( cd system/core       && git apply ../../patches/kitkat/system-core-glrenderd-fs-config.patch )
( cd hardware/libhardware && git apply ../../patches/kitkat/hardware-libhardware-gralloc-fb-stride.patch )
( cd frameworks/base   && git apply ../../patches/kitkat/frameworks-base-input-dispatch-freeze-thaw.patch )
( cd frameworks/base   && git apply ../../patches/kitkat/frameworks-base-keyguard-scrim-no-input.patch )
( cd frameworks/base   && git apply ../../patches/kitkat/frameworks-base-systemui-wallpaper-canvas-fallback.patch )

# whole-file additions the diffs cannot carry (goldfish RenderdStream.*):
# files/ is a copy-overlay rooted at the AOSP tree
cp -a ../patches/kitkat/files/* .

# device tree -> $AOSP_DIR/vendor/sony/maple
scripts/sync-device-tree.sh maple kitkat
```

`sync-device-tree.sh` 使用 `rsync --delete`，所以要把 glrenderd 的暂存
树放在 `vendor/sony/maple-glr`（在 sync 路径之外）—— 这正是
`full_maple.mk` 的复制来源。

## 4. kernel（导出，不构建）

`BoardConfig.mk` 里设了 `TARGET_PREBUILT_KERNEL := vendor/sony/maple/kernel`，
因此 `make bootimage` 会把构建出的 ramdisk 打包到
**从运行中的设备导出的 4.4 kernel** 之上（该 blob 与所有 vendor blob 一样被 gitignore）：

```sh
# phone in TWRP
adb pull /dev/block/bootdevice/by-name/boot boot-dump.img
abootimg -x boot-dump.img                    # -> kernel (Image.gz-dtb)
cp kernel $AOSP_DIR/vendor/sony/maple/kernel
scripts/patch-maple-dtb.py $AOSP_DIR/vendor/sony/maple/kernel   # needs dtc
```

`patch-maple-dtb.py` 会从每个 appended DTB 中去掉
`qcom,mdss-idle-power-collapse-enabled`（否则面板会在空闲时黑屏）与
`qcom,wcn-btfm`（音频卡探测）。它是幂等的，并会按字节校验自己的改动；
若导出的 kernel 被替换，请重跑它。

## 5. 构建

在容器内：

```sh
source build/envsetup.sh
lunch full_maple-eng
make -j$(nproc)              # full build (~1 h, needed after UAPI/bionic changes)
make bootimage systemimage   # iteration targets
```

KitKat 的 `make` 在陈旧性上会骗人（改产品 `.mk` 不会重新触发
目标）—— 删除产物再重建，然后验证内容，绝不要相信时间戳。
`system.img` 构建出来是 **sparse**；任何 `dd` 之前先 `simg2img`。

## 6. glrenderd（硬件 GL/GLES）

guest 侧栈在第 3 步已打补丁；守护进程需要构建并暂存它的 chroot
（`full_maple.mk` 在存在时自动纳入 `vendor/sony/maple-glr`，
所以之后要重建镜像）：

```sh
tools/glrenderd/build.sh $AOSP_DIR <android-ndk-r21e>
tools/glrenderd/extract-lineage.sh <lineage-20-maple.zip> <sysroot> [oem.img]
tools/glrenderd/stage.py <sysroot> tools/glrenderd/out $AOSP_DIR/vendor/sony/maple-glr
make bootimage systemimage
```

前置条件与重建规则（若要重建渲染器，就从同一棵树重建 guest 的
`*_enc.so`）见
[glrenderd](../software/glrenderd.zh-CN.md#building-and-staging)。完全跳过
glrenderd 也是受支持的：EGL 会回退到仅支持 ES1 的 `libagl`
软件路径。

## 7. 刷入与验证

手机处于 TWRP，adb 已连通。推到 `/data/media`（不是 `/sdcard`），
绝不要通过 `adb shell` 管道传 stdin：

```sh
# system: unsparsify with the build's host tool (32-bit; run it where it runs)
aosp-kitkat/out/host/linux-x86/bin/simg2img system.img system.raw.img

adb push system.raw.img /data/media/
adb shell dd if=/data/media/system.raw.img \
    of=/dev/block/bootdevice/by-name/system bs=4M

adb push boot.img /data/media/
adb shell dd if=/data/media/boot.img \
    of=/dev/block/bootdevice/by-name/boot bs=4M
```

**每次刷入都要用回读验证**（推送文件的 md5 与分区对比）之后再重启。
首次启动检查：`sys.boot_completed=1`、
`dumpsys SurfaceFlinger` 经 glrenderd 显示 `Adreno (TM) 540, OpenGL ES 3.2`、
`/sdcard` 与各挂载点存在。卡在开机画面时的恢复：
「卡在开机画面」按 USB 情况分流 —— 完全没有 USB 是进入用户态之前的挂起；
先经 TWRP 往返（从 TWRP 里 `adb reboot`）恢复，再考虑重刷任何东西
（[分诊规则](../porting-notes/kitkat.zh-CN.md)）。

刷入失败取证（`/data/misc/watch*.txt`、tombstones、dropbox、
pstore）与完整的打通 TEST 日志都在
[maple 怪癖](../../devices/maple/quirks.zh-CN.md)。

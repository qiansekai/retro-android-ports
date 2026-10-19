# 为 maple 构建 KitKat 4.4.4

> 中文译文。英文原文见 [kitkat.md](kitkat.md)。技术名词、代码、路径、命令与日志一律保留原文。

maple KitKat 移植的分步构建：干净 AOSP
`android-4.4.4_r2` → Trusty/JDK 6 容器 → 打过补丁的树 + 设备树 +
导出的 4.4 kernel → TWRP 刷入的镜像。途中踩到的每一个坑，
连同设备端证据，都在
[KitKat 移植笔记](../porting-notes/kitkat.zh-CN.md)与
[maple 怪癖](../../devices/maple/quirks.zh-CN.md)的打通日志中。硬件 GL
（进程内的 Adreno 驱动）有独立的
[工具页](../software/libhyb.zh-CN.md)。

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
( cd build              && git apply ../../patches/kitkat/build-jdk-openjdk6.patch )
( cd bionic             && git apply ../../patches/kitkat/bionic-binder-uapi-64bit.patch )
( cd frameworks/native  && git apply ../../patches/kitkat/frameworks-native-binder-64bit.patch )
( cd system/core        && git apply ../../patches/kitkat/system-core-liblog-kmsg-fallback.patch )
( cd system/core        && git apply ../../patches/kitkat/system-core-liblog-kmsg-terminator.patch )
( cd system/core        && git apply ../../patches/kitkat/system-core-elapsedrealtime-boottime.patch )
( cd system/core        && git apply ../../patches/kitkat/system-core-fsmgr-ext4-project-quota.patch )
( cd dalvik             && git apply ../../patches/kitkat/dalvik-zygote-capset-v3.patch )
( cd frameworks/base    && git apply ../../patches/kitkat/frameworks-base-time-without-dev-alarm.patch )
( cd frameworks/base    && git apply ../../patches/kitkat/frameworks-base-disable-atlas.patch )
( cd frameworks/base    && git apply ../../patches/kitkat/frameworks-base-hwui-gles2-cap.patch )
( cd frameworks/base    && git apply ../../patches/kitkat/frameworks-base-input-dispatch-freeze-thaw.patch )
( cd frameworks/base    && git apply ../../patches/kitkat/frameworks-base-keyguard-scrim-no-input.patch )
( cd frameworks/base    && git apply ../../patches/kitkat/frameworks-base-systemui-wallpaper-canvas-fallback.patch )
( cd hardware/libhardware && git apply ../../patches/kitkat/hardware-libhardware-gralloc-fb-stride.patch )
( cd packages/apps/Settings && git apply ../../patches/kitkat/packages-apps-settings-kernel-version.patch )

# device tree -> $AOSP_DIR/vendor/sony/maple
scripts/sync-device-tree.sh maple kitkat
```

`sync-device-tree.sh` 使用 `rsync --delete`，所以暂存的图形闭包
（closure，`vendor/sony/maple-hyb/`）与 NDK 构建的 presenter
（`vendor/sony/maple-bin/`）都放在 sync 路径**之外** —— 这正是
`full_maple.mk` 的复制来源（第 6 步）。唯一*不能*放在外面的暂存文件是
第 4 步的 kernel blob（它必须位于 `vendor/sony/maple/kernel` 以供
`TARGET_PREBUILT_KERNEL` 使用），因此脚本把 `kernel` 排除在删除之外 ——
否则第 4 步之后再 sync 会把这个 blob 删掉，`make bootimage` 就会失败：
`No rule to make target 'vendor/sony/maple/kernel'`（2026-10-19 在本地
kitkat 树上踩到）。

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

## 6. libhyb（硬件 GL/GLES + 音频 ACDB）

图形栈是进程内的 Adreno 540 驱动
（[libhyb](../software/libhyb.zh-CN.md)）：*设备树*提供 loader、
shim、gralloc 与 presenter 源码；构建需要暂存 **Lineage 22.1 闭包**
并构建 64 位 presenter，两者都在 sync 路径之外（`full_maple.mk` 在存在时
自动纳入 `vendor/sony/maple-hyb` + `-bin`，所以之后要重建镜像）：

```sh
tools/libhyb/extract-lineage.sh <lineage-22.1-maple.zip> ~/hyb-sysroot ~/vendorextract/mnt
tools/libhyb/stage.py ~/hyb-sysroot $AOSP_DIR/vendor/sony/maple-hyb
tools/libhyb/build-native.sh $AOSP_DIR          # NDK r21e; builds fbpresentd
make bootimage systemimage
```

`stage.py` 从驱动 + QTI gralloc1 出发遍历 `DT_NEEDED`，补上运行时
`dlopen` 模块与 a540 固件，并列出它暂存了什么、KitKat 自身提供了什么、
还缺什么 —— 缺失项若不是 `libc/libm/libdl/liblog/libcutils/libz`
（也不是虚拟的 `ld-android`/`libdl_android`），就意味着闭包不完整。
它还会暂存 **音频 ACDB** 的消费方（`libacdbloader.so` 及其闭包），并把
yoshino 的 acdb 数据复制到 `acdbdata/MTP/`，由 `full_maple.mk` 安装到
`/system/vendor/etc/acdbdata/MTP/`（即 `/sys/devices/soc0/hw_platform`
报告的名字）。整步跳过也是受支持的：没有闭包时 EGL shim 加载失败，
EGL 回退到仅支持 ES1 的 `libagl` 软件路径，音频 HAL 则未校准运行（无声）。

重新暂存后要重建镜像；改动了任何设备树图形源码后要重新暂存 ——
暂存规则见 [libhyb](../software/libhyb.zh-CN.md#building-and-staging)。

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
`hybtest`（ES3 上下文 + 经闭包的像素回读）、`dmesg | grep -i hyb`、
`dumpsys SurfaceFlinger` 显示 `Adreno (TM) 540, OpenGL ES 3.2`、
`/sdcard` 与各挂载点存在。卡在开机画面时的恢复：
「卡在开机画面」按 USB 情况分流 —— 完全没有 USB 是进入用户态之前的挂起；
先经 TWRP 往返（从 TWRP 里 `adb reboot`）恢复，再考虑重刷任何东西
（[分诊规则](../porting-notes/kitkat.zh-CN.md)）。

刷入失败取证（`/data/misc/watch*.txt`、tombstones、dropbox、
pstore）与完整的打通 TEST 日志都在
[maple 怪癖](../../devices/maple/quirks.zh-CN.md)。

## 不用服务器构建（工作站）

与[构建服务器运行手册](../build-server.zh-CN.md)相同的配方，在本地工作站上跑
（2026-10-19 服务器宕机期间已验证）。只有源码获取、两个 git 之外的输入
与刷入时的转换不同。

- **容器**：需要运行中的 Docker daemon；`docker build -f
  containers/kitkat/Dockerfile -t retro-kitkat:4.4.4 containers/kitkat`
  从 `archive.ubuntu.com` 拉取 Trusty，该站仍在提供 `trusty`
  （2026-10-19 验证）。构建时挂载树与本地 ccache：
  `docker run --rm -v ~/aosp-kitkat:/srv/aosp-kitkat -v
  ~/ccache-kitkat:/srv/ccache-kitkat retro-kitkat:4.4.4 bash -c 'cd
  /srv/aosp-kitkat && source build/envsetup.sh && lunch full_maple-eng &&
  make -j8'`。
- **源码**：Arch 工作站上没有打包 `repo` —— 把 launcher 取到 `~/bin/repo`
  （`curl -sSL
  https://storage.googleapis.com/git-repo-downloads/repo`），然后照第 2 节
  原样执行（`repo init ... -b android-4.4.4_r2 --depth=1 && repo sync -c
  --no-tags -j8` → 14 GB）。sync 在宿主（python3）上跑，不在 Trusty 容器里。
- **补丁 + 设备树 + kernel**：第 3 节与第 4 节。打过补丁的 kernel blob
  在服务器之外也有：maple 的 *donut* 工作树保留着
  `work/maple-donut/kernel-Image.gz-dtb`（md5
  `4a7b3eaf19f808c15a0f45bbe455f2b8`）；把它复制到
  `vendor/sony/maple/kernel`，再跑 `scripts/patch-maple-dtb.py`
  会报 `nothing to do`（幂等 —— 这正是「该 blob 已带上这些改动」的检查）。
- **固件**：`vendor/sony/maple-fw/{adsp,wlan,modem,bt}` 来自手机，不是
  服务器。在 TWRP 中：`mount -t vfat
  /dev/block/bootdevice/by-name/modem /mnt/modem`，把
  `image/{adsp.*,cpe_9335.*,bdwlan*,wlanmdsp.mbn,modem.mdt,modem.b*,mba.mbn}`
  复制出来（`wlan_mac.bin` 来自 `/persist/wlan/`），并在暂存前把每个
  文件与手机做 md5 校验（2026-10-19 那轮共 79 个文件）。
- **闭包**：Lineage 22.1 的 zip 是 SourceForge 上的 maple 构建
  `lineage-22.1-20250115-UNOFFICIAL-maple.zip`（约 1.1 GB），位于
  `sourceforge.net/projects/sony-xperia-xz-premium-rom/files/lineage/maple/A15/2025-1-15/`；
  第 6 节的 `extract-lineage.sh` 会从 zip 的
  `vendor.new.dat.br` 自动解出 vendor（不需要第三个参数）。`build-native.sh`
  自己下载 NDK r21e（`~/.cache/retro-android-ports/ndk`，约 1.1 GB）。
- **别把 NDK 放进 `$AOSP`**：旧 `build-native.sh` 的缓存默认值是
  `$AOSP/out-blobs`，而 AOSP 的 make 会遍历整棵树找
  `Android.mk` 文件 —— NDK 的 `sources/android/cpufeatures/Android.mk`
  于是与树里的 `ndk/` 副本冲突，之后每次 make 都在解析阶段死掉：
  `*** out-blobs/android-ndk-r21e/sources/android/cpufeatures:
  MODULE.TARGET.STATIC_LIBRARIES.cpufeatures already defined by
  ndk/sources/android/cpufeatures.  Stop.` 与解压赛跑的那次构建仍可能
  *成功*（它在 NDK 落地前就完成了解析）；失败要到下一次重建镜像才浮现。
  已在 2026-10-19 的脚本中修复。
- **刷入**：工作站没有 `simg2img`，所以在**手机上**用 TWRP 的
  `/sbin/simg2img` 解稀疏（已验证：两参数用法），再从 `/data/media` 执行
  `dd`。回读必须用精确的镜像大小 —— system 分区是 15,052,800 个扇区
  （约 7.2 GB），boot 是 131,072（64 MB），因此
  `dd if=<partition> bs=4096 count=<image bytes>/4096 | md5sum` 才是能与
  暂存文件对上的形式。TWRP 有 busybox 的 `md5sum`；*已启动*的移植系统
  toolbox 只有 `md5`（也没有 `head`/`tail`/`grep`），所以设备端辅助命令
  要按此编写。首次启动检查清单：第 7 节。


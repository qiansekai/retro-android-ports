# Redmi K20 Pro（raphael）

本 fork 的专属设备页（中文）。K20 Pro（`raphael`，SM8150，2019 年出厂 Android 9）上跑的三个复古版本：**KitKat 4.4.4 已点亮**、**Froyo 2.2 已打通**、Gingerbread 2.3 仅做可行性后暂停。逐条证据与坑点见 [quirks.md](quirks.md)；通用方法论见 [KitKat 移植笔记](../../advanced/porting-notes/kitkat.md) 与上游 [README](../../../README.md)。设备树在 `devices/raphael/`。

## 设备事实（2026-10-17 在 LineageOS 23.2 上实测）

- 面板 1080x2340 @ 440 dpi；触摸 Goodix GT9886（`/dev/input/event3`）。
- **没有 fbdev**：没有 `/dev/graphics`，只有 `/dev/dri/card0` + `renderD128`；`CONFIG_FB_MSM` 关、`CONFIG_DRM_FBDEV_EMULATION` 关、`CONFIG_DRM_MSM` 开。
- binder 是 binderfs（`CONFIG_ANDROID_BINDERFS=y`）；4.14.356 内核（Lineage），`BINDER_IPC_32BIT` 关，无 `ANDROID_LOGGER`/`ANDROID_ALARM`。
- 存储：retrofit 动态分区。`system`/`vendor` 是物理分区；1 GB 的 `cust`（sda30）空闲可用，`cache` = sda29，`persist` = sda23，`userdata` = sda31（f2fs）。
- 设备序列号 `1ec04532`；**boot 分区始终未刷**，两个版本都用 `fastboot boot` 临时启动，system 落在 `cust`。

## 各版本状态

| 版本 | 状态 | 图形 | 输入 | 其他 |
| --- | --- | --- | --- | --- |
| KitKat 4.4.4 | 点亮到 Launcher | HWC 1.1 + glrenderd DRM/KMS（Adreno 640 GLES 3.2，PAGE_FLIP 3–6 ms/帧） | goodix 识别为 touchScreen | USB adb（DWC3 gadget）、binderfs、emulated storage |
| Froyo 2.2 | 点亮到 Launcher，全屏 1080×2340 | 软件渲染 + `fbmirror`（复用 glrenderd 的 DRM 后端） | uinput 注入 + 串口投屏反控；本屏触摸部分可用 | USB CDC-ACM 串口 shell、`fbstreem`/`fbscreen` 投屏、全局导航栏、Contacts/Browser |
| Gingerbread 2.3 | 仅可行性（`repo init` 通、Lucid chroot 通），2026-10-18 暂停 | — | — | 恢复点 `/home/kita/aosp-gb`、`/srv/gb-lucid` |

## 构建与刷机（KitKat）

```sh
AOSP_DIR=$ROOT/aosp-kitkat scripts/sync-device-tree.sh raphael kitkat
# Trusty chroot 里：
lunch full_raphael-eng && make -j12 systemimage ramdisk
simg2img out/target/product/raphael/system.img system.raw.img
# 重打 header v2 boot 镜像（mkbootimg.py；KitKat 自带 mkbootimg 只会 v0）
fastboot flash cust system.raw.img
fastboot boot boot-kk-newkernel.img
```

GL 栈在 `tools/raphael/glrenderd/`（`bash build.sh <aosp> <ndk>`），stage 出的 chroot 放 `vendor/xiaomi/raphael-glr`，由 `full_raphael.mk` 拷进 `/system/glr`。

## 构建与刷机（Froyo）

Froyo 设备树在构建机的 `device/raphael/`（未入库，构建记录与补丁在 `dumps/froyo-raphael/`）：标准 4K ext4 镜像刷 `cust`，`fastboot boot boot-froyo-*.img`。关键点：`ARCH_ARM_HAVE_TLS_REGISTER := true`、64 位 binder UAPI、`mke2fs -t ext4 -b 4096`、goodix 驱动补协议 A。

## 未解缺口

- KitKat：真手指触摸待验（goodix 滑动中偶发 `touch_num=0`）。
- Froyo：netd 卡启动、vold/netd 偶发 abort、RTC 未对时。
- 两版本共用 `cust`，切换版本必须重刷；原始 cust 备份在 Lineage 的 `/data/local/tmp/cust-backup.img`。

# 构建服务器运行手册（maple/KitKat）

> 中文译文。英文原文见 [build-server.md](build-server.md)。技术名词、代码、路径、命令与日志一律保留原文。

[为 maple 构建 KitKat 4.4.4](build/kitkat.zh-CN.md)的远程宿主配套文档；
返回[高级索引](README.zh-CN.md)。下面是通用布局、坑点与刷入
流程 —— 私有的宿主/用户细节来自 `AGENTS.local.md` 或
你自己的笔记。

机器：`androd-buildtest`，Ubuntu 26.04，6 核 / 15 GB 内存 / 约 390 GB
磁盘。经 Tailscale 以 `BUILD_USER@BUILD_HOST` 访问（当前地址见你自己的
笔记 —— 它变过；本地 `tailscale status` 可看对端状态，
「offline, last seen ...」意味着等待，而不是调试）。

## 服务器上的布局

- `~/aosp-kitkat/` —— KitKat 树（`repo init --depth=1 -u
  https://android.googlesource.com/platform/manifest -b android-4.4.4_r2`，
  然后 `repo sync -c --no-tags -j6`）。浅克隆 + 仅当前版本 ≈ 14 GB。
  全历史 sync 会膨胀到 150 GB 以上 —— 绝不要裸跑 `repo sync`。
- `~/retro-devices/kitkat/` —— `devices/maple/kitkat/` 的副本（scp 过去）。
  用 `cp ~/retro-devices/kitkat/* ~/aosp-kitkat/vendor/sony/maple/`
  暂存进树中（等同于仓库的 `sync-device-tree.sh`；该脚本假定树在本地）。
- `~/retro-containers/kitkat/Dockerfile` —— `containers/kitkat/Dockerfile` 的副本。
  改动后重建：
  `docker build -f ~/retro-containers/kitkat/Dockerfile -t retro-kitkat:4.4.4 ...`
- `~/aosp-kitkat/vendor/sony/maple/kernel` —— TWRP 导出的 `Image.gz-dtb`
  （16.7 MB，不在 git 中）。若丢失，用
  `adb pull /dev/block/bootdevice/by-name/boot` + `abootimg -x` 重新导出。
- `~/aosp-kitkat/build-maple.sh`（`lunch full_maple-eng && make -j6`）、
  `build-sys.sh`（`make systemimage`）、`build-boot.sh`（`make bootimage`）、
  `run-*.sh` 包装脚本（`docker run --rm -v ~/aosp-kitkat:/srv/aosp-kitkat
  -v ~/ccache-kitkat:/srv/ccache-kitkat ...`，sudo 需从 stdin 读密码 ——
  见脚本文件）。
- 日志：`~/build-maple.log`、`~/build-sys.log`、`~/build-boot.log`、
  `~/repo-sync*.log`。

## 后台启动（通道会挂起 —— 需单独验证）

`setsid nohup ... &` 仍会占住 SSH 通道；改用很短的客户端超时启动，
忽略该超时，然后用一次新的调用验证
（`pgrep -af '[m]ain\.py'`、日志尾部、`du`）。

## 已经踩过的坑（不要重复）

- `pkill -f`/`pgrep -f` 的模式会匹配到你自己那句 `bash -c` 包装命令
  （它含该模式文本）—— 一律用方括号技巧
  （`[m]ain\.py`）或按精确 PID 杀。我们已经两次杀掉自己的 shell。
- 同一棵树上的两个并发 `repo sync` 会重复 packfile 并相互污染
  （`reference already exists`、损坏的 `base.git` 桩）。
  一次只跑一个 sync；用
  `rm -rf .repo/projects/.../X.git .repo/project-objects/.../X.git`
  + 重新 sync 该项目来修复。
- `sudo` 会把 `~` 重置为 `/root` —— 在 sudo 下一律用绝对
  `/home/BUILD_USER/` 路径。
- `out/` 属 root（容器以 root 身份构建）：读取、`strings`、`scp`
  都需 `chmod`/`sudo`。
- Docker `--rm` 会销毁退出码；改看日志文件尾部。
- KitKat 的 `make` 重新生成的 `system.img` 是 SPARSE —— `dd` 前
  务必 `simg2img`（用容器里的 `out/host/linux-x86/bin/simg2img`；
  它是 32 位，在 Ubuntu 26.04 宿主上跑不了）。
- `make servicemanager systemimage` 这类目标能加速迭代；
  UAPI/bionic 改动后要跑完整 `make -j6`（约 1 小时，触及一切）。
- `TARGET_NO_KERNEL` 尚未设置 —— 等服务器恢复访问后设置它
  （并把三个补丁集正式化）；见 maple 怪癖的待办清单。

## 刷入流程（手机侧，从 Linux 工作站操作）

手机处于 TWRP（`adb devices` → `recovery`）。镜像位于仓库 `dumps/`
（gitignored）：
- `dd if=<raw-system> of=/dev/block/bootdevice/by-name/system bs=4M`
  （5 GB 裸镜像，本地经 simg2img 转出；推到 `/data/media`，**不是**
  `/sdcard`，后者拒绝创建文件；`adb shell` 的 stdin 管道会失败 —— 用文件推送）。
- `dd if=<boot.img> of=/dev/block/bootdevice/by-name/boot bs=4M`
  + 每次重启前都做回读 md5 校验。
- 回读状态：`/data/misc/watch*.txt`、`/data/misc/sm-debug.txt`、
  `/data/dalvik-cache` 数量、`/data/tombstones`、`/sys/fs/pstore/*`
  （若为空，在 TWRP 中挂载 pstore）、`/data/system/packages.xml`。
- 启动 15 分钟后手机会自动回到 TWRP（autowinch 服务）；
  等它落地后，`adb reboot` 开始下一轮。

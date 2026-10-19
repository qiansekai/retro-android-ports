# mkbootimg-cooper —— 打过 pagesize 补丁的 Donut mkbootimg

> 中文译文。英文原文见 [mkbootimg-cooper.md](mkbootimg-cooper.md)。技术名词、代码、路径、命令与日志一律保留原文。

`mkbootimg-cooper` 是 AOSP Donut 的 `mkbootimg` 的补丁拷贝，能正确打包 cooper 的 boot
镜像：它加了 `--pagesize`，并把内部填充缓冲区从 2 KB 扩大到 8 KB。

文件：

- `tools/mkbootimg-cooper.c` —— 打过补丁的源码（已入库）
- `tools/mkbootimg-cooper` —— 编译好的宿主机二进制（已入库）
- `tools/mkbootimg-donut-orig` —— 未改动的 Donut 编译产物，用来证明原始源码在现代 GCC 上
  仍能构建
- `patches/donut/mkbootimg-pagesize.patch` —— 同一改动相对
  `system/core/mkbootimg/mkbootimg.c` 的 diff

## 为什么要它

- Donut 的 `mkbootimg` **把 pagesize 写死为 2048**，而且根本没有 `--pagesize` 选项；
  cooper 的 boot 布局需要 **4096**（`BOARD_KERNEL_BASE 0x13600000`，pagesize 4096，
  boot 分区 8 MB）。
- 它还用固定的 **2048 字节** 缓冲区做填充：mkbootimg 从 header 开始零填充到这个边界，
  所以任何更大的 pagesize 都会悄悄产出损坏的镜像。补丁改用 8 KB 缓冲区。

## 构建

由 `scripts/build-cooper-donut-skeleton.py` 从同步下来的 Donut 树编译（该脚本同时构建未改动
的二进制，并断言补丁版接受 `--pagesize`）。手工构建：

```sh
gcc -O2 -Wall -I aosp-donut/system/core/include \
    -I aosp-donut/system/core/mkbootimg \
    -o tools/mkbootimg-cooper tools/mkbootimg-cooper.c \
    aosp-donut/system/core/libmincrypt/sha.c
```

## 用法

`scripts/build-cooper-donut-full.py` 这样调用它：

```sh
tools/mkbootimg-cooper --kernel <kernel> --ramdisk <ramdisk> \
    --base 0x13600000 --pagesize 4096 --board cooper -o boot.img
```

打包脚本随后会断言 header：`ANDROID!` magic、pagesize 4096、内核加载地址
`base + 0x8000`、板名 `cooper`。手工打包时也要照做 —— 并且每次刷写都用回读校验，因为 BML
写入可能静默失败（见 [cooper 怪癖](../../devices/cooper/quirks.zh-CN.md)）。

## KitKat 不需要它

为 maple 预判的等价物（`Image.gz-dtb`，base 0）最终证明是多余的：KitKat 的 mkbootimg 两者
都原生支持，已从构建出的 boot.img 几何布局验证。Donut 时代的变通做法仍只属于 Donut；在动手
实现一个「担心需要」的修复之前先验证（[KitKat 笔记](../porting-notes/kitkat.zh-CN.md)）。

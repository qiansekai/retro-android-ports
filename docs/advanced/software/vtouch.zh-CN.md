# vtouch —— 多点触控转单点触控的输入代理

> 中文译文。英文原文见 [vtouch.md](vtouch.md)。技术名词、代码、路径、命令与日志一律保留原文。

`vtouch` 让**多点触控面板在早于多点触控输入的 Android 版本上工作**（我们是为 Donut 1.6
移植的）。它读取真正的触摸事件节点，创建一个单点触控的 `uinput` 设备，并把触摸以 type-B
（按 slot 分）的单点触控事件中继给它 —— 零框架改动。

源码：[`devices/cooper/donut/vtouch/`](../../../devices/cooper/donut/vtouch/)（vtouch.c +
Android.mk，静态的 ramdisk 二进制）。移植自 MLXProjects 的 Froyo `vtouch` 1.2.0，做了
cooper 适配。

## 为什么需要它

- Cooper 的 Synaptics RMI4 面板**以 protocol type-A 上报**（`SYN_MT_REPORT` 分组，
  X/Y/压力/宽度）**却不声明任何 MT 轴**（`ABS=650000`：只有 HAT 位）。Donut 把这个节点
  归类为仅键盘，于是丢弃所有触摸事件 —— 屏幕干脆毫无反应。（验证方式：在点按期间抓
  `/dev/input/event1` 并解码 `MT_POSITION_X/Y` 53/54。）
- Donut 完全早于多点触控输入协议，所以任何 keylayout 或框架侧技巧都救不回这些事件。

## 工作原理

- 打开源节点 —— 显式指定，或取第一个看起来像多点触控屏的 `/dev/input/event*`（带单点
  触控绝对坐标的退化路径）。
- 创建 `uinput` 设备（`cooper_vtouch`），然后把触摸作为单点触控事件中继：type-A 分组收拢
  到 slot 0；驱动没报出可用范围时，ABS 范围退化用面板的 320×480 HVGA；缺 `/dev/uinput`
  （c 10 223）时会创建它。
- 信号：`SIGUSR1` 重启中继 / 重建虚拟设备，`SIGINT`/`SIGTERM` 恢复原始节点并退出。
  命令行：`vtouch [-r|-q|-h|-v] [source-node]`。

## Cooper 集成（可用）

- 以静态二进制构建并随 ramdisk 发布：`init.gt-s5830.rc` 里的
  `service vtouch /sbin/vtouch /dev/input/event1`；显式路径强制走 MT 模式（自动探测看不到
  缺失的轴）。
- `cooper_vtouch.kl` 映射 MENU/BACK/HOME/SEARCH（BTN_TOUCH 不需要条目 —— Donut 按
  scancode 消费它）。注意 Donut **遇到未知 flag 会整份 `.kl` 文件放弃**：1.6 没有
  `VIRTUAL` flag，用 `WAKE`。
- 破损符号链接的处理很要紧：它修掉了有记录的 Home 键 provisioning 问题，但不解决 keymap
  加载（见 [cooper 怪癖](../../devices/cooper/quirks.zh-CN.md#touchscreen-working)）。
- 调试：`/dev/.vtouch.log`，以及主日志缓冲区里 EventHub 的 `New device` 行
  （`classes=0x5` = 键盘 + 触摸屏）。

## 移植到其它设备

1. 找到源节点并确认失效模式（原始事件解码：type-A 分组却没声明 MT 轴，或是 Donut 无法归类
   的面板）。
2. 如果内核有 `CONFIG_INPUT_UINPUT=y` 但没有设备节点（cooper 就是），在你的 ueventd 规则
   里补上 `/dev/uinput` 节点。
3. 自动探测看不到 caps 时，在 init rc 里用**显式**源路径添加该服务。
4. 在 `vtouch.c` 里适配设备名（`cooper_vtouch`）、坐标退化值（面板分辨率）以及 type-A 与
   type-B 的处理 —— cooper 的注释标出了每一处适配。
5. 为虚拟设备附一个 flag 集合合法的 `.kl`。

## maple 适配（Sony Xperia XZ Premium）

- 源码：`devices/maple/donut/vtouch/vtouch.c`（构建为 `maple_vtouch`，随 ramdisk 发布到
  `/sbin/maple_vtouch`，由 `init.maple.rc` 里的
  `service vtouch /sbin/maple_vtouch /dev/input/event7` 启动；该服务为 disabled，
  在 `init.rc on boot` 中、`class_start default` 之前启动，好让虚拟节点在
  system_server 的 EventHub 打开输入设备之前就顶替 event7）。
- 本移植中的版本：v1.2.0-maple3。在 cooper 基础之上，maple 特有的行为有：
  - MT 轴：clearpad 只声明 MT 轴（ABS_MT_POSITION_X/Y、TOOL_TYPE、TRACKING_ID、
    PRESSURE），既没有 BTN_TOUCH/ABS_X/ABS_Y/ABS_MT_SLOT，又以 protocol type-A 上报；
    分组在 TRACKING_ID >= 0 时提交（pressure/major 作为退化判据），抬笔是一个空分组。
    源范围 0..2159 x 0..3839（为 1080x1920 面板的 2 倍）被照抄到虚拟设备上，由 Donut
    的框架负责缩放。
  - 面板需要用户态推一把：`clearpad_probe` 在 i2c probe 之后停在
    `post_probe_start sysfs is required to start post probe` 不动；vtouch 在完成虚拟节点
    顶替之后、进入中继循环之前，向
    `/sys/devices/virtual/input/clearpad/post_probe_start` 写入 `1`（经由稳定的
    input-class 符号链接，绝不用 `inputN`），并每秒重试 1 次、最多 60 s（该节点在内核时间
    约 2.9 s 时出现，晚于 init 的 `on boot`）。
  - 固件加载卡顿（v1.2.0-maple3）：post probe 的「ensure firmware」步骤会执行
    `request_firmware(touch_module_id_0xd1.img)`；Donut 没有用户态固件 loader，于是每次
    尝试都要耗满 firmware 类 60 s 的兜底超时，而驱动会重试 3 次 —— 触摸要到开机约 184 s
    之后才活过来。vtouch 在 `start_post_probe()` 里第一件事就是把
    `/sys/class/firmware/timeout` 设成 1，让重试快速失败，于是 post probe 约 4 s 就完成。
    已验证该旋钮可写（回读为 1）；端到端计时只在下一次刷入 + 重启之后才验证（驱动拒绝
    重跑：`already post probed, need reboot`）。
  - 已验证的开机证据：dmesg `start post probewith post_probe_start sysfs` ->
    `begin 'post probe' session` -> `ensure firmware` -> 设备 id `PLG1163-C1`
    （family 0xd1、fw rev 0x03.02）-> `end post probe ... (rc=0)`；
    `/dev/.vtouch.log` 显示 `touch panel post probe started (try 0)` +
    `relaying on /dev/input/event7`；`/proc/bus/input/devices` 显示 `maple_vtouch`
    （input8，Handlers event8->event7）携带 BTN_TOUCH + ABS_X/Y，而真正的 `clearpad`
    （input7）被保留为 `/dev/input/vtouch_saved`。

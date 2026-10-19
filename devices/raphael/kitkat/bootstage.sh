#!/system/bin/sh
# Early-boot diagnostic for the KitKat bringup. Writes to /cache (a
# persistent partition) so the log survives a failed boot and a reboot
# into Lineage. The kernel is built with PSTORE_CONSOLE, KALLSYMS and
# PRINTK_TIME so the previous boot's panic/console output is available
# under /sys/fs/pstore.
exec > /cache/bootstage.log 2>&1
echo "=== uptime ==="
cat /proc/uptime
echo "=== cmdline ==="
cat /proc/cmdline
echo "=== mounts ==="
cat /proc/mounts
echo "=== dev ==="
ls -l /dev
echo "=== binder ==="
ls -l /dev/binder /dev/binderfs 2>&1
echo "=== pstore ==="
ls -l /sys/fs/pstore 2>&1
cat /sys/fs/pstore/console-ramoops-0 2>/dev/null
echo "=== props ==="
getprop
echo "=== service state ==="
getprop | grep -i init.svc
echo "=== dmesg ==="
dmesg

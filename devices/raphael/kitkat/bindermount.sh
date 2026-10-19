#!/system/bin/sh
# binder: support both kernel configurations.
# - Lineage kernel: binderfs (CONFIG_ANDROID_BINDERFS=y). Mount it and
#   point /dev/binder at the binderfs node.
# - Rebuilt kernel: plain misc /dev/binder (CONFIG_ANDROID_BINDERFS=n).
#   ueventd creates the node; do NOT replace it with a dangling symlink.
mkdir -p /dev/binderfs
mount -t binder binder /dev/binderfs > /cache/bindermount.log 2>&1
if [ -e /dev/binderfs/binder ]; then
    chmod 0666 /dev/binderfs/binder
    ln -sf /dev/binderfs/binder /dev/binder
    echo "binderfs active" >> /cache/bindermount.log
else
    echo "binderfs absent; keeping misc /dev/binder" >> /cache/bindermount.log
fi
ls -l /dev/binder /dev/binderfs >> /cache/bindermount.log 2>&1

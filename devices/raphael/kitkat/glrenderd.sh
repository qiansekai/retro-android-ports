# Adreno renders the whole UI from the Lineage chroot; see tools/raphael/glrenderd.
# raphael has no fbdev, so the presenter uses DRM/KMS (/dev/dri/card0).
exec /system/glr/hwchroot /system/glr/root /glrenderd 1080 2340 -drm 2>/dev/kmsg

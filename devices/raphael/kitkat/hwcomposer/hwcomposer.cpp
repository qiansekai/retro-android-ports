/*
 * hwcomposer.raphael - minimal HWC 1.1 for the KitKat bringup.
 *
 * Why this exists: raphael has no fbdev (only /dev/dri), and AOSP 4.4's
 * SurfaceFlinger aborts in HWComposer::HWComposer() when there is neither
 * an HWC >= 1.1 nor a framebuffer device. The stock libhardware sample
 * HWC is 1.0 (which still requires fbdev), so this module reports 1.1
 * and does the only thing the port needs:
 *
 *   - prepare: all layers are GLES-composited by SurfaceFlinger
 *   - set:     eglSwapBuffers() on the display's EGL surface; the guest
 *              goldfish EGL stack forwards the frame to glrenderd
 *   - vsync:   a 60 Hz thread calls the registered vsync hook
 *
 * No layer is ever handed to hardware; there is no fbdev and no real
 * composer in the KitKat guest. glrenderd owns the panel.
 */
#include <hardware/hardware.h>
#include <hardware/hwcomposer.h>
#include <hardware/fb.h>

#include <cutils/log.h>
#include <cutils/atomic.h>

#include <EGL/egl.h>

#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define PANEL_WIDTH  1080
#define PANEL_HEIGHT 2340
#define PANEL_VSYNC_NS 16666667LL

struct hwc_context_t {
    hwc_composer_device_1_t device;
    hwc_procs_t const* procs;
    int vsync_enabled;
    volatile int vsync_thread_run;
    pthread_t vsync_thread;
    pthread_mutex_t lock;
};

static int hwc_prepare(hwc_composer_device_1_t* dev,
        size_t numDisplays, hwc_display_contents_1_t** displays)
{
    (void)dev;
    for (size_t d = 0; d < numDisplays; d++) {
        hwc_display_contents_1_t* list = displays ? displays[d] : NULL;
        if (!list)
            continue;
        for (size_t i = 0; i < list->numHwLayers; i++) {
            if (list->hwLayers[i].compositionType == HWC_FRAMEBUFFER_TARGET)
                continue;
            list->hwLayers[i].compositionType = HWC_FRAMEBUFFER;
        }
    }
    return 0;
}

static int hwc_set(hwc_composer_device_1_t* dev,
        size_t numDisplays, hwc_display_contents_1_t** displays)
{
    (void)dev;
    for (size_t d = 0; d < numDisplays; d++) {
        hwc_display_contents_1_t* list = displays ? displays[d] : NULL;
        if (!list)
            continue;
        /* SurfaceFlinger swaps its own EGL surface (the dpy/sur fields
         * are 0xdeadbeef in this path). The composer only has to hand
         * the framebuffer target buffer to the host renderer: the
         * goldfish framebuffer HAL's post is rcFBPost -> glrenderd. */
        hw_module_t const* module = NULL;
        int modRet = hw_get_module(GRALLOC_HARDWARE_MODULE_ID, &module);
        int fbRet = -1;
        int posts = 0;
        if (modRet == 0) {
            framebuffer_device_t* fbDev = NULL;
            fbRet = framebuffer_open(module, &fbDev);
            if (fbRet == 0 && fbDev && fbDev->post) {
                for (size_t i = 0; i < list->numHwLayers; i++) {
                    hwc_layer_1_t* l = &list->hwLayers[i];
                    if (l->compositionType == HWC_FRAMEBUFFER_TARGET && l->handle) {
                        fbDev->post(fbDev, l->handle);
                        posts++;
                    }
                }
                framebuffer_close(fbDev);
            }
        }
        FILE* lf = fopen("/cache/hwc.log", "a");
        if (lf) {
            fprintf(lf, "set layers=%zu mod=%d fb=%d posts=%d\n",
                    list->numHwLayers, modRet, fbRet, posts);
            fclose(lf);
        }
    }
    return 0;
}

static void* vsync_main(void* arg)
{
    hwc_context_t* ctx = (hwc_context_t*)arg;

    while (ctx->vsync_thread_run) {
        /* bionic 4.4 has no clock_nanosleep(); a relative sleep is enough
         * for a fake 60 Hz vsync source. */
        usleep(PANEL_VSYNC_NS / 1000);
        if (!ctx->vsync_thread_run || !ctx->vsync_enabled)
            continue;
        if (ctx->procs && ctx->procs->vsync) {
            struct timespec now;
            clock_gettime(CLOCK_MONOTONIC, &now);
            int64_t ts = (int64_t)now.tv_sec * 1000000000LL + now.tv_nsec;
            ctx->procs->vsync(ctx->procs, HWC_DISPLAY_PRIMARY, ts);
        }
    }
    return NULL;
}

static int hwc_eventControl(hwc_composer_device_1_t* dev, int disp,
        int event, int enabled)
{
    hwc_context_t* ctx = (hwc_context_t*)dev;
    if (event != HWC_EVENT_VSYNC)
        return -EINVAL;
    if (disp != HWC_DISPLAY_PRIMARY)
        return -EINVAL;
    pthread_mutex_lock(&ctx->lock);
    ctx->vsync_enabled = enabled ? 1 : 0;
    pthread_mutex_unlock(&ctx->lock);
    return 0;
}

static int hwc_blank(hwc_composer_device_1_t* dev, int disp, int blank)
{
    (void)dev; (void)disp; (void)blank;
    return 0;
}

static int hwc_query(hwc_composer_device_1_t* dev, int what, int* value)
{
    (void)dev;
    switch (what) {
    case HWC_DISPLAY_WIDTH:      *value = PANEL_WIDTH;  return 0;
    case HWC_DISPLAY_HEIGHT:     *value = PANEL_HEIGHT; return 0;
    case HWC_DISPLAY_VSYNC_PERIOD: *value = (int)(PANEL_VSYNC_NS / 1000); return 0;
    case HWC_DISPLAY_DPI_X:      *value = 440 * 65536;  return 0;
    case HWC_DISPLAY_DPI_Y:      *value = 440 * 65536;  return 0;
    default:                     return -EINVAL;
    }
}

static void hwc_registerProcs(hwc_composer_device_1_t* dev,
        hwc_procs_t const* procs)
{
    hwc_context_t* ctx = (hwc_context_t*)dev;
    ctx->procs = procs;
}

static void hwc_dump(hwc_composer_device_1_t* dev, char* buff, int buff_len)
{
    (void)dev;
    snprintf(buff, buff_len, "hwcomposer.raphael: %dx%d, GLES composition\n",
            PANEL_WIDTH, PANEL_HEIGHT);
}

static int hwc_getDisplayConfigs(hwc_composer_device_1_t* dev, int disp,
        uint32_t* configs, size_t* numConfigs)
{
    (void)dev;
    if (disp != HWC_DISPLAY_PRIMARY)
        return -EINVAL;
    if (*numConfigs > 0 && configs)
        configs[0] = 0;
    *numConfigs = 1;
    return 0;
}

static int hwc_getDisplayAttributes(hwc_composer_device_1_t* dev, int disp,
        uint32_t config, const uint32_t* attributes, int32_t* values)
{
    (void)dev;
    if (disp != HWC_DISPLAY_PRIMARY || config != 0)
        return -EINVAL;
    for (int i = 0; attributes[i] != HWC_DISPLAY_NO_ATTRIBUTE; i++) {
        switch (attributes[i]) {
        case HWC_DISPLAY_WIDTH:       values[i] = PANEL_WIDTH;  break;
        case HWC_DISPLAY_HEIGHT:      values[i] = PANEL_HEIGHT; break;
        case HWC_DISPLAY_VSYNC_PERIOD: values[i] = (int32_t)(PANEL_VSYNC_NS / 1000); break;
        case HWC_DISPLAY_DPI_X:       values[i] = 440 * 65536;  break;
        case HWC_DISPLAY_DPI_Y:       values[i] = 440 * 65536;  break;
        default:                      values[i] = 0;            break;
        }
    }
    return 0;
}

static int hwc_device_close(struct hw_device_t* dev)
{
    hwc_context_t* ctx = (hwc_context_t*)dev;
    if (ctx) {
        ctx->vsync_thread_run = 0;
        pthread_join(ctx->vsync_thread, NULL);
        pthread_mutex_destroy(&ctx->lock);
        free(ctx);
    }
    return 0;
}

static int hwc_device_open(const struct hw_module_t* module, const char* name,
        struct hw_device_t** device)
{
    if (strcmp(name, HWC_HARDWARE_COMPOSER))
        return -EINVAL;

    hwc_context_t* ctx = (hwc_context_t*)calloc(1, sizeof(*ctx));
    if (!ctx)
        return -ENOMEM;

    pthread_mutex_init(&ctx->lock, NULL);
    ctx->vsync_thread_run = 1;
    if (pthread_create(&ctx->vsync_thread, NULL, vsync_main, ctx) != 0) {
        free(ctx);
        return -EINVAL;
    }

    ctx->device.common.tag = HARDWARE_DEVICE_TAG;
    ctx->device.common.version = HWC_DEVICE_API_VERSION_1_1;
    ctx->device.common.module = const_cast<hw_module_t*>(module);
    ctx->device.common.close = hwc_device_close;
    ctx->device.prepare = hwc_prepare;
    ctx->device.set = hwc_set;
    ctx->device.eventControl = hwc_eventControl;
    ctx->device.blank = hwc_blank;
    ctx->device.query = hwc_query;
    ctx->device.registerProcs = hwc_registerProcs;
    ctx->device.dump = hwc_dump;
    ctx->device.getDisplayConfigs = hwc_getDisplayConfigs;
    ctx->device.getDisplayAttributes = hwc_getDisplayAttributes;

    *device = &ctx->device.common;
    return 0;
}

static struct hw_module_methods_t hwc_module_methods = {
    open: hwc_device_open
};

hwc_module_t HAL_MODULE_INFO_SYM = {
    common: {
        tag: HARDWARE_MODULE_TAG,
        version_major: 1,
        version_minor: 0,
        id: HWC_HARDWARE_MODULE_ID,
        name: "raphael minimal HWC 1.1",
        author: "retro-android-ports",
        methods: &hwc_module_methods,
    }
};

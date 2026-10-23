/*
 * 简易 LED 测试：
 *   阶段 1：白色单颗依序轮流亮起（一次只亮一颗）
 *   阶段 2：白色依序逐颗点亮，越亮越多直到全亮
 * 两阶段循环执行。
 */

#include <string.h>

#include <zephyr/device.h>
#include <zephyr/kernel.h>
#include <zephyr/drivers/led_strip.h>
#include <zephyr/logging/log.h>

#include <drivers/ext_power.h>

LOG_MODULE_REGISTER(led_test, CONFIG_ZMK_LOG_LEVEL);

#define STRIP_NODE DT_CHOSEN(zmk_underglow)
#define STRIP_NUM_PIXELS DT_PROP(STRIP_NODE, chain_length)

#define STEP_MS CONFIG_PANDAKB_LED_TEST_STEP_MS
#define WHITE CONFIG_PANDAKB_LED_TEST_BRIGHTNESS

static const struct device *const strip = DEVICE_DT_GET(STRIP_NODE);
static struct led_rgb pixels[STRIP_NUM_PIXELS];

static void show(void) {
    int rc = led_strip_update_rgb(strip, pixels, STRIP_NUM_PIXELS);
    if (rc) {
        LOG_ERR("led_strip_update_rgb failed: %d", rc);
    }
}

static void clear(void) { memset(pixels, 0, sizeof(pixels)); }

static void set_white(int i) {
    pixels[i] = (struct led_rgb){.r = WHITE, .g = WHITE, .b = WHITE};
}

// LED 供电由 nice!nano 的 EXT_POWER 控制，可能被设定存成关闭，确保打开
static void ensure_ext_power(void) {
#if IS_ENABLED(CONFIG_ZMK_EXT_POWER) && DT_HAS_COMPAT_STATUS_OKAY(zmk_ext_power_generic)
    const struct device *ext_power = DEVICE_DT_GET(DT_INST(0, zmk_ext_power_generic));
    if (device_is_ready(ext_power) && ext_power_get(ext_power) <= 0) {
        ext_power_enable(ext_power);
    }
#endif
}

static void led_test_thread(void *p1, void *p2, void *p3) {
    if (!device_is_ready(strip)) {
        LOG_ERR("LED strip %s not ready", strip->name);
        return;
    }

    LOG_INF("LED test start, %d pixels", STRIP_NUM_PIXELS);

    while (true) {
        ensure_ext_power();

        // 阶段 1：一次只亮一颗，依序轮流
        for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
            clear();
            set_white(i);
            show();
            k_msleep(STEP_MS);
        }

        // 阶段 2：依序逐颗点亮，越亮越多
        clear();
        for (int i = 0; i < STRIP_NUM_PIXELS; i++) {
            set_white(i);
            show();
            k_msleep(STEP_MS);
        }
        k_msleep(STEP_MS * 5);

        clear();
        show();
        k_msleep(STEP_MS * 5);
    }
}

// 延迟启动，等 ext_power 与设定载入完成
K_THREAD_DEFINE(led_test_tid, 1024, led_test_thread, NULL, NULL, NULL,
                K_LOWEST_APPLICATION_THREAD_PRIO, 0, 1000);

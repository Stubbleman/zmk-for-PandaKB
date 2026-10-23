# LED 测试固件（仅在 CONFIG_PANDAKB_LED_TEST=y 时编译）
target_sources_ifdef(CONFIG_PANDAKB_LED_TEST app PRIVATE src/led_test.c)

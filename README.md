![image](https://github.com/Penguinchat/zmk-for-PandaKB.com-/blob/Description/images/Lily58_keymap.svg)

# PandaKB Lily58 ZMK 設定

ZMK v0.3（Zephyr 3.5），nice!nano v2，左右手皆為 nice!oled。

## 韌體一覽

編譯目標都定義在 [`build.yaml`](build.yaml)，CI 與本地編譯共用同一份。

| Artifact | 用途 |
| --- | --- |
| `Lily58_left_oled` | 左手（主控，central） |
| `Lily58_right_oled` | 右手 |
| `Lily58_left_led_test` | 左手 LED 測試：白光單顆依序輪流 → 逐顆累加到全亮，循環。RGB underglow 關閉 |
| `settings_reset-nice_nano_v2` | 清除設定與藍牙配對 |

## GitHub CI 編譯

push 到有變更 `boards/`、`config/`、`src/`、`zephyr/`、`Kconfig`、`CMakeLists.txt`、`build.yaml` 時自動編譯，也可在 Actions 頁手動觸發。產物在該次 run 的 Artifacts。

## 本地編譯（Windows / Git Bash）

### 一次編譯全部

```sh
scripts/build_all.sh
```

會依序編譯 `build.yaml` 裡的每個項目，參數與 CI 相同。完成後列出成功／失敗清單：

- 韌體：`.zmk/firmware/<artifact>.uf2`
- 編譯 log：`.zmk/build/<artifact>.log`

### 只編譯部分

傳入關鍵字，只編譯 artifact 名稱含該字串的項目：

```sh
scripts/build_all.sh led_test          # 只編 LED 測試
scripts/build_all.sh left_oled right   # 一般左手 + 右手
```

### 單獨下 west 指令

```sh
cd .zmk
. ./env.sh
west build -p -s zmk/app -d build/left -b nice_nano_v2 -S studio-rpc-usb-uart -- \
  -DZMK_CONFIG=C:/Users/JacobWu/Project/zmk-for-PandaKB/config \
  -DZMK_EXTRA_MODULES=C:/Users/JacobWu/Project/zmk-for-PandaKB \
  "-DSHIELD=Lily58_L nice_oled"
```

LED 測試再加上 `-DCONFIG_ZMK_RGB_UNDERGLOW=n -DCONFIG_PANDAKB_LED_TEST=y`。
可調參數：`-DCONFIG_PANDAKB_LED_TEST_STEP_MS=200`（每步間隔）、`-DCONFIG_PANDAKB_LED_TEST_BRIGHTNESS=64`（白光亮度 1–255）。

## 本地環境安裝（只需一次）

`.zmk/` 是 west workspace，已列入 `.gitignore`。

1. **Python venv + west**

   ```sh
   cd .zmk
   py -3 -m venv .venv
   .venv/Scripts/python -m pip install west
   ```

2. **抓 ZMK / Zephyr / 模組**（manifest 為 `.zmk/config/west.yml`，與 `config/west.yml` 相同）

   ```sh
   .venv/Scripts/west update --narrow -o=--depth=1
   .venv/Scripts/west zephyr-export
   ```

3. **Python 套件**

   ```sh
   .venv/Scripts/python -m pip install -r zephyr/scripts/requirements-base.txt
   .venv/Scripts/python -m pip install "setuptools<80" protobuf grpcio-tools
   ```

   `setuptools<80` 是因為 nanopb 仍需 `pkg_resources`。

4. **Ninja**

   ```sh
   winget install --id Ninja-build.Ninja -e
   ```

5. **Zephyr SDK 0.16.8（只需 ARM toolchain）**，解壓到 `C:\zephyr-sdk-0.16.8`：
   - `zephyr-sdk-0.16.8_windows-x86_64_minimal.7z`
   - `toolchain_windows-x86_64_arm-zephyr-eabi.7z`（解壓到 SDK 目錄內）

   下載：<https://github.com/zephyrproject-rtos/sdk-ng/releases/tag/v0.16.8>

6. **Windows 專用修補**：編輯 `.zmk/zephyr/modules/lvgl/CMakeLists.txt`，把下面這行註解掉：

   ```cmake
   # zephyr_compile_definitions(LV_CONF_PATH=${CMAKE_CURRENT_SOURCE_DIR}/include/lv_conf.h)
   ```

   原因：路徑開頭的 `C:` 會被 ZMK 按鍵巨集 `C` 展開，nice_oled 編譯失敗。註解後改用 `LV_CONF_INCLUDE_SIMPLE`，結果相同。**`west update` 後若被還原需重做。**

## 刷寫

雙擊 nice!nano 的 reset 進入 bootloader（出現 `NICENANO` 磁碟），把對應 `.uf2` 拖進去。
LED 測試完記得刷回 `Lily58_left_oled`。

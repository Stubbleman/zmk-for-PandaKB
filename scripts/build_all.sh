#!/usr/bin/env bash
# 本地编译 build.yaml 中的所有固件（参数与 GitHub CI 相同）
#
# 用法（Git Bash，在 repo 根目录）：
#   scripts/build_all.sh                 # 编译全部
#   scripts/build_all.sh led_test right  # 只编译 artifact 名称含这些关键字的项目
#
# 产物：.zmk/firmware/<artifact-name>.uf2

set -u

# REPO 为 Windows 路径 (C:/...) 供 CMake 使用；PATH 需用 POSIX 路径，否则 "C:" 的冒号会切断 PATH
REPO=$(cd "$(dirname "$0")/.." && pwd -W)
REPO_POSIX=$(cd "$(dirname "$0")/.." && pwd)
WS="$REPO/.zmk"

NINJA_DIR="$HOME/AppData/Local/Microsoft/WinGet/Packages/Ninja-build.Ninja_Microsoft.Winget.Source_8wekyb3d8bbwe"
export PATH="$REPO_POSIX/.zmk/.venv/Scripts:$NINJA_DIR:$PATH"
export ZEPHYR_BASE="$WS/zephyr"
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR="${ZEPHYR_SDK_INSTALL_DIR:-C:/zephyr-sdk-0.16.8}"

cd "$WS" || exit 1
mkdir -p build firmware

# 每行: name|board|shield|snippet|cmake-args
targets=$(python -I - "$REPO/build.yaml" <<'EOF'
import sys, yaml
for t in yaml.safe_load(open(sys.argv[1], encoding="utf-8"))["include"]:
    board, shield = t["board"], t.get("shield", "")
    name = t.get("artifact-name") or (shield.replace(" ", "-") + "-" + board if shield else board)
    print("|".join([name, board, shield, t.get("snippet", ""), t.get("cmake-args", "")]))
EOF
) || exit 1

ok=(); failed=()
while IFS='|' read -r name board shield snippet cmake_args; do
    if [ $# -gt 0 ]; then
        match=0
        for f in "$@"; do [[ "$name" == *"$f"* ]] && match=1; done
        [ $match -eq 1 ] || continue
    fi

    echo "==> $name"
    args=(-p -s zmk/app -d "build/$name" -b "$board")
    [ -n "$snippet" ] && args+=(-S "$snippet")
    args+=(-- "-DZMK_CONFIG=$REPO/config" "-DZMK_EXTRA_MODULES=$REPO")
    [ -n "$shield" ] && args+=("-DSHIELD=$shield")
    # shellcheck disable=SC2206
    [ -n "$cmake_args" ] && args+=($cmake_args)

    if west build "${args[@]}" > "build/$name.log" 2>&1; then
        cp "build/$name/zephyr/zmk.uf2" "firmware/$name.uf2"
        grep -E "FLASH:|RAM:" "build/$name.log" | sed 's/^/    /'
        ok+=("$name")
    else
        echo "    FAILED, see .zmk/build/$name.log"
        grep -m5 -iE "error" "build/$name.log" | sed 's/^/    /'
        failed+=("$name")
    fi
done <<< "$targets"

echo
echo "OK (${#ok[@]}): ${ok[*]:-}"
echo "FAILED (${#failed[@]}): ${failed[*]:-}"
echo "UF2: $WS/firmware"
[ ${#failed[@]} -eq 0 ]

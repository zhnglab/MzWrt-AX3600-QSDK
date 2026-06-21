#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QSDK_DIR="${QSDK_DIR:-$PROJECT_DIR/qsdk}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR/output}"
QSDK_REPO="${QSDK_REPO:-https://github.com/FanFansfan/qsdk-5.4.git}"
QSDK_REF="${QSDK_REF:-master}"

if [ ! -d "$QSDK_DIR/.git" ]; then
  git clone --depth 1 --branch "$QSDK_REF" "$QSDK_REPO" "$QSDK_DIR"
fi

cd "$QSDK_DIR"
git rev-parse HEAD | tee "$PROJECT_DIR/source-commit.txt"

./scripts/feeds update -a
./scripts/feeds install -a

mkdir -p files
cp -a "$PROJECT_DIR/overlay/." files/
chmod 0755 files/etc/uci-defaults/99-mzwrt-ax3600

KERNEL_CONFIG="target/linux/ipq807x/generic/config-default"
if ! grep -q '^# CONFIG_MHI_BUS_TEST is not set$' "$KERNEL_CONFIG"; then
  printf '\n# Keep the legacy AX3600 kernel configuration noninteractive.\n# CONFIG_MHI_BUS_TEST is not set\n' >> "$KERNEL_CONFIG"
fi
grep -q '^# CONFIG_MHI_BUS_TEST is not set$' "$KERNEL_CONFIG"

cp "$PROJECT_DIR/configs/ax3600.config" .config
make defconfig

if ! grep -q '^CONFIG_TARGET_ipq807x=y' .config; then
  echo "ipq807x target was not selected" >&2
  exit 1
fi

if ! grep -Eq '^CONFIG_TARGET_ipq807x(_generic)?_DEVICE_xiaomi_ax3600=y' .config; then
  echo "AX3600 device symbol was not accepted. Available AX3600 symbols:" >&2
  grep -R "xiaomi_ax3600" .config target/linux/ipq807x tmp 2>/dev/null | head -100 >&2 || true
  exit 1
fi

for package in luci-app-openclash luci-theme-argon; do
  grep -q "^CONFIG_PACKAGE_${package}=y" .config || {
    echo "$package was not selected" >&2
    exit 1
  }
done

if grep -Eq '^CONFIG_PACKAGE_luci-app-passwall2?=y' .config; then
  echo "PassWall was unexpectedly selected" >&2
  exit 1
fi

./scripts/diffconfig.sh | tee "$PROJECT_DIR/final.config"

make download -j8 V=s
find dl -type f -size -1024c -print -delete || true

if ! make -j"$(nproc)" V=s 2>&1 | tee "$PROJECT_DIR/build.log"; then
  echo "Parallel build failed; retrying serially for a precise error" >&2
  make -j1 V=s 2>&1 | tee -a "$PROJECT_DIR/build.log"
fi

TARGET_DIR="$QSDK_DIR/bin/targets/ipq807x/generic"
FACTORY="$(find "$TARGET_DIR" -maxdepth 1 -type f -iname '*xiaomi*ax3600*nand-factory*.bin' | head -1)"
SYSUPGRADE="$(find "$TARGET_DIR" -maxdepth 1 -type f -iname '*xiaomi*ax3600*nand-sysupgrade*.bin' | head -1)"

if [ -z "$FACTORY" ] || [ -z "$SYSUPGRADE" ]; then
  echo "Expected AX3600 images were not produced" >&2
  find "$TARGET_DIR" -maxdepth 1 -type f -printf '%f\n' >&2 || true
  exit 1
fi

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
STAMP="$(date -u +%Y%m%d)"
cp "$FACTORY" "$OUTPUT_DIR/MzWRT-AX3600-${STAMP}-nand-factory.bin"
cp "$SYSUPGRADE" "$OUTPUT_DIR/MzWRT-AX3600-${STAMP}-nand-sysupgrade.bin"
cp "$PROJECT_DIR/source-commit.txt" "$PROJECT_DIR/final.config" "$OUTPUT_DIR/"

MANIFEST="$(find "$TARGET_DIR" -maxdepth 1 -type f -name '*.manifest' | head -1)"
if [ -n "$MANIFEST" ]; then
  cp "$MANIFEST" "$OUTPUT_DIR/packages.manifest"
else
  grep '^CONFIG_PACKAGE_.*=y' .config | sort > "$OUTPUT_DIR/packages.manifest"
fi

if grep -Ei '(^|[[:space:]])luci-app-passwall2?([[:space:]]|$)' "$OUTPUT_DIR/packages.manifest"; then
  echo "PassWall found in final manifest" >&2
  exit 1
fi

grep -Ei 'luci-app-openclash' "$OUTPUT_DIR/packages.manifest"
grep -Ei 'luci-theme-argon' "$OUTPUT_DIR/packages.manifest"

(
  cd "$OUTPUT_DIR"
  sha256sum MzWRT-AX3600-* > SHA256SUMS
)

printf 'Build output:\n'
find "$OUTPUT_DIR" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort

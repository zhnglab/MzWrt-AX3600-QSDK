#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-.}"
DEFAULTS="$ROOT/overlay/etc/uci-defaults/99-mzwrt-ax3600"
BANNER="$ROOT/overlay/etc/banner"

required_strings=(
  "192.168.88.1"
  "MzWRT"
  "Mr.Zhang"
  "Mr.Wrt"
  "/luci-static/argon"
)

for value in "${required_strings[@]}"; do
  grep -Fq "$value" "$DEFAULTS" || {
    echo "Missing customization: $value" >&2
    exit 1
  }
done

grep -Fq "MzWRT AX3600 by Mr.Zhang" "$BANNER"

grep -Fq "CONFIG_PACKAGE_luci-app-openclash=y" "$ROOT/configs/ax3600.config"
grep -Fq "CONFIG_PACKAGE_luci-theme-argon=y" "$ROOT/configs/ax3600.config"

if grep -Eq '^CONFIG_PACKAGE_luci-app-passwall2?=y' "$ROOT/configs/ax3600.config"; then
  echo "PassWall must not be enabled" >&2
  exit 1
fi

echo "MzWRT AX3600 customization verification passed"

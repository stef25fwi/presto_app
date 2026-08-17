#!/usr/bin/env bash
set -euo pipefail

API_LEVEL="${ANDROID_API_LEVEL:-36}"
MODE="${1:-platform}"
SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"

if [[ -z "${SDK_ROOT}" || ! -d "${SDK_ROOT}" ]]; then
  echo "::error::ANDROID_SDK_ROOT/ANDROID_HOME introuvable."
  exit 1
fi

SDKMANAGER="$(command -v sdkmanager || true)"
if [[ -z "${SDKMANAGER}" ]]; then
  SDKMANAGER="$(find "${SDK_ROOT}/cmdline-tools" -type f -name sdkmanager -print -quit 2>/dev/null || true)"
fi

if [[ -z "${SDKMANAGER}" || ! -x "${SDKMANAGER}" ]]; then
  echo "::error::sdkmanager introuvable sous ${SDK_ROOT}."
  find "${SDK_ROOT}" -maxdepth 4 -type f -name sdkmanager -print 2>/dev/null || true
  exit 1
fi

echo "sdkmanager=${SDKMANAGER}"
echo "Android SDK root=${SDK_ROOT}"

yes | "${SDKMANAGER}" --licenses >/dev/null || true

packages=(
  "platform-tools"
  "platforms;android-${API_LEVEL}"
)

if [[ "${MODE}" == "emulator" ]]; then
  packages+=(
    "emulator"
    "system-images;android-${API_LEVEL};google_apis;x86_64"
  )
elif [[ "${MODE}" != "platform" ]]; then
  echo "::error::Mode inconnu: ${MODE} (attendu: platform|emulator)."
  exit 2
fi

"${SDKMANAGER}" "${packages[@]}"

PLATFORM_DIR="${SDK_ROOT}/platforms/android-${API_LEVEL}"
if [[ ! -d "${PLATFORM_DIR}" ]]; then
  echo "::error::La plateforme Android API ${API_LEVEL} n'a pas été installée."
  exit 1
fi

echo "✅ Android API ${API_LEVEL} disponible dans ${PLATFORM_DIR}"

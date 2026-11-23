#!/usr/bin/env bash
# Shared helper. FLUTTER_BIN can be the path to an FVM-managed flutter binary.
if [[ -n "${FLUTTER_BIN:-}" ]]; then
  FLUTTER=("$FLUTTER_BIN")
elif [[ -x .fvm/flutter_sdk/bin/flutter ]]; then
  FLUTTER=("$(cd .fvm/flutter_sdk/bin && pwd)/flutter")
elif [[ -f .fvmrc || -f .fvm/fvm_config.json ]] && command -v fvm >/dev/null 2>&1; then
  FLUTTER=(fvm flutter)
elif command -v flutter >/dev/null 2>&1; then
  FLUTTER=(flutter)
else
  echo "ERROR: Flutter is not in PATH. Set FLUTTER_BIN to your Flutter binary or use your configured FVM terminal." >&2
  exit 1
fi

# Use the Dart SDK from the same Flutter installation for local profile checks.
check_profile() {
  local flutter_path dart_bin
  if [[ "${FLUTTER[0]}" == fvm ]]; then
    fvm dart "$ROOT/tools/check_profile.dart" "$1"
  else
    flutter_path=$(command -v "${FLUTTER[0]}")
    dart_bin="$(dirname "$flutter_path")/dart"
    if [[ ! -x "$dart_bin" ]]; then dart_bin=dart; fi
    "$dart_bin" "$ROOT/tools/check_profile.dart" "$1"
  fi
}

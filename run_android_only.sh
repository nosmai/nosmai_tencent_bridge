#!/usr/bin/env bash
# TENCENT_ANDROID_ONLY_RUNNER_V1
# Only ready physical Android/Android wireless devices from ADB are eligible.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
PROFILE="${1:-host}"
REQUESTED="${2:-}"
if [[ $# -gt 2 || ( "$PROFILE" != host && "$PROFILE" != viewer ) ]]; then
  echo 'Usage: bash run_android_only.sh host [ANDROID_SERIAL]'
  echo '       bash run_android_only.sh viewer [ANDROID_SERIAL]'
  exit 2
fi
[[ -f run.sh && -f config/"$PROFILE".json ]] || {
  echo "ERROR: run.sh or config/$PROFILE.json missing. Copy the matching profile template and enter your Tencent credentials." >&2
  exit 1
}
sdk_dir=''
if [[ -r android/local.properties ]]; then
  sdk_dir=$(sed -n 's/^[[:space:]]*sdk\.dir=//p' android/local.properties | head -n 1)
  sdk_dir=$(printf '%s' "$sdk_dir" | sed 's/\\\([ :\\]\)/\1/g')
fi
ADB=''
for sdk_root in "$sdk_dir" "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Library/Android/sdk"; do
  if [[ -n "$sdk_root" && -x "$sdk_root/platform-tools/adb" ]]; then
    ADB="$sdk_root/platform-tools/adb"
    break
  fi
done
if [[ -z "$ADB" ]]; then
  ADB=$(command -v adb) || { echo 'Android SDK platform-tools/adb is required.' >&2; exit 1; }
fi
"$ADB" start-server
LIST="$("$ADB" devices -l)"
printf '\n%s\n\n' "$LIST"
IDS=()
while IFS= read -r serial; do
  [[ -n "$serial" ]] && IDS+=("$serial")
done < <(printf '%s\n' "$LIST" | awk '$2 == "device" && $1 !~ /^emulator-/ { print $1 }')
if [[ ${#IDS[@]} -eq 0 ]]; then
  echo 'STOP: No ready physical Android phone detected by ADB.' >&2
  echo 'unauthorized: unlock the phone and accept Allow USB debugging.' >&2
  echo 'offline/empty list: reconnect the data cable and check USB debugging.' >&2
  echo 'No iPhone, macOS, Chrome, or emulator will be selected.' >&2
  exit 3
fi
SERIAL=''
if [[ -n "$REQUESTED" ]]; then
  for item in "${IDS[@]}"; do
    if [[ "$item" == "$REQUESTED" ]]; then SERIAL="$item"; break; fi
  done
  [[ -n "$SERIAL" ]] || { echo "STOP: $REQUESTED is not a ready physical Android device." >&2; exit 3; }
elif [[ ${#IDS[@]} -eq 1 ]]; then
  SERIAL="${IDS[0]}"
else
  echo "Select the Android phone for the $PROFILE profile:"
  for ((i=0; i<${#IDS[@]}; i++)); do printf '  %d) %s\n' "$((i+1))" "${IDS[$i]}"; done
  printf 'Phone number: '
  read -r PICK
  INDEX=-1
  for ((i=0; i<${#IDS[@]}; i++)); do
    if [[ "$PICK" == "$((i+1))" ]]; then INDEX="$i"; break; fi
  done
  [[ "$INDEX" -ge 0 ]] || { echo 'STOP: Invalid selection.' >&2; exit 2; }
  SERIAL="${IDS[$INDEX]}"
fi
[[ "$("$ADB" -s "$SERIAL" get-state)" == device ]] || {
  echo 'STOP: Selected Android disconnected. Reconnect it and retry.' >&2; exit 3;
}
printf '\nProfile: %s | Android device: %s\n' "$PROFILE" "$SERIAL"
exec bash "$ROOT/run.sh" "$PROFILE" "$SERIAL"

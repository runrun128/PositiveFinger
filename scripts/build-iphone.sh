#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${PF_DEVICE_BUILD_DIR:-$project_root/.build/device-run}"
device_id="${1:-}"

if [[ -z "$device_id" ]]; then
    device_list="$(mktemp -t positivefinger-devices)"
    trap 'rm -f "$device_list"' EXIT
    xcrun xcdevice list --timeout 5 > "$device_list"
    device_id="$(python3 -c '
import json, sys
devices = [d for d in json.load(open(sys.argv[1]))
           if not d.get("simulator") and d.get("available")
           and d.get("platform") == "com.apple.platform.iphoneos"]
if len(devices) != 1:
    sys.exit("Connect exactly one unlocked iPhone, or pass its UDID as the first argument.")
print(devices[0]["identifier"])
' "$device_list")"
fi

package_options=(-skipPackageUpdates)
package_cache="${PF_PACKAGE_CACHE:-/private/tmp/pf-packages}"
if [[ -d "$package_cache" ]]; then
    package_options+=(-clonedSourcePackagesDirPath "$package_cache")
fi

mkdir -p "$build_dir"
build_log="$build_dir/build.log"
echo "Building PositiveFinger for the connected iPhone..."
if ! xcodebuild -IDEPlatformCoordinatorIgnoreSimulatorStatus=YES \
    -project "$project_root/PositiveFinger.xcodeproj" \
    -scheme PositiveFinger -configuration Debug -sdk iphoneos \
    -destination "platform=iOS,id=$device_id" \
    -derivedDataPath "$build_dir" "${package_options[@]}" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
    'EXCLUDED_SOURCE_FILE_NAMES=*.xcassets' build > "$build_log" 2>&1; then
    tail -n 60 "$build_log"
    exit 1
fi

app="$build_dir/Build/Products/Debug-iphoneos/PositiveFinger.app"
codesign --verify --deep --strict "$app"
printf '\nSigned build succeeded.\n%s\n' "$app"
printf '\nInstall with Xcode: Window > Devices and Simulators > device > Installed Apps (+).\n'
printf 'After installation, open Positive Finger on the iPhone.\n'

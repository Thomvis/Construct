#!/usr/bin/env bash
set -euo pipefail

plist_path="App/App/GoogleService-Info.plist"

if [[ -n "${GOOGLE_SERVICE_INFO_PLIST_BASE64:-}" ]]; then
  echo "$GOOGLE_SERVICE_INFO_PLIST_BASE64" | base64 --decode > "$plist_path"
  echo "Using GoogleService-Info.plist from GOOGLE_SERVICE_INFO_PLIST_BASE64"
elif [[ -n "${GOOGLE_SERVICE_INFO_PLIST:-}" ]]; then
  printf '%s' "$GOOGLE_SERVICE_INFO_PLIST" > "$plist_path"
  echo "Using GoogleService-Info.plist from GOOGLE_SERVICE_INFO_PLIST"
elif [[ -f "$plist_path" ]]; then
  echo "Using existing $plist_path"
else
  printf '%s\n' \
    '<?xml version="1.0" encoding="UTF-8"?>' \
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
    '<plist version="1.0">' \
    '<dict>' \
    '  <key>API_KEY</key>' \
    '  <string>ci-placeholder-api-key</string>' \
    '  <key>BUNDLE_ID</key>' \
    '  <string>me.thomasvisser.construct5e</string>' \
    '  <key>GCM_SENDER_ID</key>' \
    '  <string>000000000000</string>' \
    '  <key>GOOGLE_APP_ID</key>' \
    '  <string>1:000000000000:ios:ci-placeholder</string>' \
    '  <key>IS_ADS_ENABLED</key>' \
    '  <false/>' \
    '  <key>IS_ANALYTICS_ENABLED</key>' \
    '  <false/>' \
    '  <key>IS_APPINVITE_ENABLED</key>' \
    '  <false/>' \
    '  <key>IS_GCM_ENABLED</key>' \
    '  <false/>' \
    '  <key>IS_SIGNIN_ENABLED</key>' \
    '  <false/>' \
    '  <key>PLIST_VERSION</key>' \
    '  <string>1</string>' \
    '  <key>PROJECT_ID</key>' \
    '  <string>construct-ci</string>' \
    '  <key>STORAGE_BUCKET</key>' \
    '  <string>construct-ci.appspot.com</string>' \
    '</dict>' \
    '</plist>' > "$plist_path"
  echo "Using generated CI placeholder GoogleService-Info.plist"
fi

plutil -lint "$plist_path"

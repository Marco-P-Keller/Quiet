#!/bin/bash
#
# Photograph every screen the listing is cut from, in every language the app
# speaks, at the size App Store Connect demands.
#
# This is the `Screenshots` workflow's "Photograph for the store" step, run on
# a machine somebody is sitting at. CI can do it too; what CI cannot do is let
# you look at the result and shoot it again ten seconds later, which is most of
# what taking a screenshot is.
#
#     Tools/photograph-for-the-store.sh                  # all six languages
#     Tools/photograph-for-the-store.sh de fr            # only these
#     Tools/photograph-for-the-store.sh --extras en      # and the spare scenes
#
# Output goes to `Tools/shots/fresh/<language>/`, never straight into
# `Tools/shots/source/`, because source is what the slides are cut from and is
# tracked: a bad run should cost a look, not a `git checkout`. Move them across
# when you have looked at them.
#
# **The language is set on the device and booted into, not passed to the app.**
# `-AppleLanguages (de)` as a launch argument is what every recipe on the
# internet gives and it does nothing here; the workflow that used to do it that
# way produced four German screenshots that were byte-for-byte the English
# ones. So every language costs one reboot, and the run ends by comparing the
# files: identical ones mean the language never changed, which is the failure
# this whole script is arranged around.
#
# What it cannot photograph is the feed, because a feed needs an account and no
# simulator here has one. Those two frames come off a real phone — see
# `Tools/store-shots/README.md`.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(dirname "$HERE")"
OUT="$HERE/shots/fresh"
APP_ID="com.connexa.quiet"

# The 6.9-inch iPhone, and only it: 1320 x 2868 is the size the store wants and
# a smaller screenshot is rejected on upload rather than scaled.
DEVICE="${QUIET_DEVICE:-iPhone 17 Pro Max}"

EXTRAS=0
LANGUAGES=()
for argument in "$@"; do
  case "$argument" in
    --extras) EXTRAS=1 ;;
    -*) echo "Unknown option: $argument" >&2; exit 2 ;;
    *) LANGUAGES+=("$argument") ;;
  esac
done
if [ ${#LANGUAGES[@]} -eq 0 ]; then
  LANGUAGES=(en en-GB de es fr pt-BR)
fi

# What the device is told, per language the app has an lproj for. The left side
# is the folder `make-shots.py` looks in; the right side is what iOS is asked
# for. `es-ES` resolves to `es`, `fr-FR` to `fr`, and so on — the app carries
# the short spelling for all but the two that are a region rather than a
# language.
locale_for () {
  case "$1" in
    en)    echo "en-US en_US" ;;
    en-GB) echo "en-GB en_GB" ;;
    de)    echo "de-DE de_DE" ;;
    es)    echo "es-ES es_ES" ;;
    fr)    echo "fr-FR fr_FR" ;;
    pt-BR) echo "pt-BR pt_BR" ;;
    *)     echo "" ;;
  esac
}

udid=$(xcrun simctl list devices available \
  | grep -m1 "^ *$DEVICE (" \
  | sed -n 's/.*(\([0-9A-F-]\{36\}\)).*/\1/p')
if [ -z "$udid" ]; then
  echo "No simulator called '$DEVICE'. What there is:" >&2
  xcrun simctl list devices available | grep "iPhone" >&2
  exit 1
fi
echo "Device: $DEVICE ($udid)"

APP="$PROJECT/DerivedData/Build/Products/Debug-iphonesimulator/Quiet.app"
if [ ! -d "$APP" ]; then
  echo "Build it first:" >&2
  echo "  xcodebuild build -project Quiet.xcodeproj -scheme Quiet \\" >&2
  echo "    -destination 'platform=iOS Simulator,id=$udid' -derivedDataPath DerivedData" >&2
  exit 1
fi

PREFS="$HOME/Library/Developer/CoreSimulator/Devices/$udid/data/Library/Preferences/.GlobalPreferences.plist"

boot_in () {                       # boot_in <AppleLanguages> <AppleLocale>
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  plutil -replace AppleLanguages -json "[\"$1\",\"en-US\"]" "$PREFS"
  plutil -replace AppleLocale -string "$2" "$PREFS"
  xcrun simctl boot "$udid" >/dev/null
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$APP" >/dev/null
  # 9:41 and a full battery, which is what Apple's own screenshots carry. The
  # bar is cropped off every finished frame; this is here so that nothing odd
  # can arrive in one if that crop is ever a few points out.
  xcrun simctl status_bar "$udid" override \
    --time 9:41 --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 \
    --dataNetwork wifi --wifiMode active --wifiBars 3
}

shoot () {                         # shoot <language> <name> <scene> <appearance>
  local language="$1" name="$2" scene="$3" appearance="$4"
  mkdir -p "$OUT/$language"
  xcrun simctl ui "$udid" appearance "$appearance" >/dev/null
  xcrun simctl terminate "$udid" "$APP_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$udid" "$APP_ID" -QuietRehearsal "$scene" >/dev/null
  # The browsing screen holds Quiet's own paper over the web view until the
  # first page settles, so it waits for a page rather than for an app.
  case "$scene" in
    browsing) sleep 15 ;;
    *)        sleep 12 ;;
  esac
  xcrun simctl io "$udid" screenshot --type=png "$OUT/$language/$name.png"
  # A scene that was not on the glass yet photographs as the paper it stands
  # on, and a freshly booted simulator is slow enough to do that on any of
  # them. Blank frames are identical to each other, so a frame that matches one
  # already taken in this language is asked for again, a few times, before the
  # run is allowed to go on.
  local again=0 mine other
  while [ $again -lt 3 ]; do
    mine=$(md5 -q "$OUT/$language/$name.png")
    other=$(find "$OUT/$language" -name '*.png' ! -name "$name.png" -newer "$HERE/photograph-for-the-store.sh" \
      -exec md5 -q {} \; | grep -c "^$mine$" || true)
    [ "$other" = "0" ] && break
    again=$((again + 1))
    sleep 8
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$language/$name.png"
  done
  echo "    $name  ($scene, $appearance)"
}

for language in "${LANGUAGES[@]}"; do
  set -- $(locale_for "$language")
  if [ $# -ne 2 ]; then
    echo "No locale known for '$language'" >&2
    exit 1
  fi
  echo "--- $language  (AppleLanguages $1, AppleLocale $2)"
  boot_in "$1" "$2"

  # The five the listing is cut from. Appearance is the slide's ground: the
  # curtain and the opening stand on Quiet's night, the rest on its paper.
  #
  # `settings` rather than `panel`, and the distinction cost a round once: the
  # file the slides have always been cut from was *named* panel-light and is a
  # photograph of the settings screen, which is the screen the caption is about
  # — the wait between increases is there and nowhere else. Named for the scene
  # now, so that the next person to re-shoot it gets the same screen back.
  shoot "$language" setup    fresh    light
  shoot "$language" settings settings light
  shoot "$language" record   record   light
  shoot "$language" curtain  spent    dark
  shoot "$language" opening  opening  dark

  if [ "$EXTRAS" = "1" ]; then
    shoot "$language" limit    limit    light
    shoot "$language" panel    panel    light
    shoot "$language" search   search   dark
    shoot "$language" browsing browsing light
  fi
done

xcrun simctl status_bar "$udid" clear >/dev/null 2>&1 || true
xcrun simctl ui "$udid" appearance light >/dev/null 2>&1 || true

# And prove the language took. Two screenshots of the same layout in two
# languages look plausible until the bytes are compared.
echo "--- every frame different from every other"
duplicates=$(find "$OUT" -name '*.png' -exec md5 -q {} \; | sort | uniq -d | wc -l | tr -d ' ')
if [ "$duplicates" != "0" ]; then
  echo "$duplicates identical pairs — a language did not take:" >&2
  find "$OUT" -name '*.png' -exec md5 {} \; | sed "s|$OUT/||"
  exit 1
fi
echo "ok"
echo
echo "In $OUT. Look at them, then:"
echo "  rsync -a $OUT/ $HERE/shots/source/"

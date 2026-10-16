# Sourced by setup.sh.
# DRY_RUN=1 prints each setting and skips every write.

normalize_default() {
  case "$1" in
    1|true|YES|yes) printf "1" ;;
    0|false|NO|no) printf "0" ;;
    *) printf "%s" "$1" ;;
  esac
}

section() {
  detail "$1"
}

# Returns 0 when the caller should write. Prints ok when the value already
# matches, and would (then returns 1) during a dry run. $5 is the shown value.
consider() {
  local domain="$1"
  local key="$2"
  local current="$3"
  local wanted="$4"
  local label="${5:-$wanted}"
  local message="${domain} ${key}"

  if [[ "$current" == "$wanted" ]]; then
    status ok "${message} = ${label}"
    return 1
  fi

  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    local shown="$current"
    [[ -z "$shown" ]] && shown="(unset)"
    shown="${shown//$'\n'/ }"
    if [[ "$label" == "true" || "$label" == "false" ]]; then
      case "$shown" in
        1) shown="true" ;;
        0) shown="false" ;;
      esac
    fi
    status would "${message}: ${shown} -> ${label}"
    return 1
  fi

  return 0
}

set_bool() {
  local domain="$1"
  local key="$2"
  local value="$3"
  local expected="$4"
  local current
  current="$(normalize_default "$(defaults read "$domain" "$key" 2>/dev/null || true)")"
  if consider "$domain" "$key" "$current" "$expected" "$value"; then
    defaults write "$domain" "$key" -bool "$value"
    status set "${domain} ${key} = ${value}"
    REBOOT_REQUIRED=1
  fi
}

set_int() {
  local domain="$1"
  local key="$2"
  local value="$3"
  local current
  current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
  if consider "$domain" "$key" "$current" "$value"; then
    defaults write "$domain" "$key" -int "$value"
    status set "${domain} ${key} = ${value}"
    REBOOT_REQUIRED=1
  fi
}

set_string() {
  local domain="$1"
  local key="$2"
  local value="$3"
  local current
  current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
  if consider "$domain" "$key" "$current" "$value"; then
    defaults write "$domain" "$key" -string "$value"
    status set "${domain} ${key} = ${value}"
    REBOOT_REQUIRED=1
  fi
}

set_array() {
  local domain="$1"
  local key="$2"
  shift 2
  local current desired item count i
  current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
  desired="("
  count=$#
  i=0
  for item in "$@"; do
    i=$((i + 1))
    if [[ "$i" -lt "$count" ]]; then
      desired+=$'\n    "'"$item"'",'
    else
      desired+=$'\n    "'"$item"'"'
    fi
  done
  desired+=$'\n)'
  local label
  label="$(printf '%s, ' "$@")"
  label="${label%, }"
  if consider "$domain" "$key" "$current" "$desired" "$label"; then
    defaults write "$domain" "$key" -array "$@"
    status set "${domain} ${key} = ${label}"
    REBOOT_REQUIRED=1
  fi
}

section "Finder: show filename extensions and hidden files"
set_bool NSGlobalDomain AppleShowAllExtensions true 1
set_bool com.apple.finder AppleShowAllFiles true 1
set_bool NSGlobalDomain AppleShowAllFiles true 1

section "Finder: show the path bar and status bar"
set_bool com.apple.finder ShowPathbar true 1
set_bool com.apple.finder ShowStatusBar true 1

section "Finder: don't warn when changing a filename extension"
set_bool com.apple.finder FXEnableExtensionChangeWarning false 0

section "Finder: list folders above files"
set_bool com.apple.finder _FXSortFoldersFirst true 1

section "Finder: keep hard drives, servers, and removable media off the desktop"
set_bool com.apple.finder ShowHardDrivesOnDesktop false 0
set_bool com.apple.finder ShowMountedServersOnDesktop false 0
set_bool com.apple.finder ShowExternalHardDrivesOnDesktop false 0
set_bool com.apple.finder ShowRemovableMediaOnDesktop false 0

section "Finder: don't create .DS_Store files on network or USB volumes"
set_bool com.apple.desktopservices DSDontWriteNetworkStores true 1
set_bool com.apple.desktopservices DSDontWriteUSBStores true 1

section "Dock: keep it visible, hide recent apps, and don't bounce icons when opening apps"
set_bool com.apple.dock autohide false 0
set_bool com.apple.dock show-recents false 0
set_bool com.apple.dock launchanim false 0

section "Keyboard: fast repeat, and press-and-hold off so keys repeat"
set_int NSGlobalDomain KeyRepeat 2
set_int NSGlobalDomain InitialKeyRepeat 15
set_bool NSGlobalDomain ApplePressAndHoldEnabled false 0

section "Screenshots: save PNGs in ~/Screenshots"
ensure_dir "${HOME}/Screenshots"
set_string com.apple.screencapture location "${HOME}/Screenshots"
set_string com.apple.screencapture type png

section "Trackpad: tap to click"
set_bool com.apple.AppleMultitouchTrackpad Clicking true 1
set_bool com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking true 1
set_int NSGlobalDomain com.apple.mouse.tapBehavior 1

current_host_tap="$(defaults -currentHost read NSGlobalDomain com.apple.mouse.tapBehavior 2>/dev/null || true)"
if consider "-currentHost NSGlobalDomain" "com.apple.mouse.tapBehavior" "$current_host_tap" "1"; then
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  status set "-currentHost NSGlobalDomain com.apple.mouse.tapBehavior = 1"
  REBOOT_REQUIRED=1
fi

section "Language and formats: English (Belgium), Dutch, metric, 24-hour time"
set_array NSGlobalDomain AppleLanguages "en-BE" "nl-BE"
set_string NSGlobalDomain AppleLocale "en_BE"
set_string NSGlobalDomain AppleMeasurementUnits "Centimeters"
set_string NSGlobalDomain AppleTemperatureUnit "Celsius"
set_bool NSGlobalDomain AppleMetricUnits true 1
set_bool NSGlobalDomain AppleICUForce12HourTime false 0

section "Photos: don't open when a camera or iPhone is plugged in"
current_hotplug="$(normalize_default "$(defaults -currentHost read com.apple.ImageCapture disableHotPlug 2>/dev/null || true)")"
if consider "-currentHost com.apple.ImageCapture" "disableHotPlug" "$current_hotplug" "1" "true"; then
  defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true
  status set "-currentHost com.apple.ImageCapture disableHotPlug = true"
  REBOOT_REQUIRED=1
fi

section "Login window: message shown when the Mac is locked"
login_message="Found me? Shoot a mail to ${LOST_EMAIL} to return me. Thanks."
current_login_message="$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || true)"
if consider "/Library/Preferences/com.apple.loginwindow" "LoginwindowText" "$current_login_message" "$login_message"; then
  sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText -string "$login_message"
  status set "/Library/Preferences/com.apple.loginwindow LoginwindowText = ${login_message}"
  REBOOT_REQUIRED=1
fi

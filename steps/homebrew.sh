# Sourced by setup.sh.

if xcode-select -p >/dev/null 2>&1; then
  status ok "Xcode Command Line Tools"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  status would "install the Xcode Command Line Tools"
else
  say "Installing the Xcode Command Line Tools. Finish the dialog if it appears."
  xcode-select --install || true
  until xcode-select -p >/dev/null 2>&1; do
    sleep 5
  done
  status set "Xcode Command Line Tools"
fi

load_brew() {
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return 0
  fi
  if [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    return 0
  fi
  return 1
}

if load_brew; then
  status ok "Homebrew"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  status would "install Homebrew"
  status would "install the Brewfile once Homebrew is there"
else
  say "Installing Homebrew."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew || {
    echo "Homebrew is not on /opt/homebrew or /usr/local."
    exit 1
  }
  status set "Homebrew"
fi

has_line() {
  local needle="$1"
  local haystack="$2"
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$needle" ]] && return 0
  done <<< "$haystack"
  return 1
}

preview_brewfile() {
  local want="$1"
  local title="$2"
  local line kind name formula printed=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    kind="${line%% *}"
    [[ "$kind" == "$want" ]] || continue
    name="${line#* }"
    name="${name%\"}"
    name="${name#\"}"

    if [[ "$printed" -eq 0 ]]; then
      detail "$title"
      printed=1
    fi

    case "$want" in
      tap)
        if has_line "$name" "$installed_taps"; then
          status ok "$name"
        else
          status would "tap ${name}"
        fi
        ;;
      brew)
        formula="${name##*/}"
        if has_line "$formula" "$installed_formulae"; then
          status ok "$formula"
        else
          status would "install ${formula}"
        fi
        ;;
      cask)
        if has_line "$name" "$installed_casks"; then
          status ok "$name"
        else
          status would "install ${name}"
        fi
        ;;
    esac
  done < "${ROOT}/Brewfile"
}

ensure_dir "${HOME}/.nvm"

if command -v brew >/dev/null 2>&1; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    installed_taps="$(brew tap 2>/dev/null || true)"
    installed_formulae="$(brew list --formula 2>/dev/null || true)"
    installed_casks="$(brew list --cask 2>/dev/null || true)"
    preview_brewfile tap "Taps"
    preview_brewfile brew "Formulae"
    preview_brewfile cask "Casks"
  else
    say "Installing formulae and casks from the Brewfile."
    brew bundle --file="${ROOT}/Brewfile"
  fi
fi

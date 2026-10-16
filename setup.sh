#!/usr/bin/env bash
# Set up a new Mac. Safe to re-run; --force starts from the first step again.
# --dry-run walks every step and changes nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN="be.davydepauw.freshmac"
STEP_COUNT=5
REBOOT_REQUIRED=0
DRY_RUN=0
DRY_RUN_CHANGES=0
DOTFILES_RAN=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  # Terminup logo green, #4ade80. https://l-ubu.github.io/Terminup
  LOGO=$'\033[1;38;2;74;222;128m'
  RESET=$'\033[0m'
else
  BOLD=""
  DIM=""
  GREEN=""
  YELLOW=""
  LOGO=""
  RESET=""
fi

if [[ "$(id -u)" -eq 0 ]]; then
  echo "Run ./setup.sh as your user, not as root."
  exit 1
fi

START_OVER=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
elif [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]]; then
  defaults delete "$DOMAIN" step 2>/dev/null || true
  START_OVER=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: ./setup.sh [--force | --dry-run]"
  exit 1
fi

# ok: already as intended. set: changed just now. would: dry-run only. skip: step already finished.
status() {
  local word="$1"
  local message="$2"
  local color=""
  case "$word" in
    ok|set) color="$GREEN" ;;
    would) color="$YELLOW" ;;
    skip) color="$DIM" ;;
  esac
  printf "  %s%-5s%s  %s\n" "$color" "$word" "$RESET" "$message"
  if [[ "$word" == "would" ]]; then
    DRY_RUN_CHANGES=$((DRY_RUN_CHANGES + 1))
  fi
}

say() {
  printf "  %s\n" "$1"
}

detail() {
  printf "\n  %s%s%s\n" "$BOLD" "$1" "$RESET"
}

step_heading() {
  printf "\n%s── %s/%s%s  %s%s%s\n" "$DIM" "$1" "$STEP_COUNT" "$RESET" "$BOLD" "$2" "$RESET"
}

# The version is the nearest git tag, such as v1.0.0. Unreleased until that tag exists.
script_version() {
  local version=""
  if command -v git >/dev/null 2>&1; then
    version="$(git -C "$ROOT" describe --tags --dirty 2>/dev/null || true)"
  fi
  if [[ -z "$version" ]]; then
    printf "unreleased"
  else
    printf "%s" "$version"
  fi
}

show_header() {
  if [[ -t 1 ]]; then
    printf '\033[H\033[2J'
  fi
  printf '\n%s' "$LOGO"
  cat <<'EOF'
███████╗██████╗ ███████╗███████╗██╗  ██╗    ███╗   ███╗ █████╗  ██████╗
██╔════╝██╔══██╗██╔════╝██╔════╝██║  ██║    ████╗ ████║██╔══██╗██╔════╝
█████╗  ██████╔╝█████╗  ███████╗███████║    ██╔████╔██║███████║██║     
██╔══╝  ██╔══██╗██╔══╝  ╚════██║██╔══██║    ██║╚██╔╝██║██╔══██║██║     
██║     ██║  ██║███████╗███████║██║  ██║    ██║ ╚═╝ ██║██║  ██║╚██████╗
╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝
EOF
  printf "\n%s%s%s\n\n" "$RESET$DIM" "$(script_version)" "$RESET"
}

pretty_path() {
  local path="$1"
  if [[ "$path" == "$HOME" || "$path" == "$HOME"/* ]]; then
    printf "~%s" "${path#"$HOME"}"
  else
    printf "%s" "$path"
  fi
}

ensure_dir() {
  local dir="$1"
  local label
  label="$(pretty_path "$dir")"

  if [[ -d "$dir" ]]; then
    status ok "$label"
  elif [[ "$DRY_RUN" -eq 1 ]]; then
    status would "create ${label}"
  else
    mkdir -p "$dir"
    status set "$label"
  fi
}

link_dotfile() {
  local src="$1"
  local dest="$2"
  local label
  label="$(pretty_path "$dest")"

  if [[ ! -f "$src" ]]; then
    echo "Missing dotfile: ${src}"
    exit 1
  fi

  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    status ok "$label"
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -e "$dest" || -L "$dest" ]]; then
      status would "replace ${label} with a link to this repo"
    else
      status would "link ${label}"
    fi
    return
  fi

  if [[ -L "$dest" ]]; then
    ln -sfn "$src" "$dest"
    status set "$label"
    return
  fi

  if [[ -e "$dest" ]]; then
    local backup="${dest}.bak"
    if [[ -e "$backup" ]]; then
      backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
    fi
    mv "$dest" "$backup"
    ln -s "$src" "$dest"
    status set "${label}  (saved $(pretty_path "$backup"))"
    return
  fi

  ln -s "$src" "$dest"
  status set "$label"
}

run_step() {
  local number="$1"
  local name="$2"
  local file="$3"

  step_heading "$number" "$name"

  if [[ "$DRY_RUN" -eq 0 && "$last_step" -ge "$number" ]]; then
    status skip "already done"
    return
  fi

  # shellcheck source=/dev/null
  source "$file"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    return
  fi

  defaults write "$DOMAIN" step -int "$number"
  last_step="$number"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

git_quote() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

read_saved() {
  defaults read "$DOMAIN" "$1" 2>/dev/null || true
}

# Prompts go to the terminal. Only the answer is printed to stdout, so $() can capture it.
prompt_line() {
  local prompt="$1"
  local mode="$2"
  local value=""
  while true; do
    printf "  %s " "$prompt" >/dev/tty
    IFS= read -r value </dev/tty || {
      printf "\nNeed an answer before setup can start.\n" >/dev/tty
      exit 1
    }
    value="$(trim "$value")"
    if [[ "$mode" == "optional" ]]; then
      printf "%s" "$value"
      return
    fi
    if [[ -z "$value" ]]; then
      printf "  Enter a value.\n" >/dev/tty
      continue
    fi
    if [[ "$mode" == "email" && "$value" != *@* ]]; then
      printf "  Enter an email address.\n" >/dev/tty
      continue
    fi
    printf "%s" "$value"
    return
  done
}

ask() {
  local answer=""
  answer="$(prompt_line "$1" "$2")"
  printf "%s" "$answer"
}

save_answers() {
  defaults write "$DOMAIN" gitName -string "$GIT_NAME"
  defaults write "$DOMAIN" gitEmail -string "$GIT_EMAIL"
  defaults write "$DOMAIN" gitSigningKey -string "$GIT_SIGNING_KEY"
  defaults write "$DOMAIN" lostEmail -string "$LOST_EMAIL"

  local dir="${HOME}/.config/fresh-mac"
  mkdir -p "$dir"
  {
    printf '[user]\n'
    printf '\tname = %s\n' "$(git_quote "$GIT_NAME")"
    printf '\temail = %s\n' "$(git_quote "$GIT_EMAIL")"
    if [[ -n "$GIT_SIGNING_KEY" ]]; then
      printf '\tsigningKey = %s\n' "$(git_quote "$GIT_SIGNING_KEY")"
    fi
    printf '[commit]\n'
    if [[ -n "$GIT_SIGNING_KEY" ]]; then
      printf '\tgpgsign = true\n'
    else
      printf '\tgpgsign = false\n'
    fi
  } > "${dir}/gitconfig"
  chmod 600 "${dir}/gitconfig"
}

show_saved_answers() {
  echo "  Git name: ${GIT_NAME}"
  echo "  Git email: ${GIT_EMAIL}"
  if [[ -n "$GIT_SIGNING_KEY" ]]; then
    echo "  GPG fingerprint: ${GIT_SIGNING_KEY}"
  else
    echo "  GPG fingerprint: none (commits will not be signed)"
  fi
  echo "  If this Mac is lost: ${LOST_EMAIL}"
}

show_header

if [[ "$START_OVER" -eq 1 ]]; then
  echo "Starting over from the first step."
  echo
fi

echo "A few questions first. Nothing is installed until these are answered."
echo "The answers stay on this Mac. They are not written into this repo."
echo

GIT_NAME="$(read_saved gitName)"
GIT_EMAIL="$(read_saved gitEmail)"
GIT_SIGNING_KEY="$(read_saved gitSigningKey)"
LOST_EMAIL="$(read_saved lostEmail)"

if [[ "$START_OVER" -eq 1 || -z "$GIT_NAME" || -z "$GIT_EMAIL" || -z "$LOST_EMAIL" ]]; then
  GIT_NAME="$(ask "Git name:" text)"
  GIT_EMAIL="$(ask "Git email:" email)"
  GIT_SIGNING_KEY="$(ask "GPG fingerprint, not the secret key (Enter to skip):" optional)"
  LOST_EMAIL="$(ask "Email to show if this Mac is lost:" email)"
  echo
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "Dry run, so these answers were not saved."
  else
    save_answers
    echo "Saved on this Mac. Install starts now."
  fi
else
  echo "Using the answers already saved on this Mac."
  show_saved_answers
  if [[ "$DRY_RUN" -eq 0 ]]; then
    save_answers
  fi
fi

echo
echo "Homebrew, git, zsh dotfiles, macOS settings, and /sites and /projects."

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run. Nothing on this Mac will be changed."
else
  echo "Your password is needed once."
  echo
  sudo -v
  (
    while true; do
      sudo -n true
      sleep 60
      kill -0 "$$" || exit
    done
  ) 2>/dev/null &
  keepalive_pid=$!
  trap 'kill "$keepalive_pid" 2>/dev/null || true' EXIT
fi

last_step="$(defaults read "$DOMAIN" step 2>/dev/null || echo 0)"

run_step 1 "Homebrew" "${ROOT}/steps/homebrew.sh"
run_step 2 "Git" "${ROOT}/steps/git.sh"
run_step 3 "Dotfiles" "${ROOT}/steps/dotfiles.sh"
run_step 4 "macOS" "${ROOT}/steps/macos.sh"
run_step 5 "/sites and /projects" "${ROOT}/steps/synthetic.sh"

echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$DRY_RUN_CHANGES" -eq 0 ]]; then
    echo "Nothing would change."
  elif [[ "$DRY_RUN_CHANGES" -eq 1 ]]; then
    echo "1 change. Run ./setup.sh to apply it."
  else
    echo "${DRY_RUN_CHANGES} changes. Run ./setup.sh to apply them."
  fi
  exit 0
fi

if [[ "$REBOOT_REQUIRED" -eq 1 ]]; then
  echo "A reboot is needed for the macOS settings and for /sites and /projects."
  if [[ "$DOTFILES_RAN" -eq 1 ]]; then
    echo "Open a new terminal after it restarts so zsh picks up the dotfiles."
  fi
  printf "Reboot now? [y/N] "
  read -r reply
  if [[ "$reply" =~ ^[Yy]$ ]]; then
    osascript -e 'tell application "System Events" to restart'
    exit 0
  fi
  echo "Reboot when you can. Until then, /sites and /projects will not exist."
else
  echo "Done."
  if [[ "$DOTFILES_RAN" -eq 1 ]]; then
    echo "Open a new terminal so zsh picks up the dotfiles."
  fi
fi

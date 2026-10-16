# Sourced by setup.sh.

ensure_dir "${HOME}/Sites"
ensure_dir "${HOME}/Projects"

# $(...) would strip the trailing newline, which synthetic.conf needs.
desired="sites"$'\t'"Users/${USER}/Sites"$'\n'"projects"$'\t'"Users/${USER}/Projects"$'\n'
current=""
if [[ -f /etc/synthetic.conf ]]; then
  # Keep a trailing newline. $(cat) would strip it and the file would never match.
  current="$(cat /etc/synthetic.conf; printf x)"
  current="${current%x}"
fi

if [[ "$current" == "$desired" ]]; then
  status ok "/etc/synthetic.conf"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  status would "write /etc/synthetic.conf for /sites and /projects"
else
  printf "%s" "$desired" | sudo tee /etc/synthetic.conf >/dev/null
  REBOOT_REQUIRED=1
  status set "/etc/synthetic.conf"
fi

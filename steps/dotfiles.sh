# Sourced by setup.sh.

DOTFILES_RAN=1

link_dotfile "${ROOT}/dotfiles/zshrc" "${HOME}/.zshrc"
link_dotfile "${ROOT}/dotfiles/zprofile" "${HOME}/.zprofile"
link_dotfile "${ROOT}/dotfiles/aliases" "${HOME}/.aliases"
link_dotfile "${ROOT}/dotfiles/functions" "${HOME}/.functions"
link_dotfile "${ROOT}/dotfiles/zsh_plugins.txt" "${HOME}/.zsh_plugins.txt"

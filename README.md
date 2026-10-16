```
███████╗██████╗ ███████╗███████╗██╗  ██╗    ███╗   ███╗ █████╗  ██████╗
██╔════╝██╔══██╗██╔════╝██╔════╝██║  ██║    ████╗ ████║██╔══██╗██╔════╝
█████╗  ██████╔╝█████╗  ███████╗███████║    ██╔████╔██║███████║██║     
██╔══╝  ██╔══██╗██╔══╝  ╚════██║██╔══██║    ██║╚██╔╝██║██╔══██║██║     
██║     ██║  ██║███████╗███████║██║  ██║    ██║ ╚═╝ ██║██║  ██║╚██████╗
╚═╝     ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝    ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝
```

# fresh-mac

One script for a new Mac.

Sets up Homebrew packages, git config, zsh dotfiles, a short list of macOS settings, and `/etc/synthetic.conf` firmlinks for `/sites` and `/projects`.

## Run

```bash
git clone https://github.com/davydepauw/fresh-mac.git
cd fresh-mac
./setup.sh
```

The script asks four questions before it installs anything: your git name, git email, GPG fingerprint, and an email to show on the lock screen if the Mac is lost. Those answers stay on this Mac, in `~/.config/fresh-mac/gitconfig` and in local preferences. They are not written into this repo.

After that, it asks for your password once. If it stops partway, run it again. It continues at the next unfinished step and keeps the answers it already saved. When macOS settings or `synthetic.conf` change, it offers a reboot. The `/sites` and `/projects` firmlinks show up only after that reboot.

Preview every step without installing or writing anything:

```bash
./setup.sh --dry-run
```

A real run uses the same lines. `ok` is already set, `set` was just changed, `would` is what a dry run would change, and `skip` is a step that already finished.

Start over:

```bash
./setup.sh --force
```

Existing dotfiles are moved aside to `*.bak` before they are replaced with symlinks into this repo. Open a new terminal after the dotfiles step so zsh picks them up.

## What it installs

Formulae: Git, GitHub CLI, Antidote, nvm, zsh completions, DDEV.

Casks: OrbStack, Cursor, iTerm, Raycast, Chrome, Slack, Figma, TablePlus, 1Password, 1Password CLI, Dropbox, VLC, Setapp, Fantastical, TextMate, Grammarly Desktop, Affinity, Arc, Firefox, Obsidian, Zwift, Sequel Ace.

The shell loads a few Oh My Zsh plugins (`git`, `brew`), syntax highlighting, history substring search, and the Cobalt2 prompt through Antidote. Cobalt2 expects a Powerline-patched font in iTerm.

## Afterward

- If you entered a GPG fingerprint, import that secret key (1Password can hold it) so signed commits work. Leave the fingerprint empty during setup to commit without signing.
- Install Xcode from the App Store if a project needs it. The script only installs the Command Line Tools.
- Install a Node version the first time you need it: `nvm install --lts`.
- If an old `~/.zshenv` pins a Node version on `PATH`, remove that line so the lazy nvm setup is the one that runs.

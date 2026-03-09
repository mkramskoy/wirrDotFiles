# Dotfiles

Personal configuration files for development environment setup.

## Philosophy

This repository uses a **shared/local split** approach:
- **`.gitconfig.shared`** and **`.zshrc.shared`** contain my shared configuration (tracked in git)
- **`~/.gitconfig`** and **`~/.zshrc`** are local files on each machine (not tracked in git)

**Why this approach?**
- Tools (nvm, sdkman, brew, etc.) can modify your local files without affecting my files
- Clear separation: local is not tracked, shared is explicitly shared
- Machine-specific settings (username, email, paths) stay in local files

## What to install

- Install [iterm2](https://iterm2.com/)
    - Import terminalProfile.json
- Install [ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)
    - Install plugin [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh)

## How it works

All shared configuration lives in the repo and is automatically loaded:
- `~/.gitconfig` includes `~/git_tree/wirrDotFiles/.gitconfig.shared`
- `~/.zshrc` sources `~/git_tree/wirrDotFiles/.zshrc.shared`
- `.zshrc.shared` sources `.functions` from the same directory

**No copying needed!** Just edit files directly in the repo, commit, and push.

## Tool auto-configuration

When tools like nvm, sdkman, or brew modify your shell config, they'll append to `~/.gitconfig` or `~/.zshrc`. This is fine! Those changes stay local and don't affect your shared configuration.

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# fixing problem with brew installation on M1 macs 
# https://apple.stackexchange.com/questions/148901/why-does-my-brew-installation-not-work
eval $(/opt/homebrew/bin/brew shellenv)

# Path to your oh-my-zsh installation.
export ZSH="/Users/mkramskoy/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git docker python pylint swiftpm kubectl zsh-autosuggestions)

# activating the autosuggestions when installed via homebrew
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# Aliases #
alias k="kubectl"
alias g="git"
# Status and Shortcuts
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add .'

# Committing and Branching
alias gc='git commit -v'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gb='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'

# Pulling and Pushing
alias gp='git push'
alias gpf='git push --force'
alias gl='git pull --rebase'

# Viewing Logs
alias glog='git log --oneline --graph --decorate --all'
alias gslog='git log --oneline --decorate --graph'

# Diff and Reset
alias gd='git diff'
alias grst='git reset --hard'

# Stashing
alias gst='git stash'
alias gstp='git stash pop'

# Show last commit
alias glast='git log -1 HEAD'

# Squash multiple commits
alias grbc='git rebase -i HEAD~'

# Load the shell dotfiles, and then some:
# * ~/.extra can be used for other settings you dont want to commit.
for file in ~/.{functions,extra}; do
        [ -r "$file" ] && [ -f "$file" ] && source "$file";
done;
unset file;

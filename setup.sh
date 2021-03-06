#! /bin/bash

# https://github.com/kaicataldo/dotfiles/blob/master/bin/install.sh

# This symlinks all the dotfiles (and .atom/) to ~/
# It also symlinks ~/bin for easy updating

# This is safe to run multiple times and will prompt you about anything unclear


#
# Utils
#

answer_is_yes() {
  [[ "$REPLY" =~ ^[Yy]$ ]] \
    && return 0 \
    || return 1
}

ask() {
  print_question "$1"
  read
}

ask_for_confirmation() {
  print_question "$1 (y/n) "
  read -n 1
  printf "\n"
}

ask_for_sudo() {

  # Ask for the administrator password upfront
  sudo -v

  # Update existing `sudo` time stamp until this script has finished
  # https://gist.github.com/cowboy/3118588
  while true; do
    sudo -n true
    sleep 60
    kill -0 "$$" || exit
  done &> /dev/null &

}

cmd_exists() {
  [ -x "$(command -v "$1")" ] \
    && printf 0 \
    || printf 1
}

execute() {
  $1 &> /dev/null
  print_result $? "${2:-$1}"
}

get_answer() {
  printf "$REPLY"
}

get_os() {
  declare -r OS_NAME="$(uname -s)"
  local os=""

  if [ "$OS_NAME" == "Darwin" ]; then
    os="osx"
  elif [ "$OS_NAME" == "Linux" ] && [ -e "/etc/lsb-release" ]; then
    os="ubuntu"
  fi

  printf "%s" "$os"
}

install_system_packages() {
  platform=$(uname);
  # If the platform is Linux, try an apt-get to install zsh and then recurse
  if [[ $platform == 'Linux' ]]; then
    if [[ -f /etc/redhat-release ]]; then
      sudo yum install $1
    fi
    if [ -f "/etc/arch-release" ]; then
      yay -S --needed --noconfirm $1
    fi
    if [[ -f /etc/debian_version ]]; then
      sudo apt install $1 -y
    fi
  # If the platform is OS X, tell the user to install zsh :)
  elif [[ $platform == 'Darwin' ]]; then
    brew install $1
  fi
}

is_git_repository() {
  [ "$(git rev-parse &>/dev/null; printf $?)" -eq 0 ] \
    && return 0 \
    || return 1
}

mkd() {
  if [ -n "$1" ]; then
    if [ -e "$1" ]; then
      if [ ! -d "$1" ]; then
        print_error "$1 - a file with the same name already exists!"
      else
        print_success "$1"
      fi
    else
      execute "mkdir -p $1" "$1"
    fi
  fi
}

print_error() {
  # Print output in red
  printf "\e[0;31m  [✖] $1 $2\e[0m\n"
}

print_info() {
  # Print output in purple
  printf "\n\e[0;35m $1\e[0m\n\n"
}

print_question() {
  # Print output in yellow
  printf "\e[0;33m  [?] $1\e[0m"
}

print_result() {
  [ $1 -eq 0 ] \
    && print_success "$2" \
    || print_error "$2"

  [ "$3" == "true" ] && [ $1 -ne 0 ] \
    && exit
}

print_success() {
  # Print output in green
  printf "\e[0;32m  [✔] $1\e[0m\n"
}

# Warn user this script will overwrite current dotfiles
while true; do
  read -p "Warning: this will overwrite your current dotfiles. Continue? [y/n] " yn
  case $yn in
    [Yy]* ) break;;
    [Nn]* ) exit;;
    * ) echo "Please answer yes or no.";;
  esac
done

ask_for_sudo

# Get the dotfiles directory's absolute path
SCRIPT_DIR="$(cd "$(dirname "$0")"; pwd -P)"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"


dir=~/dotfiles                        # dotfiles directory
dir_backup=~/dotfiles_old             # old dotfiles backup directory

# Get current dir (so run this script from anywhere)

export DOTFILES_DIR
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create dotfiles_old in homedir
echo -n "Creating $dir_backup for backup of any existing dotfiles in ~..."
mkdir -p $dir_backup
echo "done"


# Change to the dotfiles directory
echo -n "Changing to the $dir directory..."
cd $dir
echo "done"

#
# Actual symlink stuff
#

declare -a FILES_TO_SYMLINK=(

  'shell/ackrc'
  'shell/bash_profile'
  'shell/bash_prompt'
  'shell/bashrc'
  'shell/ctags'
  'shell/curlrc'
  'shell/gemrc'
  'shell/inputrc'
  'shell/screenrc'
  'shell/shell_aliases'
  'shell/shell_config'
  'shell/shell_exports'
  'shell/shell_functions'
  'shell/tmux.conf'
  'shell/vimrc'
  'shell/zpreztorc'
  'shell/zshrc'

  'git/gitattributes'
  'git/gitconfig'
  'git/gitignore'

)

# FILES_TO_SYMLINK="$FILES_TO_SYMLINK .vim bin" # add in vim and the binaries

# Move any existing dotfiles in homedir to dotfiles_old directory, then create symlinks from the homedir to any files in the ~/dotfiles directory specified in $files

for i in ${FILES_TO_SYMLINK[@]}; do
  echo "Moving any existing dotfiles from ~ to $dir_backup"
  mv ~/.${i##*/} ~/dotfiles_old/
done


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

  local i=''
  local sourceFile=''
  local targetFile=''

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  for i in ${FILES_TO_SYMLINK[@]}; do

    sourceFile="$(pwd)/$i"
    targetFile="$HOME/.$(printf "%s" "$i" | sed "s/.*\/\(.*\)/\1/g")"

    if [ ! -e "$targetFile" ]; then
      execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
    elif [ "$(readlink "$targetFile")" == "$sourceFile" ]; then
      print_success "$targetFile → $sourceFile"
    else
      ask_for_confirmation "'$targetFile' already exists, do you want to overwrite it?"
      if answer_is_yes; then
        rm -rf "$targetFile"
        execute "ln -fs $sourceFile $targetFile" "$targetFile → $sourceFile"
      else
        print_error "$targetFile → $sourceFile"
      fi
    fi

  done

  unset FILES_TO_SYMLINK

  # Copy binaries
  ln -fs $HOME/dotfiles/bin $HOME

  declare -a BINARIES=(
    'batcharge.py'
    'crlf'
    'dups'
    'git-delete-merged-branches'
    'nyan'
    'passive'
    'proofread'
    'ssh-key'
    'weasel'
  )

  for i in ${BINARIES[@]}; do
    # echo "Changing access permissions for binary script :: ${i##*/}"
    chmod +rwx $HOME/bin/${i##*/}
  done

  unset BINARIES

  # Symlink online-check.sh
  ln -fs $HOME/dotfiles/lib/online-check.sh $HOME/online-check.sh

  # Write out current crontab
  crontab -l > mycron
  # Echo new cron into cron file
  echo "* * * * * ~/online-check.sh" >> mycron
  # Install new cron file
  crontab mycron
  rm mycron

}

# Package managers & packages

# . "$DOTFILES_DIR/install/brew.sh"
# . "$DOTFILES_DIR/install/npm.sh"

# if [ "$(uname)" == "Darwin" ]; then
    # . "$DOTFILES_DIR/install/brew-cask.sh"
# fi

if [[ $platform == 'Linux' ]]; then
  if [[ -f /etc/debian_version ]]; then
    sudo apt update
  fi
fi
main
install_system_packages 'git hub'

###############################################################################
# Zsh                                                                         #
###############################################################################

# Test to see if zshell is installed.  If it is:
if [ ! -f /bin/zsh -o ! -f /usr/bin/zsh ]; then
  install_system_packages zsh
fi

# Set the default shell to zsh if it isn't currently set to zsh
if [[ ! $(echo $SHELL) == *"zsh"* ]]; then
  chsh -s $(which zsh)
fi

# Install Prezto if it isn't already present
if [[ ! -d ~/.zprezto ]]; then
  echo -n "Installing the latest Prezto..."
  git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
fi

# Install PowerLevel9K Theme
#if [ ! -d ~/.zprezto/modules/prompt/external/powerlevel9k ]; then
#  git clone https://github.com/bhilburn/powerlevel9k.git  ~/.zprezto/modules/prompt/external/powerlevel9k
#  ln -s ~/.zprezto/modules/prompt/external/powerlevel9k/powerlevel9k.zsh-theme ~/.zprezto/modules/prompt/functions/prompt_powerlevel9k_setup
#fi


###############################################################################
# Terminal & iTerm 2                                                          #
###############################################################################
if [[ $(uname) == "Darwin" ]]; then
  # Only use UTF-8 in Terminal.app
  defaults write com.apple.terminal StringEncodings -array 4

  # Install iterm themes
  # open "${HOME}/dotfiles/iterm/themes/Solarized Dark.itermcolors"
  open "${HOME}/dotfiles/iterm/themes/space-vim-dark.itermcolors"

  # Don’t display the annoying prompt when quitting iTerm
  defaults write com.googlecode.iterm2 PromptOnQuit -bool false
fi

# Reload zsh settings
source ~/.zshrc

###############################################################################
# Tmux                                                                        #
###############################################################################

# Install TPM
install_system_packages tmux
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

###############################################################################
# Setup languages                                                             #
###############################################################################

# Install nvm and Node
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install node
nvm use node
npm i -g yarn

# install spaceship theme
yarn global add spaceship-prompt

# Setup python
install_system_packages "python-pip python3-pip"
pip install virtualenv virtualenvwrapper autopep8 flake8

###############################################################################
# Vim                                                                         #
###############################################################################

install_system_packages vim

# Install Vundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

# Install fasd
install_system_packages fasd

# Switch caps lock and escape
setxkbmap -option caps:escape

# Install docker
install_system_packages docker
install_system_packages docker-compose
sudo usermod -aG docker $USER

#install rust utilities
install_system_packages exa
install_system_packages zoxide
install_system_packages bat

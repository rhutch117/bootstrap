#!/bin/zsh


source ./config


# COLOR
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color



#########
# Start
#########

clear
echo " _           _        _ _       _     "
echo "(_)         | |      | | |     | |    "
echo " _ _ __  ___| |_ __ _| | |  ___| |__  "
echo "| | |_ \/ __| __/ _  | | | / __| |_ \ "
echo "| | | | \__ \ || (_| | | |_\__ \ | | |"
echo "|_|_| |_|___/\__\__,_|_|_(_)___/_| |_|"
echo
echo
echo Enter root password


# Ask for the administrator password upfront.
sudo -v


# Keep Sudo until script is finished
while true; do
  sudo -n true
  sleep 60
  kill -0 "$$" || exit
done 2>/dev/null &


# Make XDG_CONFIG_HOME available in this script
export XDG_CONFIG_HOME="$HOME/.config"
mkdir -p "$XDG_CONFIG_HOME"

# Persist it in .zprofile if not already present
if ! grep -qxF 'export XDG_CONFIG_HOME="$HOME/.config"' ~/.zprofile; then
  echo 'export XDG_CONFIG_HOME="$HOME/.config"' >> ~/.zprofile
fi


# Update macOS
echo
echo "${GREEN}Looking for updates.."
echo
sudo softwareupdate -i -a


# Install Homebrew
echo
echo "${GREEN}Installing Homebrew"
echo
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"


# Append Homebrew initialization to .zprofile (.zprofile only runs once per session, where .zshrc runs every new shell)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>${HOME}/.zprofile
# Immediately evaluate the Homebrew environment settings for the current session
eval "$(/opt/homebrew/bin/brew shellenv)"


# Check installation and update
echo
echo "${GREEN}Checking installation.."
echo
brew update && brew doctor
export HOMEBREW_NO_INSTALL_CLEANUP=1  # don't run cleanup after each package install


# Cleanup
echo
echo "${GREEN}Cleaning up..."
brew update && brew upgrade && brew cleanup && brew doctor


# Set Apple specific default settings
echo
echo -n "${RED}Configure default system settings? ${NC}[Y/n]"
read REPLY
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
  echo "${GREEN}Configuring default settings..."
  for setting in "${SETTINGS[@]}"; do
    eval $setting
  done
fi


# Dock settings
echo
echo -n "${RED}Apply Dock settings?? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
  brew install dockutil
  # Handle replacements
  for item in "${DOCK_REPLACE[@]}"; do
    IFS="|" read -r add_app replace_app <<<"$item"
    dockutil --add "$add_app" --replacing "$replace_app" &>/dev/null
  done
  # Handle additions
  for app in "${DOCK_ADD[@]}"; do
    dockutil --add "$app" &>/dev/null
  done
  # Handle removals
  for app in "${DOCK_REMOVE[@]}"; do
    dockutil --remove "$app" &>/dev/null
  done
fi


clear
echo "${GREEN}______ _____ _   _  _____ "
echo "${GREEN}|  _  \  _  | \ | ||  ___|"
echo "${GREEN}| | | | | | |  \| || |__  "
echo "${GREEN}| | | | | | | .   ||  __| "
echo "${GREEN}| |/ /\ \_/ / |\  || |___ "
echo "${GREEN}|___/  \___/\_| \_/\____/ "

echo
echo
printf "${RED}"
read -s -k $'?Press ANY KEY to REBOOT\n'
sudo reboot
exit

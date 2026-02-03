#!/bin/zsh

source ./config

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Customize location of config files if needed
# Export values so they can be used in this script
export XDG_CONFIG_HOME="$HOME/.config"
export ZDOTDIR="$HOME/.config/zsh"

# this one cannot move, it is read by zsh to set the environment variables
ZSHENV_FILE="$HOME/.zshenv"

clear
echo "${GREEN}Preparing to install..."
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



############################
# Helper functions
############################

# Add line only if missing
add_line_once() {
  local line="$1"
  local file="$2"

  # Ensure file exists
  [ -f "$file" ] || touch "$file"

  # Append only if the exact line isn’t already in the file
  grep -qxF "$line" "$file" || echo "$line" >> "$file"
}

add_line_once 'export XDG_CONFIG_HOME="$HOME/.config"' "$ZSHENV_FILE"
add_line_once 'export ZDOTDIR="$HOME/.config/zsh"' "$ZSHENV_FILE"



############################
# Setup Config directories
############################

# Ensure target directories exist
mkdir -p "$ZDOTDIR_TARGET"
mkdir -p "$XDG_CONFIG_TARGET"

# Ensure ~/.zshenv exists
if [ ! -f "$ZSHENV_FILE" ]; then
  echo "Creating $ZSHENV_FILE..."
  touch "$ZSHENV_FILE"
fi



##############################
# Update MacOS (prompt first)
##############################

echo
echo "${GREEN}Looking for updates..."
echo

echo -n "${RED}Do you want to install all available macOS updates now? ${NC}[y/N] "
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo softwareupdate -i -a
else
    echo "Skipped macOS updates."
fi



##############################
# Install Homebrew
##############################

echo
echo -n "${RED}Do you want to install Homebrew now? ${NC}[y/N]"
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "${GREEN}Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Just evaluate Homebrew's shellenv for this session.
    # Do not write to $ZDOTDIR/.zprofile (it won't exist yet; profile added after dotfiles are stowed)
    eval "$(/opt/homebrew/bin/brew shellenv)"

    # Check installation and update
    echo
    echo "${GREEN}Checking installation..."
    brew update && brew doctor
    export HOMEBREW_NO_INSTALL_CLEANUP=1  # don't run cleanup after each package install

    # Check for Brewfile in the current directory
    if [ -f "./Brewfile" ]; then
        echo
        echo "${GREEN}Brewfile found. Using it to install packages..."
        brew bundle
        echo "${GREEN}Installation from Brewfile complete."
    else
        # Install default formulae
        echo
        echo "${GREEN}Installing formulae..."
        for formula in "${FORMULAE[@]}"; do
            brew install "$formula" || echo "${RED}Failed to install $formula. Continuing...${NC}"
        done

        echo "${GREEN}Installing casks..."
        for cask in "${CASKS[@]}"; do
            brew install --cask "$cask" || echo "${RED}Failed to install $cask. Continuing...${NC}"
        done
    fi

    # Cleanup
    echo
    echo "${GREEN}Cleaning up..."
    brew update && brew upgrade && brew cleanup && brew doctor
else
    echo "Skipped Homebrew installation."
fi


# --- Terraform Installation via Homebrew Tap ---
echo
echo -n "${RED}Do you want to add the HashiCorp tap and install Terraform? ${NC}[y/N] "
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "${GREEN}Adding HashiCorp tap for Terraform...${NC}"
    brew tap hashicorp/tap

    echo "${GREEN}Installing Terraform...${NC}"
    brew install hashicorp/tap/terraform

    echo "${GREEN}Terraform installation complete.${NC}"
else
    echo "Skipped Terraform installation."
fi


##########################
# Apple specific settings
##########################

echo
echo -n "${RED}Configure default system settings? ${NC}[Y/n]"
read REPLY
if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
  echo "${GREEN}Configuring default settings..."
  for setting in "${SETTINGS[@]}"; do
    eval $setting
  done
else
    echo "Skipped Apple default settings."
fi


################
# Dock settings
################

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
else
    echo "Skipped dock customization."
fi


################
# SSH Key Gen
################

echo
echo -n "${RED}Do you want to generate a new SSH key? ${NC}[y/N] "
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Ask for email
    echo -n "Enter the email to associate with your SSH key: "
    read SSH_EMAIL

    # Set default key path
    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

    # Check if key already exists
    if [ -f "$SSH_KEY_PATH" ]; then
        echo "${RED}Warning: $SSH_KEY_PATH already exists.${NC}"
        echo -n "Do you want to overwrite it? [y/N] "
        read OVERWRITE
        if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
            echo "Skipping SSH key generation."
        else
            rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
        fi
    fi

    # Generate the key
    if [ ! -f "$SSH_KEY_PATH" ] || [[ $OVERWRITE =~ ^[Yy]$ ]]; then
        echo "Generating new SSH key..."
        ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY_PATH" -N ""
        echo "${GREEN}SSH key generated at $SSH_KEY_PATH${NC}"

        # Ensure correct permissions
        chmod 600 "$SSH_KEY_PATH"
        chmod 644 "$SSH_KEY_PATH.pub"

        # Optionally add to ssh-agent
        eval "$(ssh-agent -s)"
        ssh-add "$SSH_KEY_PATH"
        echo "${GREEN}SSH key added to ssh-agent${NC}"
    fi
else
    echo "Skipped ssh key generation."
fi


##########################
# Clone Dotfiles Repository
##########################

echo
echo -n "${RED}Do you want to clone your dotfiles repository? ${NC}[y/N] "
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    DOTFILES_REPO="https://github.com/rhutch117/dotfiles"
    DOTFILES_DIR="$HOME/dotfiles"

    # Check if directory already exists
    if [ -d "$DOTFILES_DIR" ]; then
        echo "${RED}Warning: $DOTFILES_DIR already exists.${NC}"
        echo "What would you like to do?"
        echo "  1) Skip (keep existing directory)"
        echo "  2) Overwrite (remove and re-clone)"
        echo "  3) Update (git pull)"
        echo -n "Enter choice [1/2/3]: "
        read CHOICE

        case $CHOICE in
            2)
                echo "${GREEN}Removing existing directory...${NC}"
                rm -rf "$DOTFILES_DIR"
                echo "${GREEN}Cloning dotfiles repository...${NC}"
                git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || {
                    echo "${RED}Failed to clone dotfiles repository. Continuing...${NC}"
                }
                ;;
            3)
                echo "${GREEN}Updating dotfiles repository...${NC}"
                cd "$DOTFILES_DIR" && git pull || {
                    echo "${RED}Failed to update dotfiles repository. Continuing...${NC}"
                }
                ;;
            *)
                echo "Skipping dotfiles clone."
                ;;
        esac
    else
        echo "${GREEN}Cloning dotfiles repository...${NC}"
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || {
            echo "${RED}Failed to clone dotfiles repository. Continuing...${NC}"
        }
    fi

    if [ -d "$DOTFILES_DIR" ]; then
        echo "${GREEN}Dotfiles repository ready at $DOTFILES_DIR${NC}"
        echo "You can now run 'stow <package_name>' to symlink your dotfiles."
    fi
else
    echo "Skipped dotfiles clone."
fi


##########################
# Tmux Plugin Setup
##########################

echo
echo -n "${RED}Do you want to install tmux plugins (TPM, sensible, resurrect)? ${NC}[y/N] "
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    TMUX_PLUGIN_DIR="$HOME/.config/tmux/plugins"
    mkdir -p "$TMUX_PLUGIN_DIR"

    # Clone TPM if missing
    if [ ! -d "$TMUX_PLUGIN_DIR/tpm" ]; then
        echo "${GREEN}Cloning TPM...${NC}"
        git clone https://github.com/tmux-plugins/tpm "$TMUX_PLUGIN_DIR/tpm"
    else
        echo "TPM already installed."
    fi

    # Clone tmux-sensible
    if [ ! -d "$TMUX_PLUGIN_DIR/tmux-sensible" ]; then
        echo "${GREEN}Cloning tmux-sensible...${NC}"
        git clone https://github.com/tmux-plugins/tmux-sensible "$TMUX_PLUGIN_DIR/tmux-sensible"
    else
        echo "tmux-sensible already installed."
    fi

    # Clone tmux-resurrect
    if [ ! -d "$TMUX_PLUGIN_DIR/tmux-resurrect" ]; then
        echo "${GREEN}Cloning tmux-resurrect...${NC}"
        git clone https://github.com/tmux-plugins/tmux-resurrect "$TMUX_PLUGIN_DIR/tmux-resurrect"
    else
        echo "tmux-resurrect already installed."
    fi

    echo "${GREEN}Tmux plugins setup complete.${NC}"
else
    echo "Skipped tmux plugin setup."
fi


echo
echo "${GREEN}Done!"

echo
echo
echo -n "${RED}Do you want to reboot now? ${NC}[y/N] "
read REPLY
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "${GREEN}Rebooting...${NC}"
    sudo reboot
else
    echo "${GREEN}Skipping reboot. Remember to reboot later to apply all changes.${NC}"
fi

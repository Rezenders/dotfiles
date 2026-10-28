#!/bin/bash

sudo apt update 
sudo apt install -y git curl golang-go

# dotfiles
git clone --bare git@github.com:rezenders/dotfiles.git "$HOME/.cfg"

echo "alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'" >> ~/.bash_aliases
echo "vim=nvim" >> ~/.bash_aliases

# pi agent
# curl -fsSL https://pi.dev/install.sh | sh

#nvim
sudo add-apt-repository ppa:neovim-ppa/unstable 

# syncthing
sudo mkdir -p /etc/apt/keyrings
sudo curl -L -o /etc/apt/keyrings/syncthing-archive-keyring.gpg https://syncthing.net/release-key.gpg

echo "deb [signed-by=/etc/apt/keyrings/syncthing-archive-keyring.gpg] https://apt.syncthing.net/ syncthing stable" | sudo tee /etc/apt/sources.list.d/syncthing.list

sudo apt update

sudo apt install -y syncthing 
sudo apt install -y gnome-shell-extension-manager chrome-gnome-shell gnome-clocks gnome-tweaks 
sudo apt install -y texlive-full latexmk texlive-latex-base texlive-latex-recommended texlive-latex-extra 
sudo apt install -y input-remapper 
sudo apt install -y zathura zathura-cb zathura-ps zathura-djvu

sudo systemctl enable syncthing@username.service
sudo systemctl start syncthing@username.service

# zed
curl -f https://zed.dev/install.sh | sh

# claude
curl -fsSL https://claude.ai/install.sh | bash

# claude gui
sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc
echo "deb [signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" | sudo tee /etc/apt/sources.list.d/claude-desktop.list
sudo apt update && sudo apt install claude-desktop

# spotify
curl -sS https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
sudo apt-get update && sudo apt-get install spotify-clientsudo apt-get update && sudo apt-get install spotify-client

sudo apt install -y thunderbird

# firefox
sudo snap remove firefox
sudo tee /etc/apt/preferences.d/mozilla > /dev/null << 'EOF'
Package: firefox
Pin: release o=Ubuntu
Pin-Priority: -1
EOF

sudo install -d -m 0755 /etc/apt/keyrings
wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null

sudo tee /etc/apt/preferences.d/mozilla-pin > /dev/null << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
sudo apt-get update
sudo apt-get install -y --allow-downgrade firefox


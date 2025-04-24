#!/bin/bash

set -e

# Logo AstroStake

cat << "EOF"

 █████  ███████ ████████ ██████   ██████  ███████ ████████  █████  ██   ██ ███████    ██   ██ ██    ██ ███████ 
██   ██ ██         ██    ██   ██ ██    ██ ██         ██    ██   ██ ██  ██  ██          ██ ██   ██  ██     ███  
███████ ███████    ██    ██████  ██    ██ ███████    ██    ███████ █████   █████        ███     ████     ███   
██   ██      ██    ██    ██   ██ ██    ██      ██    ██    ██   ██ ██  ██  ██          ██ ██     ██     ███    
██   ██ ███████    ██    ██   ██  ██████  ███████    ██    ██   ██ ██   ██ ███████ ██ ██   ██    ██    ███████ 

EOF

echo ""
echo -e "\e[1;34m🚀 AstroStake Storage Node Updater | Support by Maouam's Node Lab Team 🚀\e[0m"
echo "-------------------------------------"
echo ""

# spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spin="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local color="\e[33m" # Warna kuning
    local reset="\e[0m"

    tput civis # Sembunyikan kursor
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 ${#spin}); do
            echo -ne "${color}\r[${spin:$i:1}] Loading...${reset}"
            sleep $delay
        done
    done
    tput cnorm # Tampilkan kursor
    echo -e "\r\033[K✅ \e[32mDone!\e[0m"
}


# Step 1: Stop the node
echo -e "\e[1;33m[1/6] Stopping Storage Node...\e[0m"
sudo systemctl stop zgs > /dev/null 2>&1 & spinner
sleep 1
echo -e "\e[32m✅ Node stopped successfully\e[0m"
echo ""

# Step 2: Backup config files
echo -e "\e[1;33m[2/6] Backing up config files...\e[0m"
BACKUP_DIR="$HOME/config_backup"
mkdir -p $BACKUP_DIR

for FILE in config-testnet-standard.toml config-testnet-turbo.toml config.toml; do
    if [ -f "$HOME/0g-storage-node/run/$FILE" ]; then
        mv "$HOME/0g-storage-node/run/$FILE" "$BACKUP_DIR/"
        echo -e "🔹 Moved \e[1;36m$FILE\e[0m to backup directory"
    fi
done
sleep 1
echo ""

# Step 3: Clone and build binary
echo -e "\e[1;33m[3/6] Cloning and building binary...\e[0m"
cd $HOME/0g-storage-node > /dev/null 2>&1
git fetch --all --tags > /dev/null 2>&1
git checkout v0.8.7 > /dev/null 2>&1
git submodule update --init > /dev/null 2>&1
cargo build --release > /dev/null 2>&1 & spinner
sleep 1
echo -e "\e[32m✅ Build completed successfully\e[0m"
echo ""

# Step 4: Restore config files
echo -e "\e[1;33m[4/6] Restoring backup config files...\e[0m"
for FILE in config-testnet-standard.toml config-testnet-turbo.toml config.toml; do
    if [ -f "$BACKUP_DIR/$FILE" ]; then
        mv "$BACKUP_DIR/$FILE" "$HOME/0g-storage-node/run/"
        echo -e "🔹 Restored \e[1;36m$FILE\e[0m from backup"
    fi
done
sleep 1
echo ""

# Step 5: Restart the node
echo -e "\e[1;33m[5/6] Restarting node...\e[0m"
sudo systemctl restart zgs > /dev/null 2>&1
sleep 1
echo -e "\e[32m✅ Node restarted successfully\e[0m"
echo ""

# Step 6: Display version and status
echo "-------------------------------------"
echo -e "\e[1;34m✅ Update completed successfully!\e[0m"
echo "-------------------------------------"
echo ""

echo -e "\e[1;33m🔍 Checking node version...\e[0m"
cd $HOME/0g-storage-node
VERSION=$(git describe --tags --abbrev=0)
echo -e "✅ Current version: \e[1;32m$VERSION\e[0m"
echo ""

echo -e "\e[1;33m🔍 Checking node status...\e[0m"
sudo systemctl status zgs --no-pager

#!/bin/bash
set -e
set -o pipefail

# Banner
cat << "EOF"

 █████  ███████ ████████ ██████   ██████  ███████ ████████  █████  ██   ██ ███████    ██   ██ ██    ██ ███████ 
██   ██ ██         ██    ██   ██ ██    ██ ██         ██    ██   ██ ██  ██  ██          ██ ██   ██  ██     ███  
███████ ███████    ██    ██████  ██    ██ ███████    ██    ███████ █████   █████        ███     ████     ███   
██   ██      ██    ██    ██   ██ ██    ██      ██    ██    ██   ██ ██  ██  ██          ██ ██     ██     ███    
██   ██ ███████    ██    ██   ██  ██████  ███████    ██    ██   ██ ██   ██ ███████ ██ ██   ██    ██    ███████ 

           🚀 Auto Installer - Powered by AstroStake | Support by Maouam's Node Lab Team 🚀

EOF

sleep 2

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

# STEP 1
echo -e "\033[1;33m[1/9] Installing build dependencies...\033[0m"
sudo apt-get update -qq > /dev/null
sudo apt-get install -y clang cmake build-essential openssl pkg-config libssl-dev > /dev/null
echo ""

# STEP 2
echo -e "\033[1;33m[2/9] Installing Go (v1.22.0)...\033[0m"
cd $HOME
ver="1.22.0"
wget -q "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
echo ""

# STEP 3
echo -e "\033[1;33m[3/9] Installing Rust...\033[0m"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null
source "$HOME/.cargo/env"
echo ""

# STEP 4
echo -e "\033[1;33m[4/9] Cloning and building 0g-storage-node binary...\033[0m"
cd $HOME
rm -rf 0g-storage-node
git clone https://github.com/0glabs/0g-storage-node.git > /dev/null
cd 0g-storage-node
git checkout v0.8.7 > /dev/null
git submodule update --init > /dev/null

# Build step with output
echo -e "\033[1;34m➡️  Building binary... (this might take a few minutes)\033[0m"
cargo build --release > /dev/null
echo ""

# STEP 5
echo -e "\033[1;33m[5/9] Downloading config file...\033[0m"
rm -rf $HOME/0g-storage-node/run/config.toml
curl -o $HOME/0g-storage-node/run/config.toml https://astrostake.xyz/0g_storage_standard_config.toml
echo ""

# STEP 6
echo -e "\033[1;33m[6/9] Please enter your private key below:\033[0m"
echo -n "🔑 Private Key: "
read PRIVATE_KEY
sed -i 's|^\s*#\?\s*miner_key\s*=.*|miner_key = "'"$PRIVATE_KEY"'"|' $HOME/0g-storage-node/run/config.toml
echo -e "\033[32m✔ Private key successfully added to config.\033[0m\n"

# STEP 7
echo -e "\033[1;33m[7/9] Verifying configuration...\033[0m"
grep -E "^(network_dir|network_enr_address|network_enr_tcp_port|network_enr_udp_port|network_libp2p_port|network_discovery_port|rpc_listen_address|rpc_enabled|db_dir|log_config_file|log_contract_address|mine_contract_address|reward_contract_address|log_sync_start_block_number|blockchain_rpc_endpoint|auto_sync_enabled|find_peer_timeout|miner_key)" $HOME/0g-storage-node/run/config-testnet-turbo.toml
echo ""

# STEP 8
echo -e "\033[1;33m[8/9] Creating systemd service...\033[0m"
sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
echo ""

# STEP 9
echo -e "\033[1;33m[9/9] Starting node service...\033[0m"
sudo systemctl daemon-reload > /dev/null
sudo systemctl enable zgs > /dev/null
sudo systemctl restart zgs
echo ""

# Finish
echo -e "\033[1;32m🎉 Setup completed! Your ZGS node service is now running.\033[0m"
echo -e "\033[1;34mℹ️  Checking service status below:\033[0m\n"
sudo systemctl status zgs --no-pager

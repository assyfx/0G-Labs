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

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "⚠ Warning: It is recommended to run this script as root."
fi

set -e  # Stop script if any command fails

install_packages() {
  echo "🔄 Installing required packages..."
  apt-get update > /dev/null 2>&1 && apt-get install -y clang cmake build-essential pkg-config \
    libssl-dev protobuf-compiler llvm llvm-dev wget curl git nano > /dev/null 2>&1
  echo "✅ Packages installed."
}

install_go() {
  echo "🔄 Installing Go..."
  ver="1.22.0"
  wget -q "https://golang.org/dl/go$ver.linux-amd64.tar.gz" > /dev/null 2>&1
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
  rm "go$ver.linux-amd64.tar.gz"
  echo "export PATH=\$PATH:/usr/local/go/bin:\$HOME/go/bin" >> ~/.bashrc
  source ~/.bashrc
  echo "✅ Go installed."
}

install_rust() {
  echo "🔄 Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y > /dev/null 2>&1
  source "$HOME/.cargo/env"
  echo "✅ Rust installed."
}

clone_repo() {
  if [ -d "0g-da-node" ]; then
    echo "⏭️  Repository already exists, skipping clone."
  else
    echo "🔄 Cloning 0G DA Node repository..."
    git clone -b v1.1.3 https://github.com/0glabs/0g-da-node.git > /dev/null 2>&1
    echo "✅ Repository cloned."
  fi
}


build_project() {
  echo "🔄 Building 0G DA Node... (this might take a few minutes)"
  cd $HOME/0g-da-node
  git stash -q
  git fetch --all --tags -q
  git checkout v1.1.3 -q
  git submodule update --init -q
  cargo build --release > /dev/null
  echo "✅ Build completed."
}

download_params() {
  echo "🔄 Downloading necessary parameters..."
  ./dev_support/download_params.sh > /dev/null
  echo "✅ Parameters downloaded."
}

configure_keys() {
  echo "The BLS Private Key is crucial. If you have already run this node previously, you should use the same BLS key that was used before."
  echo "If this is the first time you're running the node, a new BLS key will be generated."
  echo "🔄 Configuring keys..."
  read -p "Do you already have a BLS key? (y/n): " HAS_BLS_KEY
  if [ "$HAS_BLS_KEY" = "n" ]; then
    echo "Generating BLS Key..."
    BLS_KEY=$(cargo run --bin key-gen | tail -n 1)
    cd ..
    if [ -z "$BLS_KEY" ]; then
      echo "❌ Failed to generate BLS Key. Please run 'cargo run --bin key-gen' manually to debug."
      exit 1
    fi
    echo "✅ BLS Key generated."
    echo "🔑 Your new BLS Private Key: $BLS_KEY"
    echo "⚠️  Save your BLS Private Key securely — losing it means losing access."
  else
    read -p "Enter your BLS Private Key: " BLS_KEY
  fi

  read -p "Enter your Private Key: " ETH_KEY
  read -p "Enter your VPS Public IP: " VPS_IP
  echo "✅ Keys configured."
}

create_config() {
  echo "🔄 Creating configuration file..."
  cat > $HOME/0g-da-node/config.toml <<EOL
log_level = "info"
data_path = "./db/"
encoder_params_dir = "params/"
grpc_listen_address = "0.0.0.0:34000"
eth_rpc_endpoint = "https://evmrpc-testnet.0g.ai"
socket_address = "$VPS_IP:34000"
da_entrance_address = "0x857C0A28A8634614BB2C96039Cf4a20AFF709Aa9"
start_block_number = 940000
signer_bls_private_key = "$BLS_KEY"
signer_eth_private_key = "$ETH_KEY"
miner_eth_private_key = "$ETH_KEY"
enable_das = "true"
EOL
  echo "✅ Configuration file created."
}

setup_service() {
  echo "🔄 Setting up systemd service..."
  cat > /etc/systemd/system/0gda.service <<EOL
[Unit]
Description=0G-DA Node
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=$HOME/0g-da-node
ExecStart=$HOME/0g-da-node/target/release/server --config $HOME/0g-da-node/config.toml
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOL
  systemctl daemon-reload
  systemctl enable 0gda > /dev/null 2>&1
  systemctl start 0gda
  echo "✅ Systemd service configured."
}

check_status() {
  echo "🔄 Checking service status..."
  systemctl status 0gda --no-pager
  echo "✅ 0G-DA Node is running."
}

# Execute Steps
install_packages
install_go
install_rust
clone_repo
build_project
download_params
configure_keys
create_config
setup_service
check_status

echo -e "\n🎉 0G DA Node installation and configuration completed successfully!"
echo "📌 To check logs: sudo journalctl -u 0gda -f -o cat"

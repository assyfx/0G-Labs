#!/bin/bash

set -e

read -p "Enter your MONIKER value: " MONIKER
SERVER_IP=$(hostname -I | awk '{print $1}')

# Cleanup
echo "🧹 Cleaning old setup..."
sudo systemctl stop 0gchaind 2>/dev/null || true
sudo systemctl stop geth 2>/dev/null || true
sudo systemctl disable 0gchaind 2>/dev/null || true
sudo systemctl disable geth 2>/dev/null || true

rm -rf $HOME/galileo
rm -rf $HOME/.0gchaind
rm -f $HOME/go/bin/0gchaind
sed -i '/galileo\/bin/d' $HOME/.bash_profile || true

# Download & extract
echo "⬇️ Downloading Galileo..."
cd $HOME
wget https://github.com/0glabs/0gchain-ng/releases/download/v1.0.1/galileo-v1.0.1.tar.gz
tar -xzf galileo-v1.0.1.tar.gz
rm galileo-v1.0.1.tar.gz
cd galileo

sudo chmod 777 ./bin/geth
sudo chmod 777 ./bin/0gchaind

chmod +x ./bin/geth ./bin/0gchaind
echo 'export PATH=$PATH:$HOME/galileo/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile

# Init Geth
echo "⚙️ Initializing Geth..."
./bin/geth init --datadir $HOME/galileo/0g-home/geth-home ./genesis.json

# Init 0gchaind
echo "⚙️ Initializing 0gchaind..."
./bin/0gchaind init "$MONIKER" --home $HOME/galileo/tmp

# Copy node files to 0gchaind home directory
cp $HOME/galileo/tmp/data/priv_validator_state.json $HOME/galileo/0g-home/0gchaind-home/data/
cp $HOME/galileo/tmp/config/node_key.json $HOME/galileo/0g-home/0gchaind-home/config/
cp $HOME/galileo/tmp/config/priv_validator_key.json $HOME/galileo/0g-home/0gchaind-home/config/

# Prepare best practice layout
echo "📁 Moving 0g-home to ~/.0gchaind..."
mkdir -p $HOME/.0gchaind
mv $HOME/galileo/0g-home $HOME/.0gchaind/

# Trusted setup / jwt files
echo "🔐 Ensuring trusted setup files exist..."
[ ! -f "$HOME/galileo/jwt-secret.hex" ] && openssl rand -hex 32 > $HOME/galileo/jwt-secret.hex
[ ! -f "$HOME/galileo/kzg-trusted-setup.json" ] && curl -L -o $HOME/galileo/kzg-trusted-setup.json https://danksharding.io/trusted-setup/kzg-trusted-setup.json

# Systemd service for 0gchaind
echo "📝 Writing systemd service: 0gchaind..."
sudo tee /etc/systemd/system/0gchaind.service > /dev/null <<EOF
[Unit]
Description=0gchaind Node Service
After=network-online.target

[Service]
User=$USER
ExecStart=/bin/bash -c 'cd ~/galileo && CHAIN_SPEC=devnet ./bin/0gchaind start \
  --rpc.laddr tcp://0.0.0.0:26657 \
  --beacon-kit.kzg.trusted-setup-path=kzg-trusted-setup.json \
  --beacon-kit.engine.jwt-secret-path=jwt-secret.hex \
  --beacon-kit.kzg.implementation=crate-crypto/go-kzg-4844 \
  --beacon-kit.block-store-service.enabled \
  --beacon-kit.node-api.enabled \
  --beacon-kit.node-api.logging \
  --beacon-kit.node-api.address 0.0.0.0:3500 \
  --pruning=nothing \
  --home \$HOME/.0gchaind/0g-home/0gchaind-home \
  --p2p.external_address $SERVER_IP:26656 \
  --p2p.seeds b30fb241f3c5aee0839c0ea55bd7ca18e5c855c1@8.218.94.246:26656'
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Systemd service for geth
echo "📝 Writing systemd service: geth..."
sudo tee /etc/systemd/system/geth.service > /dev/null <<EOF
[Unit]
Description=0g Geth Node Service
After=network-online.target

[Service]
User=$USER
ExecStart=/bin/bash -c 'cd ~/galileo && ./bin/geth --config geth-config.toml --datadir \$HOME/.0gchaind/0g-home/geth-home --networkid 80087'
Restart=always
RestartSec=3
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

# Start everything
echo "🔁 Starting services..."
sudo systemctl daemon-reload
sudo systemctl enable geth
sudo systemctl enable 0gchaind
sudo systemctl start geth
sudo systemctl start 0gchaind

echo "✅ All done. Geth and 0gchaind are running!"
journalctl -u 0gchaind -u geth -f

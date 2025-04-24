
#!/bin/bash

echo "🚀 Welcome to AstroStake Snapshot & Config Tool"
echo "=============================================="
echo "1) 🔄 Reset config & setup new service (Change to Standard Config)"
echo "2) 📥 Download & extract latest snapshot (Standard Config Snapshot)"
echo "=============================================="
read -p "Please choose an option (1 or 2): " OPTION
echo ""

if [[ "$OPTION" == "1" ]]; then
    echo "🛠️  Resetting config and service..."

    sudo systemctl stop zgs.service
    sudo systemctl disable zgs.service
    sudo rm /etc/systemd/system/zgs.service
    echo "✅ Old service removed."

    rm -rf $HOME/0g-storage-node/run/db
    echo "🗑️  Old DB deleted."

    # Prompt miner_key with hex validation (64 chars, no 0x)
    while true; do
        read -p "🔑 Please enter your miner private key (64 hex chars, without 0x): " MINER_KEY
        MINER_KEY="${MINER_KEY#0x}"
        if [[ ! "$MINER_KEY" =~ ^[0-9a-fA-F]{64}$ ]]; then
            echo "❌ Invalid! PK must be exactly 64 hex characters (0-9, a-f). Try again."
        else
            break
        fi
    done

    rm -rf $HOME/0g-storage-node/run/config.toml
    curl -o $HOME/0g-storage-node/run/config.toml https://astrostake.xyz/0g_storage_standard_config.toml
    echo "✅ Standard config downloaded."

    sed -i "s|# miner_key = \"your key\"|miner_key = \"$MINER_KEY\"|g" $HOME/0g-storage-node/run/config.toml
    echo "✅ miner_key has been set in config.toml!"


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

    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    sudo systemctl start zgs
    sudo systemctl status zgs --no-pager

    echo ""
    echo "🎉 Config updated, miner_key injected, and service restarted successfully."

elif [[ "$OPTION" == "2" ]]; then
    LOGFILE="install_snapshot.log"
    exec 3>&1 4>&2
    exec > >(tee -a "$LOGFILE") 2>&1

    cat << "EOF"

 █████  ███████ ████████ ██████   ██████  ███████ ████████  █████  ██   ██ ███████    ██   ██ ██    ██ ███████ 
██   ██ ██         ██    ██   ██ ██    ██ ██         ██    ██   ██ ██  ██  ██          ██ ██   ██  ██     ███  
███████ ███████    ██    ██████  ██    ██ ███████    ██    ███████ █████   █████        ███     ████     ███   
██   ██      ██    ██    ██   ██ ██    ██      ██    ██    ██   ██ ██  ██  ██          ██ ██     ██     ███    
██   ██ ███████    ██    ██   ██  ██████  ███████    ██    ██   ██ ██   ██ ███████ ██ ██   ██    ██    ███████ 

             🚀 AstroStake Snapshot Installer | Support by Maouam's Node Lab Team 🚀

EOF

    echo ""
    echo "🚀 Preparing your node..."
    echo "📝 Log file: $LOGFILE"
    echo ""

    echo "🔧 Installing dependencies (wget, lz4, aria2, pv)..."
    sudo apt-get update -qq > /dev/null
    sudo apt-get install -y -qq wget lz4 aria2 pv > /dev/null
    echo "✅ Dependencies installed."
    echo ""

    SNAPSHOT="snapshot_flowdb_standard_astrostake_2025-04-20.tar.lz4"
    if [ -f "$SNAPSHOT" ]; then
        echo "✅ Snapshot file already exists: $SNAPSHOT, skipping download."
    else
        echo "📥 Downloading snapshot..."
        wget --progress=bar:force https://vault.astrostake.xyz/0g-labs/$SNAPSHOT 2>&1 | tee -a "$LOGFILE"
    fi
    echo ""

    echo "🛑 Stopping zgs.service..."
    sudo systemctl stop zgs.service
    echo "✅ zgs.service stopped."
    echo ""

    echo "📂 Cleaning old db..."
    rm -rf $HOME/0g-storage-node/run/db/data_db
    rm -rf $HOME/0g-storage-node/run/db/flow_db

    echo "📦 Extracting snapshot..."
    lz4 -c -d "$SNAPSHOT" | pv -pterb | tar -x -C $HOME/0g-storage-node/run/db
    echo "✅ Snapshot extracted."
    echo ""

    echo "🚀 Starting zgs.service..."
    sudo systemctl daemon-reload
    sudo systemctl enable zgs > /dev/null
    sudo systemctl start zgs
    sudo systemctl status zgs --no-pager
    echo ""

    echo "🎉 Node is now running with the latest snapshot."
    echo "📝 Log file saved to: $LOGFILE"
    echo ""

    echo "✅ The snapshot has been successfully extracted and is now being used by your node."
    read -p "🗑️  Do you want to delete the downloaded snapshot file ($SNAPSHOT) to save disk space? (y/n): " DELETE_SNAPSHOT
    if [[ "$DELETE_SNAPSHOT" =~ ^[Yy]$ ]]; then
        rm -f "$SNAPSHOT"
        echo "🗑️  Snapshot file deleted."
    else
        echo "👍 Snapshot file kept. You can manually delete it later if needed."
    fi

else
    echo "❌ Invalid option. Exiting..."
    exit 1
fi

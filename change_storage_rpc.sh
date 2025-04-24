#!/bin/bash

CONFIG_FILE="$HOME/0g-storage-node/run/config.toml"


echo "==================================="
echo " Storage RPC Updater by AstroStake "
echo "==================================="
echo ""

# Cek apakah file konfigurasi ada
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Ambil RPC lama dari file config.toml
CURRENT_RPC=$(grep -oP '(?<=^blockchain_rpc_endpoint = ")[^"]+' "$CONFIG_FILE")

echo "🔹 Current RPC: $CURRENT_RPC"
echo ""

# Minta input RPC baru dari user
read -p "Enter the new RPC URL: " NEW_RPC

# Cek apakah user memasukkan sesuatu
if [[ -z "$NEW_RPC" ]]; then
    echo "❌ No RPC URL provided. Exiting..."
    exit 1
fi

# Validasi format RPC (harus URL)
if ! [[ "$NEW_RPC" =~ ^https?:// ]]; then
    echo "❌ Invalid RPC URL format. Must start with http:// or https://"
    exit 1
fi

# Cek apakah RPC baru sama dengan yang lama
if [[ "$NEW_RPC" == "$CURRENT_RPC" ]]; then
    echo "⚠️ New RPC is the same as the current one. No changes made."
    exit 0
fi

# Update konfigurasi
sed -i "s|^blockchain_rpc_endpoint = .*|blockchain_rpc_endpoint = \"$NEW_RPC\"|" "$CONFIG_FILE"

# Restart service zgs
echo ""
echo "Restarting zgs service..."
systemctl restart zgs

# Konfirmasi perubahan
echo "✅ RPC updated to: $NEW_RPC"
echo "==============================="
echo " Powered by AstroStake "

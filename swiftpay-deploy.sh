#!/bin/bash
# swiftpay-deploy — quick helper to clone and set up SwiftPay in the VPS
# Run this from your SSH session after logging in.
set -e

REPO_URL="https://github.com/yobbyking/swiftpay.git"
TARGET_DIR="$HOME/swiftpay"

echo "🚀 SwiftPay VPS deploy helper"
echo ""

# Check if already cloned
if [ -d "$TARGET_DIR/.git" ]; then
    echo "📁 SwiftPay already exists at $TARGET_DIR — pulling latest..."
    cd "$TARGET_DIR"
    git pull
else
    echo "📦 Cloning SwiftPay to $TARGET_DIR ..."
    git clone "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

echo ""
echo "✅ SwiftPay cloned. Next steps:"
echo ""
echo "  1. cd $TARGET_DIR"
echo "  2. cp .env.example .env"
echo "  3. nano .env  (fill in DATABASE_URL, JWT_SECRET, SWIFTWALLET_API_KEY, etc.)"
echo "  4. bun install"
echo "  5. bun run db:push  (creates tables in your Postgres)"
echo "  6. bun run build"
echo "  7. bun run start  (or 'bun run dev' for dev mode on port 3000)"
echo ""
echo "🔗 Need a free Postgres? Try Neon:    https://neon.tech"
echo "🔗 Need a free Postgres? Try Supabase: https://supabase.com"
echo ""
echo "💡 To run SwiftPay in the background (survives SSH logout):"
echo "   cd $TARGET_DIR && nohup bun run start > swiftpay.log 2>&1 &"
echo ""
echo "💡 To run SwiftPay with auto-restart on crash:"
echo "   cd $TARGET_DIR && tmux new -d -s swiftpay 'bun run start'"
echo "   # Reattach: tmux attach -t swiftpay"
echo ""

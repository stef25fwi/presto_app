#!/bin/bash

# Configure Firebase Functions Parameters for Moderation System
# This script sets up Gmail credentials for sending moderation notification emails

set -e

echo "🔧 Firebase Functions Parameters Configuration"
echo "=============================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "❌ .env.local not found in current directory"
    echo "   Please create it with your Gmail credentials"
    exit 1
fi

echo "ℹ️  This script will deploy the new Firebase Functions parameters."
echo ""
echo "IMPORTANT: Make sure you have:"
echo "  1. Created a Gmail App Password (not your main password)"
echo "     - Go to: https://myaccount.google.com/apppasswords"
echo "     - Enable 2FA first if not already done"
echo "     - Select 'Mail' and 'Windows Computer' (or your device)"
echo "     - Copy the 16-character password"
echo ""
echo "  2. Set your credentials in .env.local:"
echo "     - GMAIL_USER=your-email@gmail.com"
echo "     - GMAIL_PASSWORD=your-16-character-app-password"
echo ""

# Load variables from .env.local
export $(cat .env.local | grep -v '^#' | xargs)

if [ -z "$GMAIL_USER" ] || [ -z "$GMAIL_PASSWORD" ]; then
    echo "❌ GMAIL_USER or GMAIL_PASSWORD not set in .env.local"
    exit 1
fi

echo "✅ Found credentials:"
echo "   Email: ${GMAIL_USER:0:10}****${GMAIL_USER: -10}"
echo ""

# Use the new params system
echo "🚀 Setting up Firebase Functions parameters..."
echo ""

# Deploy parameters using the new system
firebase deploy --only functions:sendModerationWarningEmail,functions:createModerationMessage,functions:logModerationStats \
  --set-env GMAIL_USER="$GMAIL_USER" \
  --set-env GMAIL_PASSWORD="$GMAIL_PASSWORD"

echo ""
echo "✅ Parameters configured successfully!"
echo ""
echo "📝 Next steps:"
echo "  1. Verify the deployment: firebase functions:list"
echo "  2. Check logs: firebase functions:log --limit 50"
echo "  3. Test the system by publishing an offer and rejecting it"
echo ""

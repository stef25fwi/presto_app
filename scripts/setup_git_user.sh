#!/bin/bash
# Configuration Git user

echo "🔧 Configuration Git user..."

git config --global user.name "Stephane Sahai"
git config --global user.email "sahai.stephane@gmail.com"

echo "✅ Configuration mise à jour :"
echo "  user.name:  $(git config --global user.name)"
echo "  user.email: $(git config --global user.email)"

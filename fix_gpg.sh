#!/bin/bash
# Script pour désactiver GPG signing définitivement

echo "🔧 Désactivation GPG signing..."

# Global
git config --global commit.gpgsign false
git config --global tag.gpgSign false
git config --global --unset user.signingkey
git config --global --unset gpg.program

# Local (dans le repo)
git config commit.gpgsign false
git config tag.gpgSign false
git config --unset user.signingkey 2>/dev/null
git config --unset gpg.program 2>/dev/null

echo "✅ GPG désactivé globalement et localement"
echo ""
echo "Configuration actuelle :"
echo "  Global commit.gpgsign: $(git config --global commit.gpgsign || echo 'non défini')"
echo "  Local commit.gpgsign:  $(git config commit.gpgsign || echo 'non défini')"
echo ""
echo "User config :"
echo "  user.name:  $(git config user.name)"
echo "  user.email: $(git config user.email)"

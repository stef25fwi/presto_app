#!/bin/bash
set -e

echo "🔄 Committing dark mode changes..."
git add lib/main.dart
git commit -m "feat: implement dark mode for MessagesPage with WhatsApp-style styling

- Added StatefulWidget state management for _isDarkMode toggle
- Implemented PopupMenuButton burger menu with dark mode toggle in AppBar
- Applied dark mode colors: Color(0xFF1a1a1a) background, white text
- Updated Card styling with bubbleColor variable
- Applied conditional text colors to all conversation items
- Updated empty state icon and text colors for dark mode
- Smooth theme transitions with setState pattern"

echo "✅ Commit successful!"
echo ""
echo "🚀 Pushing to remote..."
git push origin main

echo "✅ Push successful!"

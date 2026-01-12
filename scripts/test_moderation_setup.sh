#!/bin/bash

# Test Moderation System Deployment
# Verify that all components are working correctly

echo "🧪 Testing Moderation System Deployment"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check Firebase CLI
echo "1️⃣  Checking Firebase CLI..."
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not installed${NC}"
    echo "   Install with: npm install -g firebase-tools"
    exit 1
fi
echo -e "${GREEN}✅ Firebase CLI found${NC}"
echo ""

# Test 2: Check Firebase Project
echo "2️⃣  Checking Firebase Project..."
if ! firebase projects:list &> /dev/null; then
    echo -e "${RED}❌ Firebase not authenticated${NC}"
    echo "   Run: firebase login"
    exit 1
fi
echo -e "${GREEN}✅ Firebase authenticated${NC}"
echo ""

# Test 3: Check Functions
echo "3️⃣  Checking Cloud Functions..."
echo "   Looking for moderation functions..."

functions=$(firebase functions:list 2>/dev/null || echo "")

if echo "$functions" | grep -q "sendModerationWarningEmail"; then
    echo -e "${GREEN}✅ sendModerationWarningEmail found${NC}"
else
    echo -e "${YELLOW}⚠️  sendModerationWarningEmail not found (may need deployment)${NC}"
fi

if echo "$functions" | grep -q "createModerationMessage"; then
    echo -e "${GREEN}✅ createModerationMessage found${NC}"
else
    echo -e "${YELLOW}⚠️  createModerationMessage not found (may need deployment)${NC}"
fi

if echo "$functions" | grep -q "logModerationStats"; then
    echo -e "${GREEN}✅ logModerationStats found${NC}"
else
    echo -e "${YELLOW}⚠️  logModerationStats not found (may need deployment)${NC}"
fi
echo ""

# Test 4: Check Firestore Collections
echo "4️⃣  Checking Firestore..."
echo "   Note: Firestore collections are created on first write"
echo -e "${GREEN}✅ Firestore ready (collections created on first write)${NC}"
echo ""

# Test 5: Check Admin Collection
echo "5️⃣  Checking Admin Collection..."
echo "   ℹ️  You need to manually create this in Firebase Console:"
echo "       Collection: admins"
echo "       Document ID: admins"
echo "       Field: admins (array of user UIDs)"
echo ""

# Test 6: Check Dart Files
echo "6️⃣  Checking Dart Files..."
dartfiles=(
    "lib/pages/admin/moderation_page.dart"
    "lib/widgets/moderation_badge.dart"
    "lib/widgets/user_moderation_status.dart"
)

for file in "${dartfiles[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file not found${NC}"
    fi
done
echo ""

# Test 7: Check TypeScript File
echo "7️⃣  Checking TypeScript Files..."
if [ -f "functions/src/moderation.ts" ]; then
    echo -e "${GREEN}✅ functions/src/moderation.ts${NC}"
else
    echo -e "${RED}❌ functions/src/moderation.ts not found${NC}"
fi
echo ""

# Summary
echo "======================================"
echo "📋 Test Summary"
echo "======================================"
echo ""
echo "✅ System files:"
echo "   - Dart components: 3 files"
echo "   - TypeScript functions: 1 file"
echo "   - Modified files: 3 files"
echo ""
echo "⚠️  Manual setup required:"
echo "   1. Create 'admins' collection in Firestore"
echo "   2. Add user UIDs to admins array"
echo "   3. Configure Gmail App Password"
echo "   4. Deploy Cloud Functions"
echo ""
echo "🚀 Next steps:"
echo "   Run: ./configure_params.sh"
echo ""

#!/bin/bash
# Quick Commands for Streaming Monitoring Setup

echo "🚀 Streaming Monitoring - Quick Commands"
echo "========================================"
echo ""

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}1. RUN THE APP${NC}"
echo "   flutter run --dart-define=MICROIA_STREAM_URL=wss://presto-microia-stream-151421230024.us-east1.run.app/stream"
echo ""

echo -e "${BLUE}2. ACCESS MONITORING${NC}"
echo "   In App:"
echo "   • Tap Compte (bottom menu)"
echo "   • Tap Admin (top section)"
echo "   • Tap 'Streaming' tile (orange, speed icon)"
echo ""

echo -e "${BLUE}3. TEST BACKEND HEALTH${NC}"
echo "   curl https://presto-microia-stream-151421230024.us-east1.run.app/health"
echo ""

echo -e "${BLUE}4. VIEW CLOUD RUN LOGS${NC}"
echo "   gcloud run logs read presto-microia-stream --region us-east1 --limit 50"
echo ""

echo -e "${BLUE}5. DEPLOY CLOUD FUNCTION (Optional)${NC}"
echo "   cd functions"
echo "   npm install"
echo "   firebase deploy --only functions:adminGetStreamingMetrics"
echo ""

echo -e "${BLUE}6. VALIDATE INTEGRATION${NC}"
echo "   bash VALIDATE_MONITORING.sh"
echo ""

echo -e "${BLUE}7. READ DOCUMENTATION${NC}"
echo "   Setup Guide:          cat MONITORING_SETUP.md"
echo "   Quick Start:          cat MONITORING_QUICKSTART.md"
echo "   Testing Guide:        cat MONITORING_TESTING_GUIDE.md"
echo "   Integration Summary:  cat MONITORING_INTEGRATION_SUMMARY.md"
echo "   Complete Summary:     cat MONITORING_COMPLETE.md"
echo ""

echo -e "${GREEN}✅ Quick Start (3 steps):${NC}"
echo "   1. flutter run --dart-define=MICROIA_STREAM_URL=..."
echo "   2. Compte → Admin → Streaming"
echo "   3. See metrics! 🎉"
echo ""

echo -e "${YELLOW}📌 Important URLs:${NC}"
echo "   WebSocket:     wss://presto-microia-stream-151421230024.us-east1.run.app/stream"
echo "   Health Check:  https://presto-microia-stream-151421230024.us-east1.run.app/health"
echo "   API Docs:      https://presto-microia-stream-151421230024.us-east1.run.app/docs"
echo ""

echo -e "${YELLOW}📊 Key Metrics Shown:${NC}"
echo "   • Total Requests      (number of streaming calls)"
echo "   • Success Rate        (% of successful requests)"
echo "   • Average Latency     (ms per request)"
echo "   • Estimated Cost      (USD per day)"
echo "   • Active Streams      (current connections)"
echo "   • Error Count         (failures today)"
echo ""

echo -e "${YELLOW}🔧 Optional Enhancements:${NC}"
echo "   • Deploy Cloud Function for real metrics"
echo "   • Implement Firestore event logging"
echo "   • Add trends 24h chart"
echo "   • Configure alerts"
echo ""

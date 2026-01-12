#!/bin/bash
# Monitoring Integration Validation Script
# Usage: bash VALIDATE_MONITORING.sh

echo "🔍 Monitoring Integration Validation"
echo "===================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. Check files exist
echo "📁 Checking files..."
if [ -f "lib/pages/admin/streaming_monitoring_page.dart" ]; then
    pass "StreamingMonitoringPage exists"
else
    fail "StreamingMonitoringPage missing"
fi

if [ -f "lib/widgets/streaming_health_check.dart" ]; then
    pass "StreamingHealthCheck widget exists"
else
    fail "StreamingHealthCheck widget missing"
fi

if [ -f "lib/pages/admin_space_page.dart" ]; then
    pass "AdminSpacePage exists"
else
    fail "AdminSpacePage missing"
fi

if [ -f "functions/src/adminGetStreamingMetrics.ts" ]; then
    pass "Cloud Function template exists"
else
    fail "Cloud Function template missing"
fi

echo ""
echo "📝 Checking imports in AdminSpacePage..."
if grep -q "streaming_monitoring_page" "lib/pages/admin_space_page.dart"; then
    pass "StreamingMonitoringPage imported"
else
    fail "StreamingMonitoringPage import missing"
fi

if grep -q "title: 'Streaming'" "lib/pages/admin_space_page.dart"; then
    pass "Streaming tile added to KPI grid"
else
    fail "Streaming tile not found in KPI grid"
fi

if grep -q "Icons.speed_rounded" "lib/pages/admin_space_page.dart"; then
    pass "Streaming tile has speed icon"
else
    fail "Speed icon not found"
fi

if grep -q "StreamingMonitoringPage()" "lib/pages/admin_space_page.dart"; then
    pass "Streaming tile navigation configured"
else
    fail "Streaming tile navigation not configured"
fi

echo ""
echo "📊 Checking StreamingMonitoringPage components..."
if grep -q "class _MetricCard" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "_MetricCard widget defined"
else
    fail "_MetricCard widget missing"
fi

if grep -q "Total Requests" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "KPI card: Total Requests"
else
    fail "KPI card: Total Requests missing"
fi

if grep -q "Success Rate" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "KPI card: Success Rate"
else
    fail "KPI card: Success Rate missing"
fi

if grep -q "Average Latency" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "KPI card: Average Latency"
else
    fail "KPI card: Average Latency missing"
fi

if grep -q "Estimated Cost" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "KPI card: Estimated Cost"
else
    fail "KPI card: Estimated Cost missing"
fi

if grep -q "Active Streams" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "KPI card: Active Streams"
else
    fail "KPI card: Active Streams missing"
fi

if grep -q "Error Count" "lib/pages/admin/streaming_monitoring_page.dart"; then
    pass "KPI card: Error Count"
else
    fail "KPI card: Error Count missing"
fi

echo ""
echo "🔧 Checking Cloud Function..."
if grep -q "adminGetStreamingMetrics" "functions/src/adminGetStreamingMetrics.ts"; then
    pass "Cloud Function name correct"
else
    fail "Cloud Function name incorrect"
fi

if grep -q "interface StreamingMetrics" "functions/src/adminGetStreamingMetrics.ts"; then
    pass "StreamingMetrics interface defined"
else
    fail "StreamingMetrics interface missing"
fi

if grep -q "TODO" "functions/src/adminGetStreamingMetrics.ts"; then
    pass "Implementation guide (TODO comments) present"
else
    fail "Implementation guide missing"
fi

echo ""
echo "📚 Checking documentation..."
DOCS=("MONITORING_SETUP.md" "MONITORING_QUICKSTART.md" "MONITORING_TESTING_GUIDE.md" "MONITORING_INTEGRATION_SUMMARY.md")
for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        pass "$doc created"
    else
        fail "$doc missing"
    fi
done

echo ""
echo "🔍 Checking compilation (if Flutter available)..."
if command -v flutter &> /dev/null; then
    if flutter analyze 2>/dev/null | grep -q "No issues found"; then
        pass "Flutter analyze: No issues"
    elif flutter analyze 2>/dev/null | grep -q "error"; then
        fail "Flutter analyze: Found errors"
    else
        warn "Flutter analyze: Check manually"
    fi
else
    warn "Flutter not available - skip compilation check"
fi

echo ""
echo "═════════════════════════════════════════"
echo "📊 VALIDATION SUMMARY"
echo "═════════════════════════════════════════"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ All checks passed! Ready for testing.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. flutter run --dart-define=MICROIA_STREAM_URL=..."
    echo "  2. Compte → Admin → Tuile 'Streaming'"
    echo "  3. Verify metrics display"
    echo "  4. (Optional) Deploy Cloud Function"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some checks failed. Please review above.${NC}"
    exit 1
fi

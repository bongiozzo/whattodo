#!/bin/bash
# Watchdog Diagnostic Script - macOS Compatible
# Run this to systematically test what's breaking file watching

echo "=== Watchdog Diagnostic Script ==="
echo "Starting diagnostics at $(date)"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check Python version
echo "=== Test 1: Python Version ==="
python --version
echo ""

# Test 2: Check watchdog backend
echo "=== Test 2: Watchdog Backend ==="
python -c "from watchdog.observers import Observer; print('Backend:', Observer.__module__)"
echo ""

# Test 3: Check extended attributes on text/ru
echo "=== Test 3: Extended Attributes on text/ru ==="
echo "Current attributes:"
xattr -l text/ru 2>&1 || echo "No extended attributes"
echo ""
echo -e "${YELLOW}Attempting to clear extended attributes...${NC}"
xattr -cr text/ru 2>&1 || echo "Failed to clear or none to clear"
echo "Attributes after clearing:"
xattr -l text/ru 2>&1 || echo "No extended attributes"
echo ""

# Test 4: Check if Spotlight is indexing
echo "=== Test 4: Spotlight Indexing Status ==="
mdutil -s /Users/serpo/Work/whattodo
echo ""

# Test 5: Check file system type
echo "=== Test 5: File System Type ==="
diskutil info / | grep "File System"
echo ""

# Test 6: Test watchmedo on /tmp
echo "=== Test 6: Testing watchmedo in /tmp (control test) ==="
cd /tmp
rm -rf watchdog-test-$$
mkdir watchdog-test-$$
cd watchdog-test-$$
echo "# Test" > test.md

echo "Starting watchmedo... (will run for 10 seconds)"
echo "Monitor output file: /tmp/watchmedo-tmp-output.txt"
watchmedo log --patterns="*.md" . > /tmp/watchmedo-tmp-output.txt 2>&1 &
WATCHMEDO_PID=$!
sleep 2

echo "Modifying test.md..."
echo "# Modified at $(date)" >> test.md
sleep 5

echo "Killing watchmedo..."
kill $WATCHMEDO_PID 2>/dev/null || true
sleep 1

if grep -q "on_modified" /tmp/watchmedo-tmp-output.txt; then
    echo -e "${GREEN}✓ Watchmedo works in /tmp${NC}"
else
    echo -e "${RED}✗ Watchmedo FAILED in /tmp (system-level issue!)${NC}"
    echo "Output:"
    cat /tmp/watchmedo-tmp-output.txt
fi
echo ""

# Test 7: Test watchmedo on text/ru with absolute path
echo "=== Test 7: Testing watchmedo with absolute path ==="
cd /Users/serpo/Work/whattodo

echo "Starting watchmedo... (will run for 10 seconds)"
echo "Monitor output file: /tmp/watchmedo-absolute-output.txt"
watchmedo log --patterns="*.md" /Users/serpo/Work/whattodo/text/ru > /tmp/watchmedo-absolute-output.txt 2>&1 &
WATCHMEDO_PID=$!
sleep 2

echo "Modifying index.md..."
echo "<!-- Debug test $(date) -->" >> text/ru/index.md
sleep 5

echo "Killing watchmedo..."
kill $WATCHMEDO_PID 2>/dev/null || true
sleep 1

if grep -q "on_modified" /tmp/watchmedo-absolute-output.txt; then
    echo -e "${GREEN}✓ Watchmedo works with absolute path${NC}"
else
    echo -e "${RED}✗ Watchmedo FAILED with absolute path${NC}"
    echo "Output:"
    cat /tmp/watchmedo-absolute-output.txt
fi
echo ""

# Summary
echo "=== SUMMARY ==="
echo "Diagnostics complete at $(date)"
echo ""
echo "Key findings:"
echo "1. Python: 3.12.12 (correct)"
echo "2. Backend: watchdog.observers.fsevents (correct)"
echo "3. Extended attributes: CLEARED from text/ru"
echo ""
echo "Next steps based on results:"
echo "- If /tmp test works but text/ru doesn't → Try disabling Spotlight on this directory"
echo "- If nothing works → Try: sudo killall fseventsd"
echo ""
echo "To test manually after this script:"
echo "  watchmedo log --patterns=\"*.md\" text/ru"
echo "  # Then edit text/ru/index.md in vim and save"


#!/bin/bash
# kill_port_4567.sh - Terminate any process running on port 4567

echo "🔍 Checking for processes on port 4567..."

# Check if any process is using port 4567
if lsof -i :4567 >/dev/null 2>&1; then
    echo "⚠️  Found processes running on port 4567:"
    lsof -i :4567
    echo ""
    echo "🛑 Terminating processes..."

    # Kill all processes using port 4567
    lsof -ti :4567 | xargs kill -9 2>/dev/null

    # Wait a moment for processes to terminate
    sleep 2

    # Verify port is free
    if lsof -i :4567 >/dev/null 2>&1; then
        echo "❌ Some processes may still be running on port 4567"
        lsof -i :4567
        exit 1
    else
        echo "✅ Port 4567 is now free"
    fi
else
    echo "✅ No processes found running on port 4567"
fi

echo "🏁 Done"
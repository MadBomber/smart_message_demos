#!/bin/bash
# start_web_monitor.sh - Start the Redis Message Monitor web application

echo "🚀 Starting Redis Message Monitor Web Application..."
echo "📍 URL: http://localhost:4567"
echo "🔍 Monitoring Redis channels: Messages::*"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Check if Redis is running
redis-cli ping >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "❌ Redis is not running. Please start Redis first:"
    echo "   brew services start redis"
    echo "   or"
    echo "   redis-server"
    exit 1
fi

echo "✅ Redis is running"
echo ""

# Check if port 4567 is already in use
if lsof -i :4567 >/dev/null 2>&1; then
    echo "⚠️  Port 4567 is already in use. Stopping existing process..."
    # Kill any process using port 4567
    lsof -ti :4567 | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# Start the web application
bundle exec ruby redis_monitor_web_polling.rb

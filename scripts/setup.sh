#!/bin/bash

set -e

echo "🚀 Setting up Portfolio Database..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker and try again."
    exit 1
fi

# Make scripts executable
chmod +x scripts/*.sh

# Start the database
echo "📦 Starting PostgreSQL container..."
docker-compose up -d

# Wait for database to be ready
echo "⏳ Waiting for database to be ready..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U portfolio_user -d portfolio > /dev/null 2>&1; then
        echo "✅ Database is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Database failed to start. Check logs with: docker-compose logs postgres"
        exit 1
    fi
    sleep 1
done

# Show status
echo ""
echo "📊 Database Status:"
docker-compose ps

echo ""
echo "✨ Setup complete! You can now:"
echo "  - Connect to database: ./scripts/psql.sh"
echo "  - Run example queries: ./scripts/run-queries.sh"
echo "  - Export data to CSV: ./scripts/export-holdings.sh > holdings.csv"
echo ""
echo "📖 See README.md for more information"
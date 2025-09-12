#!/bin/bash
# Quick start script for Grande Sentiment MCP Server

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Grande Sentiment MCP Server - Quick Start${NC}"
echo "============================================="

# Check if Docker is available
if command -v docker >/dev/null 2>&1 && command -v docker-compose >/dev/null 2>&1; then
    echo -e "${GREEN}Docker detected - Starting with Docker Compose${NC}"
    
    # Check if .env exists
    if [ ! -f .env ]; then
        echo "Creating .env file from template..."
        cp env.example .env
        echo -e "${YELLOW}Please edit .env file with your configuration${NC}"
    fi
    
    # Start services
    docker compose up -d
    
    echo -e "${GREEN}Server started!${NC}"
    echo "Health check: http://localhost:8000/health"
    echo "View logs: docker compose logs -f sentiment-server"
    
elif command -v python3 >/dev/null 2>&1; then
    echo -e "${GREEN}Python detected - Starting with Python${NC}"
    
    # Check if virtual environment exists
    if [ ! -d ".venv" ]; then
        echo "Creating virtual environment..."
        python3 -m venv .venv
    fi
    
    # Activate virtual environment
    source .venv/bin/activate
    
    # Install dependencies
    echo "Installing dependencies..."
    pip install -r requirements.txt requests
    
    # Set environment variables
    export MCP_TRANSPORT=streamable-http
    export SENTIMENT_PROVIDER=openai_compat
    export OPENAI_BASE_URL=http://localhost:11434/v1
    export OPENAI_API_KEY=EMPTY
    export OPENAI_MODEL=gpt-4o-mini
    
    echo -e "${GREEN}Starting server...${NC}"
    echo "Press Ctrl+C to stop"
    
    # Start server
    python main.py
    
else
    echo -e "${YELLOW}Neither Docker nor Python found${NC}"
    echo "Please install Docker or Python 3 to continue"
    exit 1
fi

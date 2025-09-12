@echo off
REM Quick start script for Grande Sentiment MCP Server (Windows)

echo Grande Sentiment MCP Server - Quick Start
echo =============================================

REM Check if Docker is available
where docker >nul 2>&1
if %errorlevel% == 0 (
    where docker-compose >nul 2>&1
    if %errorlevel% == 0 (
        echo Docker detected - Starting with Docker Compose
        
        REM Check if .env exists
        if not exist .env (
            echo Creating .env file from template...
            copy env.example .env
            echo Please edit .env file with your configuration
        )
        
        REM Start services
        docker compose up -d
        
        echo Server started!
        echo Health check: http://localhost:8000/health
        echo View logs: docker compose logs -f sentiment-server
        goto :end
    )
)

REM Check if Python is available
where python >nul 2>&1
if %errorlevel% == 0 (
    echo Python detected - Starting with Python
    
    REM Check if virtual environment exists
    if not exist .venv (
        echo Creating virtual environment...
        python -m venv .venv
    )
    
    REM Activate virtual environment
    call .venv\Scripts\activate.bat
    
    REM Install dependencies
    echo Installing dependencies...
    pip install -r requirements.txt requests
    
    REM Set environment variables
    set MCP_TRANSPORT=streamable-http
    set SENTIMENT_PROVIDER=openai_compat
    set OPENAI_BASE_URL=http://localhost:11434/v1
    set OPENAI_API_KEY=EMPTY
    set OPENAI_MODEL=gpt-4o-mini
    
    echo Starting server...
    echo Press Ctrl+C to stop
    
    REM Start server
    python main.py
    goto :end
)

echo Neither Docker nor Python found
echo Please install Docker or Python 3 to continue
exit /b 1

:end
pause

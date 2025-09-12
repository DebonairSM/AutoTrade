# Grande Sentiment MCP Server - Deployment Guide

This guide provides multiple deployment options to ensure your sentiment server MCP is always running and monitored.

## 🚀 Quick Start

### Option 1: Docker (Recommended)
```bash
# Clone and navigate to the directory
cd mcp/analyze_sentiment_server

# Copy environment file
cp env.example .env

# Edit configuration
nano .env

# Start with Docker Compose
docker compose up -d

# Check status
docker compose ps
docker compose logs -f sentiment-server
```

### Option 2: Direct Python with Monitor
```bash
# Install dependencies
pip install -r requirements.txt requests

# Start with monitoring
python monitor.py

# Or start manually
python main.py
```

## 📋 Deployment Options

### 1. Docker Deployment (Production Recommended)

**Advantages:**
- ✅ Isolated environment
- ✅ Built-in health checks
- ✅ Easy scaling and updates
- ✅ Consistent across environments
- ✅ Automatic restart policies

**Setup:**
```bash
# Build and start
docker compose up -d

# With local LLM (Ollama)
docker compose --profile local-llm up -d

# Check health
curl http://localhost:8000/health

# View logs
docker compose logs -f sentiment-server
```

**Configuration:**
- Edit `docker-compose.yml` for port changes
- Edit `.env` file for environment variables
- Modify `Dockerfile` for custom dependencies

### 2. Systemd Service (Linux)

**Advantages:**
- ✅ Native Linux service management
- ✅ Automatic startup on boot
- ✅ Built-in restart policies
- ✅ System integration

**Setup:**
```bash
# Run deployment script
./deploy.sh

# Or manual setup
sudo cp grande-sentiment.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable grande-sentiment
sudo systemctl start grande-sentiment
```

**Management:**
```bash
# Start/Stop/Restart
sudo systemctl start grande-sentiment
sudo systemctl stop grande-sentiment
sudo systemctl restart grande-sentiment

# Check status
sudo systemctl status grande-sentiment

# View logs
sudo journalctl -u grande-sentiment -f
```

### 3. Windows Service

**Advantages:**
- ✅ Native Windows service
- ✅ Automatic startup
- ✅ Service management integration

**Setup:**
1. Install NSSM (Non-Sucking Service Manager)
2. Copy files to `C:\grande-sentiment\`
3. Install service:
```cmd
nssm install GrandeSentimentMCP C:\grande-sentiment\.venv\Scripts\python.exe
nssm set GrandeSentimentMCP AppParameters main.py
nssm set GrandeSentimentMCP AppDirectory C:\grande-sentiment
nssm start GrandeSentimentMCP
```

### 4. Python Monitor Script

**Advantages:**
- ✅ Cross-platform
- ✅ Customizable monitoring
- ✅ Detailed logging
- ✅ Easy debugging

**Usage:**
```bash
# Basic monitoring
python monitor.py

# Custom configuration
python monitor.py --url http://localhost:8000/health --interval 60 --max-retries 5
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_TRANSPORT` | `stdio` | Transport mode (`stdio` or `streamable-http`) |
| `SENTIMENT_PROVIDER` | `openai_compat` | Provider (`openai_compat`, `finbert_local`, `classifier`) |
| `OPENAI_BASE_URL` | - | OpenAI-compatible API endpoint |
| `OPENAI_API_KEY` | - | API key (if required) |
| `OPENAI_MODEL` | `gpt-4o-mini` | Model name |
| `CLASSIFIER_URL` | - | Custom classifier endpoint |
| `FINBERT_MODEL` | `yiyanghkust/finbert-tone` | FinBERT model name |

### Provider Options

#### 1. OpenAI Compatible (Default)
```bash
export OPENAI_BASE_URL="http://localhost:11434/v1"  # Ollama
export OPENAI_API_KEY="EMPTY"
export OPENAI_MODEL="llama3.2"
```

#### 2. Local FinBERT
```bash
export SENTIMENT_PROVIDER="finbert_local"
export FINBERT_MODEL="yiyanghkust/finbert-tone"
```

#### 3. Custom Classifier
```bash
export SENTIMENT_PROVIDER="classifier"
export CLASSIFIER_URL="http://your-classifier:8080/analyze"
```

## 📊 Monitoring and Health Checks

### Health Check Endpoint
- **URL:** `http://localhost:8000/health`
- **Method:** GET
- **Response:** `{"status": "healthy", "service": "Grande Sentiment Server"}`

### Docker Health Checks
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 10s
```

### Monitor Script Features
- ✅ Automatic health checking
- ✅ Auto-restart on failure
- ✅ Configurable intervals
- ✅ Detailed logging
- ✅ Graceful shutdown

## 🔍 Troubleshooting

### Common Issues

#### 1. Server Won't Start
```bash
# Check logs
docker compose logs sentiment-server
sudo journalctl -u grande-sentiment -f

# Check dependencies
pip install -r requirements.txt
```

#### 2. Health Check Fails
```bash
# Test health endpoint
curl -v http://localhost:8000/health

# Check if server is running
netstat -tlnp | grep 8000
```

#### 3. Permission Issues
```bash
# Fix ownership
sudo chown -R mcpuser:mcpuser /opt/grande-sentiment

# Check service user
id mcpuser
```

### Log Locations

| Deployment | Log Location |
|------------|--------------|
| Docker | `docker compose logs sentiment-server` |
| Systemd | `sudo journalctl -u grande-sentiment` |
| Windows | `C:\grande-sentiment\logs\` |
| Monitor | `monitor.log` |

## 🚀 Production Recommendations

### 1. Use Docker (Recommended)
- Better isolation and security
- Easier updates and rollbacks
- Built-in health monitoring
- Consistent across environments

### 2. Enable Logging
```bash
# Docker
docker compose logs -f sentiment-server

# Systemd
sudo journalctl -u grande-sentiment -f --since "1 hour ago"
```

### 3. Set Up Monitoring
- Use the provided monitor script
- Set up external monitoring (Prometheus, Grafana)
- Configure alerts for failures

### 4. Security Considerations
- Run as non-root user
- Use environment variables for secrets
- Enable firewall rules
- Regular security updates

## 📈 Scaling and High Availability

### Load Balancing
```yaml
# docker-compose.yml
services:
  sentiment-server-1:
    # ... configuration
  sentiment-server-2:
    # ... configuration
  nginx:
    image: nginx
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
```

### Multiple Instances
```bash
# Start multiple instances
docker compose up -d --scale sentiment-server=3
```

## 🔄 Updates and Maintenance

### Docker Updates
```bash
# Pull latest changes
git pull

# Rebuild and restart
docker compose down
docker compose up -d --build
```

### Systemd Updates
```bash
# Update files
sudo cp main.py /opt/grande-sentiment/
sudo systemctl restart grande-sentiment
```

## 📞 Support

For issues and questions:
1. Check the logs first
2. Review this documentation
3. Check the health endpoint
4. Verify configuration

## 🎯 Best Practices

1. **Always use health checks** - Monitor service availability
2. **Log everything** - Enable detailed logging for debugging
3. **Use environment variables** - Don't hardcode configuration
4. **Test deployments** - Verify functionality after updates
5. **Monitor resources** - Watch CPU, memory, and disk usage
6. **Backup configuration** - Keep deployment configs in version control
7. **Use restart policies** - Ensure automatic recovery from failures

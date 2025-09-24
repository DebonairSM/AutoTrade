# Grande Enhanced FinBERT Deployment Guide

## Quick Start

### 1. Prerequisites
- Python 3.8+
- 4GB+ RAM (8GB recommended for GPU)
- NVIDIA GPU with CUDA support (optional, for faster processing)

### 2. Installation
```bash
# Clone or download the Grande repository
cd mcp/analyze_sentiment_server

# Create virtual environment
python -m venv .venv

# Activate virtual environment
# Windows:
.\.venv\Scripts\Activate.ps1
# Linux/Mac:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 3. Basic Configuration
```bash
# Set environment variables
export SENTIMENT_PROVIDER="finbert_local"
export CALENDAR_ANALYZER="finbert_enhanced"
export FINBERT_MODEL="yiyanghkust/finbert-tone"
```

### 4. Test Installation
```bash
# Run benchmark test
python performance_benchmark.py

# Expected output:
# === BENCHMARK RESULTS ===
# Tests Passed: 4/4
# Success Rate: 100.0%
# Overall Grade: A (Very Good)
```

## Production Deployment

### Option A: Local Development
```bash
# Start MCP server
python main.py

# Test with sample data
python finbert_calendar_analyzer.py --input test_sample_events.json
```

### Option B: Docker Deployment
```dockerfile
# Dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

ENV SENTIMENT_PROVIDER=finbert_local
ENV CALENDAR_ANALYZER=finbert_enhanced
ENV MCP_TRANSPORT=streamable-http

CMD ["python", "main.py"]
```

```bash
# Build and run
docker build -t grande-finbert .
docker run -p 8000:8000 grande-finbert
```

### Option C: MQL5 Integration
1. Copy `GrandeNewsSentimentIntegration.mqh` to your MQL5 Experts folder
2. Include in your Expert Advisor:
```cpp
#include "GrandeNewsSentimentIntegration.mqh"

CNewsSentimentIntegration news_sentiment;

int OnInit() {
    if (!news_sentiment.Initialize()) {
        Print("ERROR: Failed to initialize FinBERT sentiment analysis");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

void OnTick() {
    if (news_sentiment.RunCalendarAnalysis()) {
        news_sentiment.PrintEnhancedMetrics();
        
        if (news_sentiment.ShouldEnterLong()) {
            // Enter long position based on sentiment
        }
    }
}
```

## Configuration Options

### Environment Variables
```bash
# Core Settings
SENTIMENT_PROVIDER=finbert_local          # finbert_local, openai_compat, classifier
CALENDAR_ANALYZER=finbert_enhanced        # finbert_enhanced, heuristic
FINBERT_MODEL=yiyanghkust/finbert-tone    # FinBERT model to use

# Server Settings
MCP_TRANSPORT=stdio                       # stdio, streamable-http
MCP_HOST=0.0.0.0                         # HTTP server host
MCP_PORT=8000                            # HTTP server port

# External API Settings (if using)
OPENAI_BASE_URL=http://localhost:11434/v1 # OpenAI-compatible endpoint
OPENAI_API_KEY=EMPTY                     # API key (if required)
OPENAI_MODEL=llama3.2                    # Model name
```

### Performance Tuning
```bash
# For better performance with GPU
export CUDA_VISIBLE_DEVICES=0

# For CPU-only deployment
pip install torch --index-url https://download.pytorch.org/whl/cpu

# For memory optimization
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
```

## Monitoring and Maintenance

### Health Checks
```bash
# Check if server is running
curl http://localhost:8000/health

# Run performance benchmark
python performance_benchmark.py

# Test with sample data
python finbert_calendar_analyzer.py --input test_sample_events.json
```

### Log Monitoring
```bash
# View logs
tail -f grande_sentiment.log

# Check performance metrics
grep "processing_time_ms" grande_sentiment.log | tail -10
```

### Model Updates
```bash
# Update FinBERT model
export FINBERT_MODEL=latest_version
python -c "from transformers import AutoTokenizer; AutoTokenizer.from_pretrained('$FINBERT_MODEL')"
```

## Troubleshooting

### Common Issues

**1. "No module named 'torch'"**
```bash
# Install PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

**2. CUDA out of memory**
```bash
# Reduce batch size or use CPU
export CUDA_VISIBLE_DEVICES=""
```

**3. Model download fails**
```bash
# Manual download
python -c "from transformers import AutoTokenizer, AutoModel; AutoTokenizer.from_pretrained('yiyanghkust/finbert-tone')"
```

**4. MQL5 integration issues**
- Ensure "Allow DLL imports" is enabled in Expert Advisor settings
- Check file paths in GrandeNewsSentimentIntegration.mqh
- Verify JSON parsing in ParseCalendarSentimentData()

### Performance Issues

**Slow Processing:**
- Check if using GPU: `python -c "import torch; print(torch.cuda.is_available())"`
- Monitor memory usage during analysis
- Consider reducing batch size

**Low Accuracy:**
- Verify economic event data format
- Check impact weight assignments
- Review surprise calculation logic

**High Memory Usage:**
- Use CPU-only PyTorch build
- Reduce model precision: `torch.float16`
- Implement model caching

## Security Considerations

### API Security
```bash
# Use authentication for HTTP endpoints
export OPENAI_API_KEY="your-secure-key"

# Enable HTTPS in production
export MCP_SSL_CERT=/path/to/cert.pem
export MCP_SSL_KEY=/path/to/key.pem
```

### Data Privacy
- Economic event data is processed locally
- No sensitive information is logged
- PII detection and redaction enabled by default

### Network Security
```bash
# Restrict network access
export MCP_HOST=127.0.0.1  # Localhost only

# Use firewall rules
ufw allow 8000/tcp  # Allow only necessary ports
```

## Scaling and Production

### Horizontal Scaling
```bash
# Load balancer configuration (nginx)
upstream finbert_backend {
    server 127.0.0.1:8001;
    server 127.0.0.1:8002;
    server 127.0.0.1:8003;
}

server {
    listen 80;
    location / {
        proxy_pass http://finbert_backend;
    }
}
```

### Monitoring
```bash
# Prometheus metrics endpoint
export ENABLE_METRICS=true

# Health check endpoint
curl http://localhost:8000/health
```

### Backup and Recovery
```bash
# Backup model cache
tar -czf finbert_model_backup.tar.gz ~/.cache/huggingface/

# Backup configuration
cp .env .env.backup
```

## Support and Maintenance

### Regular Maintenance
- Weekly performance benchmarks
- Monthly model updates
- Quarterly security reviews

### Support Contacts
- Technical Issues: Check logs and run diagnostics
- Performance Issues: Run benchmark tests
- Integration Issues: Verify MQL5 configuration

### Version Updates
```bash
# Check for updates
pip list --outdated

# Update dependencies
pip install -r requirements.txt --upgrade

# Test after updates
python performance_benchmark.py
```
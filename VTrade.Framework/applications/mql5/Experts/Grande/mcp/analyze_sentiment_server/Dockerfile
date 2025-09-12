FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Create non-root user
RUN useradd -m -u 1000 mcpuser && chown -R mcpuser:mcpuser /app
USER mcpuser

# Expose port for HTTP transport
EXPOSE 8000

# Health check - check if port is listening
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD netstat -an | grep :8000 || exit 1

# Default environment variables
ENV MCP_TRANSPORT=streamable-http
ENV SENTIMENT_PROVIDER=openai_compat
ENV OPENAI_MODEL=gpt-4o-mini

# Run the application
CMD ["python", "main.py"]

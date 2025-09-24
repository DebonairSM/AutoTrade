FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV SENTIMENT_PROVIDER=finbert_local
ENV CALENDAR_ANALYZER=finbert_enhanced
ENV FINBERT_MODEL=yiyanghkust/finbert-tone
ENV MCP_PORT=8000

EXPOSE 8000

CMD ["python", "main.py"]

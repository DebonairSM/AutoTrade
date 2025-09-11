### Grande Sentiment MCP Server

Minimal Python MCP server exposing a single tool: `analyze_sentiment(text)`.

- Input: `text` (string)
- Output (JSON): `{ sentiment: "Positive|Neutral|Negative", score: -1..1, confidence: 0..1 }`
- Security: minimal PII scan (email/phone) and redacted logging. No secrets logged.

#### Setup
1) Create and activate venv (PowerShell):
```powershell
python -m venv .venv
. .\.venv\Scripts\Activate.ps1
```
2) Install deps:
```powershell
pip install -r requirements.txt
```
3) Set environment variables (base URL required for local model):
```powershell
[System.Environment]::SetEnvironmentVariable("OPENAI_BASE_URL","http://localhost:11434/v1","User")
$env:OPENAI_BASE_URL = "http://localhost:11434/v1"
# Optional model override
$env:OPENAI_MODEL = "llama3.2"
# Optional: some servers require a token; many ignore it
$env:OPENAI_API_KEY = "EMPTY"

# OpenAI-compatible endpoints (Ollama/vLLM/NIM):
# Ollama (Windows/NVIDIA): http://localhost:11434/v1
# vLLM: http://localhost:8000/v1
# NIM:  http://localhost:8000/v1 (varies by image)
```

#### Run
- STDIO transport (default):
```powershell
python .\main.py
```
- Streamable HTTP transport:
```powershell
$env:MCP_TRANSPORT = "streamable-http"
python .\main.py
# Endpoint: http://localhost:8000/mcp (FastMCP default)
```

#### Test with Python MCP client (stdio example)
```python
import asyncio
from mcp.client.session import ClientSession
from mcp.client.stdio import StdioServerParameters, stdio_client

async def main():
    async with stdio_client(
        StdioServerParameters(command="python", args=["main.py"])
    ) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            print([t.name for t in tools.tools])
            result = await session.call_tool("analyze_sentiment", {"text": "Great earnings beat; stock rallies strongly."})
            print(result)

asyncio.run(main())
```

Notes:
- Do not commit or hardcode API keys.
- Consider stronger auth (OAuth/JWT) if exposing over HTTP.

#### Host your own model locally (Docker)

Option A) Ollama (recommended for easiest Windows/NVIDIA setup)

1) Install Docker Desktop (enable WSL2 + GPU support). Ensure NVIDIA drivers are installed and `nvidia-smi` works in a CUDA container.
2) Start Ollama with GPU:
```powershell
docker run -d --gpus=all -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
```
3) Pull a model and (optionally) alias to an OpenAI name:
```powershell
docker exec -it ollama ollama pull llama3.2
docker exec -it ollama ollama cp llama3.2 gpt-3.5-turbo
```
4) Point this MCP server to Ollama:
```powershell
$env:OPENAI_BASE_URL = "http://localhost:11434/v1"
$env:OPENAI_API_KEY = "EMPTY"    # ignored by Ollama
$env:OPENAI_MODEL = "llama3.2"   # or "gpt-3.5-turbo" if you aliased
```

Option B) vLLM (OpenAI server on :8000)

```powershell
docker run --runtime nvidia --gpus all -p 8000:8000 --ipc=host vllm/vllm-openai:latest --model mistralai/Mistral-7B-v0.1
$env:OPENAI_BASE_URL = "http://localhost:8000/v1"
$env:OPENAI_API_KEY = "EMPTY"
$env:OPENAI_MODEL = "mistralai/Mistral-7B-v0.1"
```

Option C) NVIDIA NIM (OpenAI-compatible on :8000; requires NGC login and appropriate image)

```powershell
# Example shape; consult NVIDIA NIM docs for your chosen image
docker run --gpus all --shm-size=8g -p 8000:8000 -v ${env:USERPROFILE}\.cache\nim:/opt/nim/.cache nvcr.io/nvidia/nim/llm-nim:latest
$env:OPENAI_BASE_URL = "http://localhost:8000/v1"
$env:OPENAI_API_KEY = "EMPTY"
```

Once the local server is running, launch this MCP server and call `analyze_sentiment` as usual.

#### Use local FinBERT (no Docker)

Install dependencies (PowerShell):
```powershell
pip install -r requirements.txt
# Then install PyTorch appropriate for your system (choose ONE of the following):
# GPU (CUDA 12.1, Windows x64 example):
pip install --index-url https://download.pytorch.org/whl/cu121 torch torchvision torchaudio
# CPU only (works everywhere):
pip install torch --index-url https://download.pytorch.org/whl/cpu
```

Enable FinBERT provider:
```powershell
$env:SENTIMENT_PROVIDER = "finbert_local"
$env:FINBERT_MODEL = "yiyanghkust/finbert-tone"  # optional override
python .\main.py
```

Notes:
- Uses GPU if available (CUDA); otherwise CPU. First run will download the model.
- Output is normalized to {sentiment, score in [-1,1], confidence in [0,1]}.

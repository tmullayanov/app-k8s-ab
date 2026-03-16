FROM ghcr.io/astral-sh/uv:latest AS builder
WORKDIR /app

COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-cache --no-install-project

FROM python:3.13-alpine
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY main.py .

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
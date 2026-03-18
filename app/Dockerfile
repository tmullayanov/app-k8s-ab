# syntax=docker/dockerfile:1

# ────────────────────────────────────────
#  Stage 1 - Build dependencies
# ────────────────────────────────────────
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

COPY --chown=uv:uv pyproject.toml uv.lock* ./

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

COPY --chown=uv:uv . .

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ────────────────────────────────────────
#  Stage 2 - slim runtime image
# ────────────────────────────────────────
FROM python:3.12-slim-bookworm

COPY --from=builder /app/.venv /app/.venv

WORKDIR /app

COPY --from=builder /app /app

ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1

ARG APP_VERSION=v0
ENV APP_VERSION=${APP_VERSION}

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
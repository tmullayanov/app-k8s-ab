from typing import Annotated

from fastapi import FastAPI, Header, Request
from prometheus_client import CollectorRegistry, Counter, generate_latest
from pydantic import BaseModel
from starlette.responses import Response
import os

app = FastAPI(title="A/B Test Service")


# custom metrics.
my_registry = CollectorRegistry()
bad_responses = Counter("bad_responses", "Total number of bad requests", labelnames=["version"], registry=my_registry)
total_responses = Counter("total_responses", "Total number of responses", labelnames=["version"], registry=my_registry)

# Response
class ResponseModel(BaseModel):
    message: str
    version: str
    beta_tester: bool


def is_bad_response(version: str) -> bool:
    # Simulate a dice roll to determine if the request should be considered "bad" for demonstration purposes
    import random
    version_no = int(version.lstrip("v")) if version.startswith("v") and version[1:].isdigit() else 0
    if version_no >= 2:
        return random.random() < 0.3  # 30% chance of being a bad response for v2 and above
    return False

@app.get("/")
async def root(req: Request, x_role: Annotated[str | None, Header()] = None) -> ResponseModel:
    version = os.getenv("APP_VERSION", "not set")
    print(f"Headers: {req.headers}") # simple prints instead of loguru/structlog for simplicity
    print(f"X-Role: {x_role}")

    is_beta_tester = x_role == "beta_tester"
    total_responses.labels(version=version).inc()

    if is_bad_response(version):
        bad_responses.labels(version=version).inc()
        return ResponseModel(
            message="Bad response",
            version=version,
            beta_tester=is_beta_tester
        )

    return ResponseModel(
        message=f"Hello from version {version} 🎉",
        version=version,
        beta_tester=is_beta_tester
    )

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(my_registry), media_type="text/plain")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
from typing import Annotated

from fastapi import FastAPI, Header, Request
from prometheus_client import CollectorRegistry, Counter, generate_latest
from starlette.responses import Response
import os

app = FastAPI(title="A/B Test Service")

my_registry = CollectorRegistry()
bad_responses = Counter("bad_responses", "Total number of bad requests", registry=my_registry)
total_responses = Counter("total_responses", "Total number of responses", registry=my_registry)

def roll_dice_for_version(version: str) -> bool:
    # Simulate a dice roll to determine if the request should be considered "bad" for demonstration purposes
    import random
    version_no = int(version.lstrip("v")) if version.startswith("v") and version[1:].isdigit() else 0
    if version_no >= 2:
        return random.random() < 0.5  # 50% chance of being a bad response for v2 and above
    return False

@app.get("/")
async def root(req: Request, x_role: Annotated[str | None, Header()] = None):
    version = os.getenv("APP_VERSION", "not set")
    print(f"Headers: {req.headers}") # simple prints instead of loguru/structlog for simplicity
    print(f"X-Role: {x_role}")

    is_beta_tester = x_role == "beta_tester"



    total_responses.inc()
    return {
        "message": f"Hello from version {version} 🎉",
        "version": version,
        "beta_tester": is_beta_tester
    }

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/metrics")
async def metrics():
    return Response(generate_latest(my_registry), media_type="text/plain")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
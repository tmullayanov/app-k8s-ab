from typing import Annotated

from fastapi import FastAPI, Header, Request
import os

app = FastAPI(title="A/B Test Service")

@app.get("/")
async def root(req: Request, x_role: Annotated[str | None, Header()] = None):
    version = os.getenv("APP_VERSION", "not set")
    print(f"Headers: {req.headers}") # simple prints instead of loguru/structlog for simplicity
    print(f"X-Role: {x_role}")

    is_beta_tester = x_role == "beta_tester"

    return {
        "message": f"Hello from version {version} 🎉",
        "version": version,
        "beta_tester": is_beta_tester
    }

@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
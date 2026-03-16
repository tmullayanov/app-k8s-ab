from typing import Annotated

from fastapi import FastAPI, Header, Request
import os

app = FastAPI(title="A/B Test Service")

@app.get("/")
async def root(req: Request, x_beta_tester: Annotated[bool, Header()] = False):
    version = os.getenv("APP_VERSION", "unknown")
    print(f"Headers: {req.headers}")
    print(f"X-Beta-Tester: {x_beta_tester}")

    return {
        "message": f"Hello from version {version} 🎉",
        "version": version,
        "beta_tester": False   # просто для примера
    }

@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
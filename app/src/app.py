from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
import os

app = FastAPI()

# Prometheus metrics endpoint (auto /metrics)
Instrumentator().instrument(app).expose(app)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/ping")
async def ping():
    return {"message": "pong"}

@app.get("/db-health")
async def db_health():
    # Dummy; replace with real DB ping
    return {"database": "connected"}
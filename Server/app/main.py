from __future__ import annotations

from fastapi import FastAPI

from .routers import auth, mech_muse
from .schemas import HealthResponse, RootResponse

__all__ = ["app", "create_app"]


def create_app() -> FastAPI:
    application = FastAPI(title="Construct Server")

    @application.get("/", response_model=RootResponse)
    async def read_root() -> RootResponse:
        return RootResponse(message="Construct server ready")

    @application.get("/health", response_model=HealthResponse)
    async def health_check() -> HealthResponse:
        return HealthResponse(status="ok")

    application.include_router(auth.router)
    application.include_router(mech_muse.router)

    return application


app = create_app()

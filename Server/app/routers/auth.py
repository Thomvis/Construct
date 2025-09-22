from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException

from ..schemas import ProtectedResponse, TokenRequest, TokenResponse
from ..security import create_access_token, get_current_subject
from ..settings import Clock, get_clock, get_settings

__all__ = ["router"]

router = APIRouter(tags=["auth"])


@router.post("/token", response_model=TokenResponse)
async def generate_token(
    payload: TokenRequest,
    clock: Clock = Depends(get_clock),
) -> TokenResponse:
    settings = get_settings()
    if payload.password != settings.admin_password:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(subject="admin", clock=clock)
    return TokenResponse(access_token=token)


@router.get("/protected", response_model=ProtectedResponse)
async def protected_route(current_subject: str = Depends(get_current_subject)) -> ProtectedResponse:
    return ProtectedResponse(message=f"Hello, {current_subject}. Access granted.")

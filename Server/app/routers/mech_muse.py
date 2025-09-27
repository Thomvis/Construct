from __future__ import annotations

import json
from typing import Any, cast

from fastapi import APIRouter, Depends, HTTPException, status
from openai import AsyncOpenAI, OpenAIError
from pydantic import BaseModel, Field, ValidationError
from pydantic.config import ConfigDict

from ..security import TokenData, get_current_token
from ..services.usage import TokenUsageStore, get_usage_store
from ..settings import get_openai_client, get_settings

__all__ = ["router", "provide_openai_client"]

router = APIRouter(prefix="/mech-muse", tags=["mech-muse"])


class AbilityScoresModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    strength: int | None = None
    dexterity: int | None = None
    constitution: int | None = None
    intelligence: int | None = None
    wisdom: int | None = None
    charisma: int | None = None


class NamedTextItemModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    description: str


class SimpleStatBlockModel(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str
    size: str | None = None
    type: str | None = None
    subtype: str | None = None
    alignment: str | None = None
    armor_class: int | None = None
    hit_points: int | None = None
    walk_speed: int | None = None
    fly_speed: int | None = None
    swim_speed: int | None = None
    climb_speed: int | None = None
    burrow_speed: int | None = None
    abilities: AbilityScoresModel | None = None
    saves: dict[str, int] | None = None
    skills: dict[str, int] | None = None
    damage_vulnerabilities: str | None = None
    damage_resistances: str | None = None
    damage_immunities: str | None = None
    condition_immunities: str | None = None
    senses: str | None = None
    languages: str | None = None
    challenge_rating: str | None = None
    level: int | None = None
    features: list[NamedTextItemModel] | None = None
    actions: list[NamedTextItemModel] | None = None
    reactions: list[NamedTextItemModel] | None = None
    legendary_description: str | None = None
    legendary_actions: list[NamedTextItemModel] | None = None

    def to_json(self) -> str:
        return self.model_dump_json(exclude_none=True)


class RevisionPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    prompt: str = Field(min_length=1)
    stat_block: SimpleStatBlockModel = Field(alias="stat_block")


class CreatureGenerationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    instructions: str = Field(min_length=1)
    base: SimpleStatBlockModel | None = Field(default=None)
    revisions: list[RevisionPayload] = Field(default_factory=list)


def _instructions_prompt(instructions: str) -> str:
    return (
        "Update the latest stat block following the following instructions:\n\n"
        "<instructions>\n"
        f"{instructions}\n"
        "</instructions>\n\n"
        "Respond with the updated stat block. "
        "If a field should not change, use the same value in your response."
    )


def _build_mech_muse_prompt(payload: CreatureGenerationRequest) -> list[dict[str, Any]]:
    messages: list[dict[str, Any]] = [
        {
            "role": "system",
            "content": [
                {
                    "type": "text",
                    "text": (
                        "You help a Dungeons & Dragons DM create or edit creatures. "
                        "Be concise and consistent with 5e.\n\n"
                        "Guidelines:\n"
                        "- pass null instead of empty strings, arrays or objects.\n"
                        "- pass null instead of 0 for movement types the creature does not have."
                    ),
                }
            ],
        }
    ]

    base_message = (
        "Create or edit a Dungeons & Dragons creature stat block following these instructions:\n\n"
    )
    if payload.base is not None:
        base_message += (
            "Current creature stat block:\n\n<stat-block>\n"
            f"{payload.base.to_json()}\n"
            "</stat-block>\n"
        )

    messages.append(
        {
            "role": "user",
            "content": [{"type": "text", "text": base_message}],
        }
    )

    for revision in payload.revisions:
        messages.append(
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": _instructions_prompt(revision.prompt),
                    }
                ],
            }
        )
        messages.append(
            {
                "role": "assistant",
                "content": [
                    {
                        "type": "text",
                        "text": revision.stat_block.to_json(),
                    }
                ],
            }
        )

    messages.append(
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": _instructions_prompt(payload.instructions),
                }
            ],
        }
    )

    return messages


def _extract_response_text(response: Any) -> str:
    text = getattr(response, "output_text", None)
    if isinstance(text, str) and text.strip():
        return text

    output = getattr(response, "output", None)
    if output:
        first = output[0]
        content = getattr(first, "content", None)
        if content is None and isinstance(first, dict):
            content = first.get("content")
        if content:
            item = content[0]
            item_text = getattr(item, "text", None)
            if isinstance(item_text, str) and item_text:
                return item_text
            if isinstance(item, dict):
                text_value = item.get("text")
                if isinstance(text_value, str):
                    return text_value
                json_value = item.get("json")
                if json_value is not None:
                    return json.dumps(json_value)
            json_payload = getattr(item, "json", None)
            if json_payload is not None:
                return json.dumps(json_payload)

    raise ValueError("OpenAI response did not contain textual content")


def _extract_usage_counts(response: Any | None) -> tuple[int, int]:
    if response is None:
        return (0, 0)

    usage = getattr(response, "usage", None)
    if usage is None and isinstance(response, dict):
        usage = response.get("usage")

    if usage is None:
        return (0, 0)

    if isinstance(usage, dict):
        input_tokens = usage.get("input_tokens") or usage.get("prompt_tokens")
        output_tokens = usage.get("output_tokens") or usage.get("completion_tokens")
    else:
        input_tokens = getattr(usage, "input_tokens", None)
        if input_tokens is None:
            input_tokens = getattr(usage, "prompt_tokens", None)
        output_tokens = getattr(usage, "output_tokens", None)
        if output_tokens is None:
            output_tokens = getattr(usage, "completion_tokens", None)

    def _coerce(value: Any) -> int:
        if isinstance(value, int):
            return max(value, 0)
        if isinstance(value, float):
            return max(int(value), 0)
        return 0

    return (_coerce(input_tokens), _coerce(output_tokens))


async def provide_openai_client() -> AsyncOpenAI:
    try:
        return get_openai_client()
    except RuntimeError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc


@router.post(
    "/creatures/generate",
    response_model=SimpleStatBlockModel,
    responses={
        502: {"description": "OpenAI request failed"},
        503: {"description": "Service unavailable"},
    },
)
async def generate_creature_stat_block(
    payload: CreatureGenerationRequest,
    openai_client: AsyncOpenAI = Depends(provide_openai_client),
    token: TokenData = Depends(get_current_token),
    usage_store: TokenUsageStore = Depends(get_usage_store),
) -> SimpleStatBlockModel:
    settings = get_settings()
    prompt = _build_mech_muse_prompt(payload)

    response: Any | None = None
    try:
        kwargs: dict[str, Any] = {
            "model": settings.openai_model,
            "input": prompt,
            "response_format": cast(Any, {"type": "json_object"}),
            "temperature": settings.openai_temperature,
        }
        if settings.openai_max_output_tokens is not None:
            kwargs["max_output_tokens"] = settings.openai_max_output_tokens
        response = await openai_client.responses.create(**kwargs)
    except OpenAIError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc
    except Exception as exc:  # pragma: no cover - unexpected failures
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to contact OpenAI",
        ) from exc

    try:
        content = _extract_response_text(response)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail=str(exc)) from exc

    try:
        data = json.loads(content)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="OpenAI response was not valid JSON",
        ) from exc

    try:
        return SimpleStatBlockModel.model_validate(data)
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="OpenAI response did not match the expected schema",
        ) from exc
    finally:
        usage = _extract_usage_counts(response)
        if usage != (0, 0):
            subscription_id = token.subscription_id or token.subject
            product_id = token.product_id or "unknown"
            await usage_store.increment_usage(
                subscription_id=subscription_id,
                user_id=token.subject,
                product_id=product_id,
                input_tokens=usage[0],
                output_tokens=usage[1],
            )

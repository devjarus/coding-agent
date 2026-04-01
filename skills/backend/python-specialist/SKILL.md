---
name: python-specialist
description: Python expertise — patterns for building APIs and server-side logic using FastAPI, Django, or Flask. Covers type hints, async Python, testing with pytest, and Python packaging.
---

# Python Specialist

Expert Python backend engineering patterns for building clean, well-typed, production-grade APIs and services. Idiomatic Python that passes mypy strict checks, is thoroughly tested with pytest, and follows modern packaging conventions.

## When to Apply

- Building or modifying Python backend services (FastAPI, Django, Flask)
- Implementing async Python patterns or data persistence with SQLAlchemy
- Setting up pytest fixtures, structured logging, or validation with Pydantic
- Configuring mypy strict mode or Python packaging

## Core Expertise

**Frameworks**
- **FastAPI** — async-first, Pydantic-native, OpenAPI auto-generation, dependency injection system
- **Django** — ORM, admin, migrations, Django REST Framework (DRF), class-based and function-based views
- **Flask** — Blueprints, application factories, Flask-SQLAlchemy, Flask-Migrate, Marshmallow
- Know each framework's idioms; fit the one already in use in the project

**Type System**
- Type hints everywhere — function signatures, class attributes, local variables where it aids clarity
- `mypy --strict` clean: no `Any`, no untyped functions, proper use of `Optional`, `Union`, `Literal`, `TypeVar`, `Protocol`
- Pydantic v2 models for request/response validation, settings management (`pydantic-settings`), and serialization
- `TypedDict` for structured dicts; `dataclasses` or Pydantic for richer models

**Async Python**
- `asyncio`, `async def`, `await`, `asyncio.gather`, `asyncio.TaskGroup` (3.11+)
- Async DB drivers: `asyncpg`, `databases`, `SQLAlchemy` async engine
- `httpx.AsyncClient` for async HTTP calls; proper session lifecycle management
- Avoid blocking I/O in async code — offload to thread pool with `asyncio.to_thread` when necessary

**Data & Persistence**
- SQLAlchemy 2.x (mapped classes, `select()`, async sessions), Alembic for migrations
- Pydantic for validation and schema definition — never pass raw dicts across service boundaries
- Dependency injection for DB sessions (FastAPI `Depends`, Django middleware, Flask `g`)

**Testing**
- pytest with fixtures, parametrize, and markers
- `conftest.py` for shared fixtures (DB sessions, test clients, factories)
- `pytest-asyncio` for async tests; `httpx.AsyncClient` or `TestClient` for API tests
- Arrange-Act-Assert structure in every test

**Observability**
- Structured logging via `structlog` or `python-json-logger` — include `request_id`, `user_id`, service name
- Health endpoints returning meaningful status and dependency health
- Environment config via `pydantic-settings` — never hardcode secrets

## Coding Patterns

**Type Hints Everywhere**
```python
from typing import Optional
from pydantic import BaseModel

class UserCreate(BaseModel):
    email: str
    name: str
    role: Optional[str] = None

class UserResponse(BaseModel):
    id: int
    email: str
    name: str

    model_config = {"from_attributes": True}
```

**Dependency Injection (FastAPI)**
```python
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with async_session() as session:
        yield session

@router.post("/users", response_model=UserResponse, status_code=201)
async def create_user(
    body: UserCreate,
    db: AsyncSession = Depends(get_db),
) -> UserResponse:
    ...
```

**Structured Error Responses**
Return `{ "error": { "code": ..., "message": ..., "details": ... } }` consistently. Use framework exception handlers — never leak tracebacks to clients.

**Virtual Environments Always**
Every project uses a virtual environment (`venv`, `poetry`, or `uv`). Never install packages globally. Record all dependencies in `pyproject.toml`.

**pytest Fixtures in conftest.py**
```python
# conftest.py
import pytest
from httpx import AsyncClient
from app.main import app

@pytest.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac
```

**Structured Logging**
```python
import structlog
logger = structlog.get_logger()

logger.info("user_created", user_id=user.id, email=user.email)
```

## Rules

1. **PY-01 (CRITICAL): Follow the project's framework** — read existing code before adding new patterns. Match the project's router structure, model conventions, and middleware setup.
2. **PY-02 (CRITICAL): Type everything with mypy strict** — every function parameter and return type annotated; `any` is not acceptable. If you must use `Any`, add a comment explaining why.
3. **PY-03 (HIGH): Test with pytest (arrange-act-assert)** — every new endpoint or function gets a test. Use parametrize for multiple input scenarios. Fixtures over setup/teardown methods.
4. **PY-04 (HIGH): PEP 8 always** — use `black` for formatting, `isort` for import ordering, `ruff` or `flake8` for linting. Code must pass the project's configured linters.
5. **PY-05 (MEDIUM): Use Context7 MCP for documentation lookup** — when you need current docs for FastAPI, Django, SQLAlchemy, Pydantic, pytest, etc., resolve the library ID and fetch up-to-date documentation instead of relying on training-data memory.

## Skills

Apply these skills during your work:
- **tdd** — write failing tests with pytest before implementation; use parametrize for edge cases and fixtures in `conftest.py`
- **api-design** — follow REST conventions for resource naming, status codes, and response shapes; validate against the spec's API contract
- **error-handling** — apply boundary patterns using framework exception handlers; never let tracebacks reach the client, always return structured error responses
- **config-management** — use `pydantic-settings` as the single config module (CFG-01); read all values from environment variables, never hardcode secrets or URLs
- **security-checklist** — validate all inputs with Pydantic models at the boundary, enforce auth/authz on protected routes, sanitize outputs, never log secrets
- **integration-testing** — use `httpx.AsyncClient` or `TestClient` for API tests; run against a test database with proper fixtures, not production data

## Workflow

1. Read existing code to understand the framework, project structure, and conventions in use.
2. Activate or verify the virtual environment; check `pyproject.toml` for dependencies and scripts.
3. Use Context7 MCP to fetch current docs for any library you are working with.
4. Write or edit code following the patterns above.
5. Run `pytest` (or the project's test command) and ensure all tests pass.
6. Run `mypy` and `ruff` (or `flake8`/`black`) and fix any issues.
7. Confirm the application starts and health checks pass.

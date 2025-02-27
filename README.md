# Quiz Maker

## Run the backend

```bash
uv run uvicorn backend.api:app --reload
```

## Run the frontend

```bash
cd frontend/quiz_app && flutter run -d chrome
```

## Run the backend and frontend

```bash
uv run uvicorn backend.api:app --reload &
cd frontend/quiz_app && flutter run -d chrome
```

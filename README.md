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

## Using Docker Compose

You can also run the entire application using Docker Compose:

1. Make sure you have Docker and Docker Compose installed on your system.
2. Copy the `.env.example` file to `.env` and set your GROQ API key:
   ```bash
   cp .env.example .env
   # Edit .env and set GROQ_API_KEY
   ```
3. Build and start the containers:
   ```bash
   docker-compose up -d
   ```
4. Access the application:
   - Backend API: http://localhost:8000
   - Frontend: http://localhost:8080

5. To stop the containers:
   ```bash
   docker-compose down
   ```

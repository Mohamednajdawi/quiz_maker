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


delete all questions

```bash
python -c "import sqlite3; conn = sqlite3.connect('quiz_database.db'); cursor = conn.cursor(); cursor.execute('SELECT COUNT(*) FROM quiz_questions'); question_count = cursor.fetchone()[0]; cursor.execute('SELECT COUNT(*) FROM quiz_topics'); topic_count = cursor.fetchone()[0]; print(f'Found {question_count} questions and {topic_count} topics in the database.'); cursor.execute('DELETE FROM quiz_questions'); cursor.execute('DELETE FROM quiz_topics'); conn.commit(); print('Successfully deleted all quizzes from the database.'); conn.close()"
```


check the count of questions and topics
```bash
python -c "import sqlite3; conn = sqlite3.connect('quiz_database.db'); cursor = conn.cursor(); cursor.execute('SELECT COUNT(*) FROM quiz_questions'); print(f'Questions count: {cursor.fetchone()[0]}'); cursor.execute('SELECT COUNT(*) FROM quiz_topics'); print(f'Topics count: {cursor.fetchone()[0]}'); conn.close()"
```


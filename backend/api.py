from typing import Any, Dict, List

from dotenv import load_dotenv

# Load environment variables at startup
load_dotenv()

import requests
from fastapi import Depends, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl
from sqlalchemy.orm import Session

from backend.db import get_db
from backend.sqlite_dal import QuizQuestion, QuizTopic
from backend.utils import generate_quiz

app = FastAPI(title="Quiz Maker API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class URLRequest(BaseModel):
    url: HttpUrl
    num_questions: int = 5  # Default to 5 questions
    difficulty: str = (
        "medium"  # Default to medium difficulty, options: easy, medium, hard
    )


class QuizResponse(BaseModel):
    topic: str
    questions: List[Dict[str, Any]]


class TopicResponse(BaseModel):
    id: int
    topic: str


@app.post("/generate-quiz")
async def create_quiz(
    request: URLRequest, db: Session = Depends(get_db)
) -> Dict[str, Any]:
    try:
        # Remove trailing slash if present
        url = str(request.url).rstrip("/")

        # Validate difficulty level
        if request.difficulty not in ["easy", "medium", "hard"]:
            raise HTTPException(
                status_code=400,
                detail="Invalid difficulty level. Choose from: easy, medium, hard",
            )

        quiz = generate_quiz(url, request.num_questions, request.difficulty)

        # Store quiz in database
        quiz_topic = QuizTopic(topic=quiz["topic"])
        db.add(quiz_topic)
        db.flush()  # Get the ID of the newly created topic

        # Add questions
        for q in quiz["questions"]:
            quiz_question = QuizQuestion(
                question=q["question"],
                options=q["options"],
                right_option=q["right_option"],
                topic_id=quiz_topic.id,
            )
            db.add(quiz_question)

        db.commit()
        return quiz
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 404:
            raise HTTPException(
                status_code=404, detail=f"Content not found at URL: {request.url}"
            )
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"An unexpected error occurred: {str(e)}"
        )


@app.get("/topics", response_model=List[TopicResponse])
async def get_topics(db: Session = Depends(get_db)):
    """Get all quiz topics"""
    topics = db.query(QuizTopic).all()
    return [{"id": topic.id, "topic": topic.topic} for topic in topics]


@app.get("/quiz/{topic_id}", response_model=QuizResponse)
async def get_quiz(topic_id: int, db: Session = Depends(get_db)):
    """Get a specific quiz by topic ID"""
    topic = db.query(QuizTopic).filter(QuizTopic.id == topic_id).first()
    if not topic:
        raise HTTPException(status_code=404, detail="Quiz topic not found")

    questions = db.query(QuizQuestion).filter(QuizQuestion.topic_id == topic_id).all()
    return {
        "topic": topic.topic,
        "questions": [
            {
                "question": q.question,
                "options": q.options,
                "right_option": q.right_option,
            }
            for q in questions
        ],
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy"}

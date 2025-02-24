from typing import Any, Dict

from dotenv import load_dotenv

# Load environment variables at startup
load_dotenv()

import requests
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, HttpUrl

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


@app.post("/generate-quiz")
async def create_quiz(request: URLRequest) -> Dict[str, Any]:
    try:
        # Remove trailing slash if present
        url = str(request.url).rstrip("/")
        quiz = generate_quiz(url)
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


@app.get("/health")
async def health_check():
    return {"status": "healthy"}

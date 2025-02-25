from typing import Any, Dict

from backend.pipelines import quiz_generation_pipeline


def generate_quiz(
    url: str, num_questions: int = 5, difficulty: str = "medium"
) -> Dict[str, Any]:
    return quiz_generation_pipeline.run(
        {
            "link_content_fetcher": {"urls": [url]},
            "prompt_builder": {
                "num_questions": num_questions,
                "difficulty": difficulty,
            },
        }
    )["quiz_parser"]["quiz"]

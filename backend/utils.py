from typing import Any, Dict

from backend.pipelines import quiz_generation_pipeline


def generate_quiz(url: str) -> Dict[str, Any]:
    return quiz_generation_pipeline.run({"link_content_fetcher": {"urls": [url]}})[
        "quiz_parser"
    ]["quiz"]

QUIZ_GENERATION_PROMPT = """Given the following text, create {{ num_questions }} multiple choice quizzes in JSON format with {{ difficulty }} difficulty level.

{% if difficulty == "easy" %}
Create straightforward questions that test basic understanding and recall of the main concepts from the text.
{% elif difficulty == "medium" %}
Create moderately challenging questions that require understanding relationships between concepts and some analysis.
{% elif difficulty == "hard" %}
Create challenging Very hard questions that require deep understanding, critical thinking, knowledge of the subject and the ability to make connections between different parts of the text.
{% endif %}

Each question should have 4 different options, and only one of them should be correct.
The options should be unambiguous.
Each option should begin with a letter followed by a period and a space (e.g., "a. option").
The question should also briefly mention the general topic of the text so that it can be understood in isolation.
Each question should not give hints to answer the other questions.

respond with JSON only, no markdown or descriptions.

example JSON format you should absolutely follow:
{"topic": "a title fits the topic of the text",
 "questions":
  [
    {
      "question": "text of the question",
      "options": ["a. 1st option", "b. 2nd option", "c. 3rd option", "d. 4th option"],
      "right_option": "c"  # letter of the right option ("a" for the first, "b" for the second, etc.)
    }, ...
  ]
}

text:
{% for doc in documents %}{{ doc.content|truncate(4000) }}{% endfor %}
"""

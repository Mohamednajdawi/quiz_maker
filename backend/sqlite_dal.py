from sqlalchemy import JSON, Column, ForeignKey, Integer, String
from sqlalchemy.orm import declarative_base, relationship

Base = declarative_base()


class QuizTopic(Base):
    __tablename__ = "quiz_topics"

    id = Column(Integer, primary_key=True)
    topic = Column(String, nullable=False)
    category = Column(String, nullable=False)
    subcategory = Column(String, nullable=False)
    questions = relationship("QuizQuestion", back_populates="topic")


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"

    id = Column(Integer, primary_key=True)
    question = Column(String, nullable=False)
    options = Column(JSON, nullable=False)  # Store options as JSON
    right_option = Column(String, nullable=False)
    topic_id = Column(Integer, ForeignKey("quiz_topics.id"))

    topic = relationship("QuizTopic", back_populates="questions")

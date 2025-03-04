import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.sqlite_dal import Base

# Get the absolute path to the database file
db_path = os.path.abspath("quiz_database.db")

# Create SQLite engine with absolute path
engine = create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})

# Create all tables
Base.metadata.create_all(engine)

# Create sessionmaker
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    """Dependency to get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

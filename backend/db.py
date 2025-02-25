from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from backend.sqlite_dal import Base

# Create SQLite engine
engine = create_engine("sqlite:///quiz_database.db")

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

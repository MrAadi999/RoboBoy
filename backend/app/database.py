from datetime import datetime
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, DateTime, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship
from app.config import settings

# Create engine
engine = create_engine(
    settings.DATABASE_URL, 
    connect_args={"check_same_thread": False} if settings.DATABASE_URL.startswith("sqlite") else {}
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Declarative Base
Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone_or_email = Column(String, unique=True, index=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    messages = relationship("ChatMessage", back_populates="user", cascade="all, delete-orphan")
    memories = relationship("UserMemory", back_populates="user", cascade="all, delete-orphan")
    preferences = relationship("UserPreferences", uselist=False, back_populates="user", cascade="all, delete-orphan")
    interactions = relationship("InteractionLog", back_populates="user", cascade="all, delete-orphan")
    activity_logs = relationship("ActivityLog", back_populates="user", cascade="all, delete-orphan")
    confirmations = relationship("ConfirmationGate", back_populates="user", cascade="all, delete-orphan")
    briefings = relationship("DailyBriefing", back_populates="user", cascade="all, delete-orphan")
    emails = relationship("Email", back_populates="user", cascade="all, delete-orphan")
    calendar_events = relationship("CalendarEvent", back_populates="user", cascade="all, delete-orphan")
    ecommerce_orders = relationship("ECommerceOrder", back_populates="user", cascade="all, delete-orphan")

class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    role = Column(String, nullable=False)  # "user" or "assistant"
    content = Column(String, nullable=False)
    mode = Column(String, nullable=True)     # "fugu" or "odysseus"
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="messages")

class UserMemory(Base):
    __tablename__ = "user_memories"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    fact = Column(String, nullable=False)   # stored fact/preference (encrypted string)
    embedding = Column(String, nullable=True) # serialized JSON list of floats for vector search
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="memories")

class UserPreferences(Base):
    __tablename__ = "user_preferences"

    user_id = Column(Integer, ForeignKey("users.id"), primary_key=True)
    tone = Column(String, default="formal")  # "formal" or "casual"
    language = Column(String, default="hinglish")  # "hinglish" or "english" (deprecated, kept for compat)
    dashboard_language = Column(String, default="english") # UI language
    character_language = Column(String, default="hinglish") # TTS / voice / chat response language
    hinglish_ratio = Column(Float, default=0.5)  # implicit learning metric (0.0 to 1.0)
    preferred_length = Column(String, default="medium")  # "short", "medium", "long"
    permission_calendar = Column(Boolean, default=False)
    permission_email = Column(Boolean, default=False)
    permission_location = Column(Boolean, default=False)
    permission_business = Column(Boolean, default=False)
    user_name = Column(String, default="Aditya")
    assistant_name = Column(String, default="Aadi AI")
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    user = relationship("User", back_populates="preferences")

class InteractionLog(Base):
    __tablename__ = "interaction_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    query_type = Column(String, nullable=True)  # "chat", "voice", "weather", etc.
    hinglish_words_count = Column(Integer, default=0)
    total_words_count = Column(Integer, default=0)
    response_length = Column(Integer, default=0)

    user = relationship("User", back_populates="interactions")

class ActivityLog(Base):
    __tablename__ = "activity_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action_type = Column(String, nullable=False)  # "email_draft", "calendar_read", "order_lookup", etc.
    description = Column(String, nullable=False)
    status = Column(String, nullable=False)  # "pending_confirmation", "approved", "denied", "completed", "failed"
    explanation = Column(String, nullable=True)  # Explainability trace: "Why did Aadi do this?"
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="activity_logs")

class ConfirmationGate(Base):
    __tablename__ = "confirmation_gate"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    action_type = Column(String, nullable=False)  # "send_email", "add_calendar", etc.
    payload = Column(String, nullable=False)  # JSON payload with details needed to run the action
    explanation = Column(String, nullable=True)
    status = Column(String, default="pending")  # "pending", "approved", "denied"
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="confirmations")

class DailyBriefing(Base):
    __tablename__ = "daily_briefings"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    brief_content = Column(String, nullable=False)
    compiled_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="briefings")

class Email(Base):
    __tablename__ = "emails"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    sender = Column(String, nullable=False)
    recipient = Column(String, nullable=False)
    subject = Column(String, nullable=False)
    body = Column(String, nullable=False)
    snippet = Column(String, nullable=False)
    status = Column(String, default="unread")  # "unread", "read", "draft", "sent"
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="emails")

class CalendarEvent(Base):
    __tablename__ = "calendar_events"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    title = Column(String, nullable=False)
    description = Column(String, nullable=True)
    event_time = Column(String, nullable=False)  # "10:00 AM", etc.
    event_date = Column(String, nullable=False)  # "Today", "Tomorrow", etc.
    location = Column(String, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="calendar_events")

class ECommerceOrder(Base):
    __tablename__ = "ecommerce_orders"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    order_id = Column(String, index=True, nullable=False)
    vendor = Column(String, nullable=False)  # "Flipkart", "Amazon"
    item = Column(String, nullable=False)
    status = Column(String, nullable=False)  # "Delayed", "Shipped", "Processing", "Delivered"
    delivery_date = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="ecommerce_orders")

class GoogleCredential(Base):
    __tablename__ = "google_credentials"

    user_id = Column(Integer, ForeignKey("users.id"), primary_key=True)
    access_token = Column(String, nullable=False)
    refresh_token = Column(String, nullable=True)
    token_uri = Column(String, nullable=False)
    client_id = Column(String, nullable=False)
    client_secret = Column(String, nullable=False)
    scopes = Column(String, nullable=False)  # JSON serialized string
    expiry = Column(DateTime, nullable=True)

    user = relationship("User", backref="google_credential", uselist=False)

# DB helper to get session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Create tables
def init_db():
    Base.metadata.create_all(bind=engine)
    
    # Programmatically add missing user_name and assistant_name columns if they don't exist in SQLite
    import sqlite3
    db_path = settings.DATABASE_URL.replace("sqlite:///", "")
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("PRAGMA table_info(user_preferences)")
        columns = [row[1] for row in cursor.fetchall()]
        if "user_name" not in columns:
            cursor.execute("ALTER TABLE user_preferences ADD COLUMN user_name VARCHAR DEFAULT 'Aditya'")
        if "assistant_name" not in columns:
            cursor.execute("ALTER TABLE user_preferences ADD COLUMN assistant_name VARCHAR DEFAULT 'Aadi AI'")
        if "dashboard_language" not in columns:
            cursor.execute("ALTER TABLE user_preferences ADD COLUMN dashboard_language VARCHAR DEFAULT 'english'")
        if "character_language" not in columns:
            cursor.execute("ALTER TABLE user_preferences ADD COLUMN character_language VARCHAR DEFAULT 'hinglish'")
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Migration error: {e}")

def seed_user_data(user_id: int, db):
    """Seed dynamic stateful simulation data for a specific user if empty."""
    from datetime import timedelta
    
    # Check and seed E-Commerce Orders
    order_count = db.query(ECommerceOrder).filter(ECommerceOrder.user_id == user_id).count()
    if order_count == 0:
        delayed_date = (datetime.now() + timedelta(days=3)).strftime("%B %d, %Y")
        shipped_date = (datetime.now() + timedelta(days=1)).strftime("%B %d, %Y")
        db.add_all([
            ECommerceOrder(
                user_id=user_id,
                order_id="F-9821",
                vendor="Flipkart",
                item="Halonix Smart Bulb",
                status="Delayed by 3 days",
                delivery_date=delayed_date
            ),
            ECommerceOrder(
                user_id=user_id,
                order_id="A-1029",
                vendor="Amazon",
                item="Puma Running Shoes",
                status="Shipped",
                delivery_date=shipped_date
            )
        ])

    # Check and seed Calendar Meetings
    meeting_count = db.query(CalendarEvent).filter(CalendarEvent.user_id == user_id).count()
    if meeting_count == 0:
        db.add_all([
            CalendarEvent(
                user_id=user_id,
                title="Halonix Orders Status Review",
                description="Review shipment and delays for Halonix smart bulbs.",
                event_time="10:00 AM",
                event_date="Today",
                location="Meeting Room 3"
            ),
            CalendarEvent(
                user_id=user_id,
                title="Aadi AI Phase 2 Team Alignment",
                description="Sync alignment on the database models, voice pipeline, and scheduling systems.",
                event_time="2:30 PM",
                event_date="Today",
                location="Virtual / Zoom"
            ),
            CalendarEvent(
                user_id=user_id,
                title="Quarterly Performance Sync",
                description="Performance review of Phase 2 personal assistant development.",
                event_time="11:30 AM",
                event_date="Tomorrow",
                location="Conference Room A"
            )
        ])

    # Check and seed Emails
    email_count = db.query(Email).filter(Email.user_id == user_id).count()
    if email_count == 0:
        db.add_all([
            Email(
                user_id=user_id,
                sender="boss@halonix.co.in",
                recipient="aditya@halonix.co.in",
                subject="URGENT: Order #F-9821 Delay",
                body="Aditya, why is the smart bulb shipment delayed? Please check and draft a complaint to Flipkart Support immediately.",
                snippet="Aditya, why is the smart bulb shipment delayed? Please check.",
                status="unread"
            ),
            Email(
                user_id=user_id,
                sender="updates@flipkart.com",
                recipient="aditya@halonix.co.in",
                subject="Delivery Update for Order #F-9821",
                body="We apologize, but your order is delayed due to weather issues. It will take another 3 days.",
                snippet="We apologize, but your order is delayed due to weather issues.",
                status="unread"
            )
        ])
    
    db.commit()


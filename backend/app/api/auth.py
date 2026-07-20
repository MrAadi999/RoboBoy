import logging
from datetime import datetime, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session
from app.database import get_db, User, seed_user_data
from app.schemas import OTPRequest, OTPVerify, Token
from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["authentication"])

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/verify-otp", auto_error=False)

def create_access_token(data: dict, expires_delta: timedelta = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if not token:
        # Fallback for phase 1 demo/local test without JWT: return a default user if database has one, otherwise raise
        default_user = db.query(User).filter(User.phone_or_email == "aadi@ai.local").first()
        if not default_user:
            default_user = User(phone_or_email="aadi@ai.local")
            db.add(default_user)
            db.commit()
            db.refresh(default_user)
        seed_user_data(default_user.id, db)
        return default_user

    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALGORITHM])
        phone_or_email: str = payload.get("sub")
        if phone_or_email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(User).filter(User.phone_or_email == phone_or_email).first()
    if user is None:
        raise credentials_exception
    seed_user_data(user.id, db)
    return user

import random
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# In-memory transient store for OTP verification
OTP_STORE = {}

@router.post("/request-otp")
def request_otp(payload: OTPRequest):
    phone_or_email = payload.phone_or_email.strip()
    logger.info(f"OTP requested for {phone_or_email}")
    
    # Generate 6 digit OTP
    otp = f"{random.randint(100000, 999999)}"
    OTP_STORE[phone_or_email] = otp
    
    email_sent = False
    error_msg = ""
    
    # Check if input looks like an email and SMTP is configured
    if "@" in phone_or_email and settings.SMTP_USERNAME and settings.SMTP_PASSWORD:
        try:
            msg = MIMEMultipart()
            msg['From'] = settings.SMTP_USERNAME
            msg['To'] = phone_or_email
            msg['Subject'] = "Aadi AI Security Verification Code"
            
            body = f"""
            <html>
                <body style="font-family: Arial, sans-serif; background-color: #121212; color: #ffffff; padding: 20px;">
                    <div style="max-width: 600px; margin: 0 auto; background-color: #1e1e1e; padding: 30px; border-radius: 12px; border: 1px solid #FF9E00;">
                        <h2 style="color: #FF9E00;">Aadi AI Verification</h2>
                        <p>Namaste! Use the following security verification code to sign in to your personal assistant:</p>
                        <div style="font-size: 32px; font-weight: bold; letter-spacing: 5px; color: #FF9E00; margin: 20px 0; text-align: center;">
                            {otp}
                        </div>
                        <p style="color: #888888; font-size: 12px;">This code will expire shortly. If you did not request this code, please ignore this email.</p>
                    </div>
                </body>
            </html>
            """
            msg.attach(MIMEText(body, 'html'))
            
            # Send using SMTP with STARTTLS
            server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT)
            server.starttls()
            server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            server.sendmail(settings.SMTP_USERNAME, phone_or_email, msg.as_string())
            server.quit()
            
            email_sent = True
            logger.info(f"Successfully sent OTP email to {phone_or_email}")
        except Exception as e:
            error_msg = str(e)
            logger.error(f"Failed to send email OTP: {e}")

    # Build response
    response_payload = {
        "status": "success" if (email_sent or settings.DEV_MODE) else "error",
        "message": f"OTP successfully dispatched to {phone_or_email}." if email_sent else f"OTP generated (SMTP unconfigured/failed: {error_msg})."
    }
    
    if settings.DEV_MODE:
        response_payload["dev_note"] = f"Use '{otp}' (or standard bypass '123456') to verify."
        
    return response_payload

@router.post("/verify-otp", response_model=Token)
def verify_otp(payload: OTPVerify, db: Session = Depends(get_db)):
    phone_or_email = payload.phone_or_email.strip()
    
    # Check developer bypass or dynamic code match
    is_valid = False
    if settings.DEV_MODE and payload.otp == "123456":
        is_valid = True
    elif OTP_STORE.get(phone_or_email) == payload.otp:
        is_valid = True
        # Clear code from transient store on success
        OTP_STORE.pop(phone_or_email, None)

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect verification code. Please check and try again."
        )
        
    # Get or create user
    user = db.query(User).filter(User.phone_or_email == phone_or_email).first()
    if not user:
        user = User(phone_or_email=phone_or_email)
        db.add(user)
        db.commit()
        db.refresh(user)
        logger.info(f"Created new user: {phone_or_email}")
        
    seed_user_data(user.id, db)
    # Generate JWT
    access_token = create_access_token(data={"sub": user.phone_or_email})
    return {"access_token": access_token, "token_type": "bearer"}

import logging
import base64
import json
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.responses import RedirectResponse
from sqlalchemy.orm import Session
from app.database import get_db, User, GoogleCredential
from app.api.auth import get_current_user
from app.config import settings

# Google OAuth components
try:
    from google_auth_oauthlib.flow import Flow
    GOOGLE_OAUTH_SUPPORTED = True
except ImportError:
    GOOGLE_OAUTH_SUPPORTED = False

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth/google", tags=["google_oauth"])

# Scopes needed for Gmail and Calendar access
SCOPES = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/gmail.modify"
]

def get_flow(state: str = None) -> Flow:
    if not settings.GOOGLE_CLIENT_ID or not settings.GOOGLE_CLIENT_SECRET:
        raise ValueError("Google Client ID and Client Secret must be configured in settings.")
        
    client_config = {
        "web": {
            "client_id": settings.GOOGLE_CLIENT_ID,
            "client_secret": settings.GOOGLE_CLIENT_SECRET,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
        }
    }
    
    return Flow.from_client_config(
        client_config,
        scopes=SCOPES,
        redirect_uri=settings.GOOGLE_REDIRECT_URI,
        state=state
    )

@router.get("/login")
def google_login(current_user: User = Depends(get_current_user)):
    """
    Returns the Google consent screen URL for authentication.
    Encodes the current user's ID in the state parameter to verify identity in callback.
    """
    if not GOOGLE_OAUTH_SUPPORTED:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Google OAuth library dependencies are missing on the server."
        )
        
    try:
        # Encode user_id as state
        state_data = {"user_id": current_user.id}
        state_str = base64.urlsafe_b64encode(json.dumps(state_data).encode()).decode()
        
        flow = get_flow(state=state_str)
        authorization_url, _ = flow.authorization_url(
            access_type="offline",
            include_granted_scopes="true",
            prompt="consent"
        )
        return {"url": authorization_url}
    except Exception as e:
        logger.error(f"Google login flow initiation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OAuth initialization error: {str(e)}"
        )

@router.get("/callback")
def google_callback(
    code: str = Query(...),
    state: str = Query(...),
    db: Session = Depends(get_db)
):
    """
    Callback URL where Google redirects the user.
    Exchanges the auth code for access/refresh tokens and stores them in database.
    """
    try:
        # Decode state to verify and link user
        state_data = json.loads(base64.urlsafe_b64decode(state.encode()).decode())
        user_id = state_data.get("user_id")
        if not user_id:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid state parameter.")
            
        flow = get_flow(state=state)
        flow.fetch_token(code=code)
        creds = flow.credentials
        
        # Check if credential already exists for this user
        db_cred = db.query(GoogleCredential).filter(GoogleCredential.user_id == user_id).first()
        
        if not db_cred:
            db_cred = GoogleCredential(user_id=user_id)
            db.add(db_cred)
            
        db_cred.access_token = creds.token
        if creds.refresh_token:
            db_cred.refresh_token = creds.refresh_token
        db_cred.token_uri = creds.token_uri
        db_cred.client_id = creds.client_id
        db_cred.client_secret = creds.client_secret
        db_cred.scopes = json.dumps(creds.scopes)
        db_cred.expiry = creds.expiry
        
        db.commit()
        logger.info(f"Google credentials successfully saved for user ID: {user_id}")
        
        # Return a simple landing page to notify the user
        return RedirectResponse(url="http://localhost:8000/api/auth/google/success")
    except Exception as e:
        logger.error(f"OAuth callback exchange failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"OAuth exchange error: {str(e)}"
        )

@router.get("/success")
def success_page():
    """Simple confirmation page redirect for the user."""
    from fastapi.responses import HTMLResponse
    html_content = """
    <html>
        <head>
            <title>Authentication Successful</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #121212; color: #ffffff; margin: 0; }
                .card { text-align: center; padding: 40px; background: #1e1e1e; border-radius: 16px; box-shadow: 0 4px 30px rgba(0, 0, 0, 0.5); }
                h1 { color: #FF9E00; margin-bottom: 10px; }
                p { color: #cccccc; margin-bottom: 20px; }
                .btn { background: #FF9E00; color: black; border: none; padding: 10px 20px; border-radius: 8px; font-weight: bold; cursor: pointer; text-decoration: none; }
            </style>
        </head>
        <body>
            <div class="card">
                <h1>Google Account Connected!</h1>
                <p>Aadi AI can now access your Gmail inbox and Calendar events securely.</p>
                <p>You can close this tab and return to the app.</p>
            </div>
        </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=200)

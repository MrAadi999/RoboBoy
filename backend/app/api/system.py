import logging
import os
import sys
import time
import datetime
import subprocess
import psutil
import threading
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional
from app.database import get_db, User
from app.api.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/system", tags=["system"])

# Uptime tracker (FastAPI start time reference)
START_TIME = time.time()

# Ensure screenshot folder exists
SCREENSHOTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static", "screenshots")
os.makedirs(SCREENSHOTS_DIR, exist_ok=True)

class OpenAppPayload(BaseModel):
    app_name: str

class PowerPayload(BaseModel):
    action: str  # "shutdown" or "restart"

def capture_screenshot_local() -> Optional[str]:
    """Takes a screenshot and saves it inside the static screenshots folder"""
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"screenshot_{timestamp}.png"
    filepath = os.path.join(SCREENSHOTS_DIR, filename)
    
    try:
        if sys.platform == "darwin":  # macOS
            subprocess.call(["screencapture", "-x", filepath])
        elif sys.platform == "win32":  # Windows
            cmd = "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('%{PRTSC}');"
            subprocess.run(["powershell", "-Command", cmd], capture_output=True)
            # Safe check: if we need fallback logic on Windows we can print or use PIL
            pass
        
        if os.path.exists(filepath):
            # Returns the path that can be served via static endpoint
            return f"/static/screenshots/{filename}"
    except Exception as e:
        logger.error(f"Screenshot failed: {e}")
    return None

def run_open_app_local(app_name: str) -> bool:
    try:
        if sys.platform == "darwin":  # macOS
            subprocess.call(["open", "-a", app_name])
            return True
        elif sys.platform == "win32":  # Windows
            subprocess.Popen(["start", app_name], shell=True)
            return True
    except Exception as e:
        logger.error(f"Failed to open app {app_name}: {e}")
    return False

@router.post("/screenshot")
def screenshot_endpoint(current_user: User = Depends(get_current_user)):
    """Capture a screenshot of the host machine."""
    path = capture_screenshot_local()
    if path:
        return {"status": "success", "path": path}
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Could not capture desktop screenshot."
    )

@router.post("/open-app")
def open_app_endpoint(payload: OpenAppPayload, current_user: User = Depends(get_current_user)):
    """Launch a desktop application on the host machine."""
    success = run_open_app_local(payload.app_name)
    if success:
        return {"status": "success", "message": f"Successfully triggered opening of {payload.app_name}."}
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail=f"Could not open application: {payload.app_name}."
    )

@router.get("/telemetry")
def telemetry_endpoint(current_user: User = Depends(get_current_user)):
    """Get CPU usage, Memory usage, and system uptime metrics."""
    try:
        cpu = psutil.cpu_percent(interval=None)
        mem = psutil.virtual_memory().percent
        uptime_seconds = int(time.time() - START_TIME)
        uptime = str(datetime.timedelta(seconds=uptime_seconds))
        return {
            "cpu": cpu,
            "memory": mem,
            "uptime": uptime
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to fetch system telemetry: {str(e)}"
        )

@router.post("/power")
def power_endpoint(payload: PowerPayload, current_user: User = Depends(get_current_user)):
    """Shutdown or restart the system after a brief delay."""
    action = payload.action.lower()
    if action not in ["shutdown", "restart"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid power action. Must be 'shutdown' or 'restart'."
        )

    message = f"System will {action} in 5 seconds."
    
    def execute_power_action():
        time.sleep(5)
        if action == "shutdown":
            if sys.platform == "darwin":
                subprocess.call(["sudo", "shutdown", "-h", "now"])
            elif sys.platform == "win32":
                subprocess.call(["shutdown", "/s", "/t", "0"])
        elif action == "restart":
            if sys.platform == "darwin":
                subprocess.call(["sudo", "shutdown", "-r", "now"])
            elif sys.platform == "win32":
                subprocess.call(["shutdown", "/r", "/t", "0"])

    threading.Thread(target=execute_power_action, daemon=True).start()
    return {"status": "success", "message": message}

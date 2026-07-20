import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db, User, ActivityLog, ConfirmationGate
from app.schemas import ActivityLogResponse, ConfirmationGateResponse, ConfirmationAction
from app.api.auth import get_current_user
from app.services.planner import task_planner

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/planner", tags=["planner"])

@router.get("/activity-log", response_model=List[ActivityLogResponse])
def get_activity_log(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Retrieve the audit trail activity logs containing task executions and explanations.
    """
    logs = db.query(ActivityLog).filter(
        ActivityLog.user_id == current_user.id
    ).order_by(ActivityLog.timestamp.desc()).all()
    return logs

@router.get("/confirmations", response_model=List[ConfirmationGateResponse])
def get_pending_confirmations(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Retrieve all pending confirmation actions currently queued in the Confirmation Gate.
    """
    confirmations = db.query(ConfirmationGate).filter(
        ConfirmationGate.user_id == current_user.id,
        ConfirmationGate.status == "pending"
    ).order_by(ConfirmationGate.timestamp.desc()).all()
    return confirmations

@router.post("/confirmations/{action_id}")
async def handle_confirmation_action(
    action_id: int,
    payload: ConfirmationAction,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Approve or deny a queued confirmation action. If approved, executes the transaction tool.
    """
    gate_item = db.query(ConfirmationGate).filter(
        ConfirmationGate.id == action_id,
        ConfirmationGate.user_id == current_user.id
    ).first()

    if not gate_item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Confirmation action not found."
        )

    if gate_item.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Action has already been processed with status: {gate_item.status}."
        )

    if payload.approve:
        logger.info(f"User approved action ID {action_id} ({gate_item.action_type})")
        # Update gate item status
        gate_item.status = "approved"
        db.commit()

        # Execute
        success = await task_planner.execute_confirmed_action(gate_item, db)
        if success:
            return {"status": "success", "message": f"Action '{gate_item.action_type}' successfully executed."}
            
        return {"status": "error", "message": f"Action execution failed. Check logs."}
        
    else:
        logger.info(f"User denied action ID {action_id} ({gate_item.action_type})")
        gate_item.status = "denied"
        
        # Log denial in audit log
        audit = ActivityLog(
            user_id=current_user.id,
            action_type=gate_item.action_type,
            description=f"User rejected pending action: {gate_item.action_type}.",
            status="denied",
            explanation=f"Transaction cancelled by user. Reason: {gate_item.explanation}"
        )
        db.add(audit)
        db.commit()
        return {"status": "success", "message": f"Action '{gate_item.action_type}' was rejected and cancelled."}

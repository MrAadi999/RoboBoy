from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db, UserMemory, User
from app.schemas import MemoryCreate, MemoryResponse
from app.api.auth import get_current_user
from app.services.memory_vector import memory_vector_service

router = APIRouter(prefix="/memory", tags=["memory"])

@router.get("/", response_model=List[MemoryResponse])
def get_memories(
    current_user: User = Depends(get_current_user), 
    db: Session = Depends(get_db)
):
    from app.services.memory_vector import decrypt_fact
    memories = db.query(UserMemory).filter(UserMemory.user_id == current_user.id).all()
    
    # Safely decrypt facts into dictionaries to avoid marking SQLAlchemy models as dirty
    result = []
    for m in memories:
        result.append({
            "id": m.id,
            "fact": decrypt_fact(m.fact),
            "created_at": m.created_at
        })
    return result

@router.post("/", response_model=MemoryResponse, status_code=status.HTTP_201_CREATED)
async def create_memory(
    payload: MemoryCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    from app.services.memory_vector import decrypt_fact
    # Use service to compute vector, resolve conflicts and save
    new_memory = await memory_vector_service.save_user_memory(current_user.id, payload.fact, db)
    return {
        "id": new_memory.id,
        "fact": decrypt_fact(new_memory.fact),
        "created_at": new_memory.created_at
    }

@router.delete("/{memory_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_memory(
    memory_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    memory = db.query(UserMemory).filter(
        UserMemory.id == memory_id, 
        UserMemory.user_id == current_user.id
    ).first()
    
    if not memory:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Memory not found."
        )
        
    db.delete(memory)
    db.commit()
    # Invalidate cached list for the user
    memory_vector_service.invalidate_cache(current_user.id)
    return None

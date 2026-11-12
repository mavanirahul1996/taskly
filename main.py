import json
import logging
import time
import uuid
from typing import List, Optional

from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.responses import Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST, Gauge

ACTIVE_TASKS = Gauge("active_tasks", "Number of unfinished tasks")
from pydantic import BaseModel
from sqlalchemy.orm import Session

import cache
from database import Base, engine, get_db
from models import TaskModel

app = FastAPI(
    title="Tasks API",
    description="Taskly - Production DevOps Project"
)

Base.metadata.create_all(bind=engine)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("taskly")

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status"]
)

REQUEST_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"]
)

TASKS_CREATED = Counter(
    "tasks_created_total",
    "Total number of tasks created"
)


@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    trace_id = uuid.uuid4().hex
    request.state.trace_id = trace_id
    start_time = time.perf_counter()
    status_code = 500

    try:
        response = await call_next(request)
        status_code = response.status_code
        response.headers["X-Trace-ID"] = trace_id
        return response
    finally:
        duration = time.perf_counter() - start_time
        route = request.scope.get("route")
        endpoint = getattr(route, "path", request.url.path)

        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=endpoint,
            status=str(status_code)
        ).inc()

        REQUEST_DURATION.labels(
            method=request.method,
            endpoint=endpoint
        ).observe(duration)

        logger.info(json.dumps({
            "trace_id": trace_id,
            "method": request.method,
            "endpoint": endpoint,
            "status_code": status_code,
            "duration_ms": round(duration * 1000, 2)
        }))


class Task(BaseModel):
    title: str
    description: Optional[str] = None
    done: bool = False
    priority: Optional[str] = None


class TaskOut(Task):
    id: int

    model_config = {"from_attributes": True}


@app.get("/health")
def health():
    return {"status": "ok", "service": "tasks-api"}


@app.get("/metrics")
def metrics(db: Session = Depends(get_db)):
    ACTIVE_TASKS.set(
        db.query(TaskModel).filter(TaskModel.done.is_(False)).count()
    )
    return Response(
        generate_latest(),
        media_type=CONTENT_TYPE_LATEST
    )


@app.get("/tasks", response_model=List[TaskOut])
def list_tasks(db: Session = Depends(get_db)):
    cached = cache.get_cached_tasks()
    if cached is not None:
        return cached

    result = [
        TaskOut.model_validate(task).model_dump()
        for task in db.query(TaskModel).order_by(TaskModel.id).all()
    ]

    cache.set_cached_tasks(result)
    return result


@app.post("/tasks", response_model=TaskOut, status_code=201)
def create_task(task: Task, db: Session = Depends(get_db)):
    db_task = TaskModel(**task.model_dump())
    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    TASKS_CREATED.inc()
    cache.invalidate_task_cache(db_task.id)

    return db_task


@app.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(task_id: int, db: Session = Depends(get_db)):
    cached = cache.get_cached_task(task_id)
    if cached is not None:
        return cached

    db_task = db.get(TaskModel, task_id)
    if db_task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    result = TaskOut.model_validate(db_task).model_dump()
    cache.set_cached_task(task_id, result)
    return result


@app.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(task_id: int, task: Task, db: Session = Depends(get_db)):
    db_task = db.get(TaskModel, task_id)
    if db_task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    for field, value in task.model_dump().items():
        setattr(db_task, field, value)

    db.commit()
    db.refresh(db_task)
    cache.invalidate_task_cache(task_id)

    return db_task


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: int, db: Session = Depends(get_db)):
    db_task = db.get(TaskModel, task_id)
    if db_task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    db.delete(db_task)
    db.commit()
    cache.invalidate_task_cache(task_id)

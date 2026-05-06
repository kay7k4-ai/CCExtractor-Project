from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Annotated
import shutil
import subprocess
import uuid
import os

from compare import compare_files
from database import cursor, conn

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads", exist_ok=True)
os.makedirs("outputs", exist_ok=True)

EXPECTED_PATH = "test_files/expected/sample.srt"

# ✅ Look for ccextractor in current directory first, then system PATH
CC_BINARY = "./ccextractor_bin" if os.path.exists("./ccextractor_bin") else "ccextractor"


def check_ccextractor():
    try:
        result = subprocess.run(
            [CC_BINARY, "--version"],
            capture_output=True, timeout=10
        )
        return True
    except Exception:
        return False


@app.get("/")
def home():
    return {
        "message": "Server is running",
        "ccextractor_available": check_ccextractor(),
        "ccextractor_path": CC_BINARY,
        "expected_file_exists": os.path.exists(EXPECTED_PATH)
    }


@app.post("/run-test")
async def run_test(file: UploadFile = File(...)):
    if not check_ccextractor():
        raise HTTPException(status_code=500,
            detail=f"ccextractor not found at {CC_BINARY}")

    if not os.path.exists(EXPECTED_PATH):
        raise HTTPException(status_code=500,
            detail=f"Expected file not found at {EXPECTED_PATH}")

    file_id = str(uuid.uuid4())
    input_path = f"uploads/{file_id}.mp4"
    output_path = f"outputs/{file_id}.srt"

    try:
        with open(input_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        subprocess.run(
            [CC_BINARY, input_path, "-o", output_path],
            capture_output=True, text=True, timeout=120
        )

        result = compare_files(output_path, EXPECTED_PATH)
        status = "PASS" if result.get("pass") else "FAIL"

        cursor.execute(
            "INSERT INTO results (id, status, missing, extra) VALUES (?, ?, ?, ?)",
            (file_id, status,
             str(result.get("missing_lines", [])),
             str(result.get("extra_lines", [])))
        )
        conn.commit()

        return {"file_id": file_id, "status": status, "result": result}

    except subprocess.TimeoutExpired:
        raise HTTPException(status_code=500, detail="CCExtractor timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if os.path.exists(input_path):
            os.remove(input_path)


@app.post("/run-batch")
async def run_batch(files: Annotated[List[UploadFile], File(description="Upload multiple video files")]):
    if not check_ccextractor():
        raise HTTPException(status_code=500,
            detail=f"ccextractor not found at {CC_BINARY}")

    results_summary = []
    passed = 0
    failed = 0

    for file in files:
        file_id = str(uuid.uuid4())
        input_path = f"uploads/{file_id}.mp4"
        output_path = f"outputs/{file_id}.srt"

        try:
            with open(input_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            subprocess.run(
                [CC_BINARY, input_path, "-o", output_path],
                capture_output=True, text=True, timeout=120
            )

            result = compare_files(output_path, EXPECTED_PATH)
            status = "PASS" if result.get("pass") else "FAIL"

            if status == "PASS":
                passed += 1
            else:
                failed += 1

            cursor.execute(
                "INSERT INTO results (id, status, missing, extra) VALUES (?, ?, ?, ?)",
                (file_id, status,
                 str(result.get("missing_lines", [])),
                 str(result.get("extra_lines", [])))
            )
            conn.commit()
            results_summary.append({"file_id": file_id, "status": status})

        except Exception as e:
            failed += 1
            results_summary.append({
                "file_id": file_id,
                "status": "FAIL",
                "error": str(e)
            })
        finally:
            if os.path.exists(input_path):
                os.remove(input_path)

    return {
        "total": len(files),
        "passed": passed,
        "failed": failed,
        "details": results_summary
    }


@app.get("/results")
def get_all_results():
    cursor.execute("SELECT * FROM results ORDER BY rowid DESC")
    rows = cursor.fetchall()
    return [
        {"id": r[0], "status": r[1], "missing": r[2], "extra": r[3]}
        for r in rows
    ]


@app.get("/results/{file_id}")
def get_result(file_id: str):
    cursor.execute("SELECT * FROM results WHERE id=?", (file_id,))
    row = cursor.fetchone()
    if not row:
        return {"error": "Not found"}
    return {"id": row[0], "status": row[1], "missing": row[2], "extra": row[3]}
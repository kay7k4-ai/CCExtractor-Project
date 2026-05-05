from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Annotated
import shutil
import subprocess
import uuid
import os

from compare import compare_files
from database import cursor, conn

if shutil.which("ccextractor") is None:
    raise RuntimeError("❌ ccextractor is not installed in the container")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create folders
os.makedirs("uploads", exist_ok=True)
os.makedirs("outputs", exist_ok=True)
os.makedirs("expected", exist_ok=True)


@app.get("/")
def home():
    return {"message": "Server is running"}


@app.post("/run-test")
async def run_test(file: UploadFile = File(...)):
    try:
        # ✅ Runtime safety check
        if shutil.which("ccextractor") is None:
            return {"error": "ccextractor not installed on server"}

        file_id = str(uuid.uuid4())
        input_path = f"uploads/{file_id}.mp4"
        output_path = f"outputs/{file_id}.srt"
        expected_path = "expected/sample.srt"

        # Save uploaded file
        with open(input_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Run CCExtractor
        process = subprocess.run(
            ["ccextractor", input_path, "-o", output_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )

        if process.returncode != 0:
            return {
                "error": "CCExtractor failed",
                "details": process.stderr.decode()
            }

        if not os.path.exists(output_path):
            return {"error": "Output file not generated"}

        # Compare output
        result = compare_files(output_path, expected_path)
        status = "PASS" if result.get("pass") else "FAIL"

        # Save to DB
        cursor.execute(
            "INSERT INTO results (id, status, missing, extra) VALUES (?, ?, ?, ?)",
            (
                file_id,
                status,
                str(result.get("missing_lines", [])),
                str(result.get("extra_lines", []))
            )
        )
        conn.commit()

        return {"file_id": file_id, "status": status, "result": result}

    except Exception as e:
        return {"error": str(e)}


@app.post("/run-batch")
async def run_batch(
    files: Annotated[List[UploadFile], File(description="Upload multiple video files")]
):
    results_summary = []
    passed = 0
    failed = 0

    try:
        # ✅ Runtime safety check
        if shutil.which("ccextractor") is None:
            return {"error": "ccextractor not installed on server"}

        for file in files:
            file_id = str(uuid.uuid4())
            input_path = f"uploads/{file_id}.mp4"
            output_path = f"outputs/{file_id}.srt"
            expected_path = "expected/sample.srt"

            # Save file
            with open(input_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            # Run CCExtractor
            process = subprocess.run(
                ["ccextractor", input_path, "-o", output_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )

            if process.returncode != 0:
                results_summary.append({
                    "file_id": file_id,
                    "status": "FAIL",
                    "error": process.stderr.decode()
                })
                failed += 1
                continue

            if not os.path.exists(output_path):
                results_summary.append({
                    "file_id": file_id,
                    "status": "FAIL",
                    "error": "Output file not generated"
                })
                failed += 1
                continue

            result = compare_files(output_path, expected_path)
            status = "PASS" if result.get("pass") else "FAIL"

            if status == "PASS":
                passed += 1
            else:
                failed += 1

            # Save to DB
            cursor.execute(
                "INSERT INTO results (id, status, missing, extra) VALUES (?, ?, ?, ?)",
                (
                    file_id,
                    status,
                    str(result.get("missing_lines", [])),
                    str(result.get("extra_lines", []))
                )
            )
            conn.commit()

            results_summary.append({
                "file_id": file_id,
                "status": status
            })

        return {
            "total": len(files),
            "passed": passed,
            "failed": failed,
            "details": results_summary
        }

    except Exception as e:
        return {"error": str(e)}


@app.get("/results")
def get_all_results():
    cursor.execute("SELECT * FROM results ORDER BY rowid DESC")
    rows = cursor.fetchall()
    return [
        {
            "id": r[0],
            "status": r[1],
            "missing": r[2],
            "extra": r[3]
        }
        for r in rows
    ]


@app.get("/results/{file_id}")
def get_result(file_id: str):
    cursor.execute("SELECT * FROM results WHERE id=?", (file_id,))
    row = cursor.fetchone()

    if not row:
        return {"error": "Not found"}

    return {
        "id": row[0],
        "status": row[1],
        "missing": row[2],
        "extra": row[3]
    }
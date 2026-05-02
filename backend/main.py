from fastapi import FastAPI, UploadFile, File
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

# Ensure folders exist
os.makedirs("uploads", exist_ok=True)
os.makedirs("outputs", exist_ok=True)
os.makedirs("expected", exist_ok=True)


@app.get("/")
def home():
    return {"message": "Server is running"}


# 🔹 SINGLE FILE TEST
@app.post("/run-test")
async def run_test(file: UploadFile = File(...)):
    file_id = str(uuid.uuid4())

    input_path = f"uploads/{file_id}.mp4"
    output_path = f"outputs/{file_id}.srt"
    expected_path = "../test_files/expected/sample.srt"

    # Save uploaded file
    with open(input_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # Run CCExtractor
    subprocess.run(["ccextractor", input_path, "-o", output_path])

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

    return {
        "file_id": file_id,
        "status": status,
        "result": result
    }


# 🔥 BATCH TEST (MULTIPLE FILES)
@app.post("/run-batch")
async def run_batch(files: Annotated[List[UploadFile], File(description="Upload multiple video files")]):

    results_summary = []
    passed = 0
    failed = 0

    for file in files:
        file_id = str(uuid.uuid4())
        input_path = f"uploads/{file_id}.mp4"
        output_path = f"outputs/{file_id}.srt"
        expected_path = "expected/sample.srt"

        with open(input_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        subprocess.run(["ccextractor", input_path, "-o", output_path])
        result = compare_files(output_path, expected_path)
        status = "PASS" if result.get("pass") else "FAIL"

        if status == "PASS":
            passed += 1
        else:
            failed += 1

        cursor.execute(
            "INSERT INTO results (id, status, missing, extra) VALUES (?, ?, ?, ?)",
            (file_id, status, str(result.get("missing_lines", [])), str(result.get("extra_lines", [])))
        )
        conn.commit()
        results_summary.append({"file_id": file_id, "status": status})

    return {
        "total": len(files),
        "passed": passed,
        "failed": failed,
        "details": results_summary
    }

# 🔹 GET SINGLE RESULT
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
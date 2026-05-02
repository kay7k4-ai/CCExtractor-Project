# CCExtractor Regression Testing Dashboard

An automated regression testing system for [CCExtractor](https://github.com/CCExtractor/ccextractor) — upload video/subtitle files, run extraction, compare against expected output, and view results in a Flutter dashboard.

---

## Project Structure

```
project/
├── backend/
│   ├── main.py          # FastAPI app & API endpoints
│   ├── compare.py       # Diff logic (actual vs expected)
│   ├── database.py      # SQLite setup
│   ├── models.py        # DB models
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   └── main.dart    # Flutter dashboard UI
│   └── pubspec.yaml
├── test_files/
│   ├── input/           # Sample video/subtitle files
│   └── expected/        # Expected .srt reference outputs
└── README.md
```

---

## Prerequisites

- Python 3.10+
- Flutter SDK 3.x
- CCExtractor installed on your system
- Git

### Install CCExtractor

**macOS:**
```bash
brew install ccextractor
```

**Ubuntu/Linux:**
```bash
sudo apt install ccextractor
```

**Windows:**  
Download the `.exe` from [ccextractor.org](https://ccextractor.org/public/general/downloads/) and add it to your PATH.

Verify installation:
```bash
ccextractor --version
```

---

## Backend Setup

```bash
cd backend
pip install -r requirements.txt
```

**requirements.txt:**
```
fastapi
uvicorn
python-multipart
sqlalchemy
```

Start the server:
```bash
uvicorn main:app --reload
```

Server runs at: `http://127.0.0.1:8000`  
Swagger docs at: `http://127.0.0.1:8000/docs`

---

## Frontend Setup

```bash
cd frontend
flutter pub get
flutter run -d chrome     # Web
flutter run               # Desktop or connected device
```

> **Note:** Make sure the backend is running before launching the frontend.

---

## API Endpoints

### `GET /`
Health check.
```json
{ "message": "Server is running" }
```

### `POST /run-test`
Upload a single file and run the test.

**Request:** `multipart/form-data` with field `file`

**Response:**
```json
{
  "file_id": "uuid-here",
  "status": "PASS",
  "result": {
    "pass": true,
    "missing_lines": [],
    "extra_lines": []
  }
}
```

### `POST /run-batch`
Upload multiple files and run all tests.

**Request:** `multipart/form-data` with field `files` (multiple)

**Response:**
```json
{
  "total": 3,
  "passed": 2,
  "failed": 1,
  "details": [
    { "file_id": "uuid-1", "status": "PASS" },
    { "file_id": "uuid-2", "status": "PASS" },
    { "file_id": "uuid-3", "status": "FAIL" }
  ]
}
```

### `GET /results/{file_id}`
Get result details for a specific test run.

**Response:**
```json
{
  "id": "uuid-here",
  "status": "FAIL",
  "missing": "['line 1', 'line 2']",
  "extra": "[]"
}
```

### `GET /results`
Get all past test results.

---

## Testing with curl

```bash
# Health check
curl http://127.0.0.1:8000/

# Single file test
curl -X POST http://127.0.0.1:8000/run-test \
  -F "file=@./test_files/input/sample.mp4"

# Batch test
curl -X POST http://127.0.0.1:8000/run-batch \
  -F "files=@./test_files/input/sample1.mp4" \
  -F "files=@./test_files/input/sample2.mkv"

# Get result by ID
curl http://127.0.0.1:8000/results/YOUR-FILE-ID-HERE

# Get all results
curl http://127.0.0.1:8000/results
```

---

## How to Add New Test Cases

### Step 1 — Add your input file
Place your video or subtitle file in:
```
test_files/input/your_file.mp4
```

### Step 2 — Generate expected output
Run CCExtractor manually on it once:
```bash
ccextractor test_files/input/your_file.mp4 -o test_files/expected/your_file.srt
```

Review the `.srt` output and confirm it looks correct. This becomes your **ground truth**.

### Step 3 — Register it in the backend
In `main.py`, update the `expected_path` to point to the right expected file per test. For multiple test cases, consider a naming convention like:

```
uploads/{file_id}.mp4    →    expected/{original_name}.srt
```

You can pass the original filename along with the upload and look up the expected file dynamically.

### Step 4 — Run the test
Upload `your_file.mp4` via the dashboard or curl. The system will:
1. Run CCExtractor on it
2. Compare with `test_files/expected/your_file.srt`
3. Return PASS/FAIL with diff details

---

## Expected Output Format (.srt)

A valid `.srt` subtitle file looks like:

```
1
00:00:01,000 --> 00:00:04,000
This is the first subtitle line.

2
00:00:05,500 --> 00:00:08,000
This is the second subtitle.

3
00:00:09,000 --> 00:00:12,500
Multiple lines can appear
on consecutive lines like this.
```

**Fields:**
- **Index** — sequential number starting from 1
- **Timestamp** — `HH:MM:SS,mmm --> HH:MM:SS,mmm`
- **Text** — one or more lines of subtitle content
- **Blank line** — separates each subtitle block

The diff engine checks for:
- Missing subtitle lines (in expected but not in actual)
- Extra lines (in actual but not in expected)
- Timing mismatches

---

## Supported File Formats

| Format | Extension |
|--------|-----------|
| MPEG-4 Video | `.mp4` |
| Matroska Video | `.mkv` |
| MPEG Transport Stream | `.ts` |
| MPEG Program Stream | `.mpg` / `.mpeg` |
| Subtitle (direct) | `.srt` |

---

## Dashboard Features

- **Single Test** — upload one file, see immediate pass/fail with diff
- **Batch Test** — upload multiple files, view summary report
- **Results History** — searchable table of all past test runs
- All results persisted in SQLite database

---

## Contributing / Adding More Tests

1. Fork this repo
2. Add your test files to `test_files/`
3. Generate expected outputs using CCExtractor
4. Submit a PR with your new test cases and expected `.srt` files

---

## License

MIT
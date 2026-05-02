import sqlite3

conn = sqlite3.connect("results.db", check_same_thread=False)
cursor = conn.cursor()

cursor.execute("""
CREATE TABLE IF NOT EXISTS results (
    id TEXT PRIMARY KEY,
    status TEXT,
    missing TEXT,
    extra TEXT
)
""")

conn.commit()
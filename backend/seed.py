"""One-off setup script: inserts a test login.

Run with: venv/Scripts/python.exe seed.py
Requires the schema to already exist - run `alembic upgrade head` first.

Uses psycopg's plain *sync* connection, on purpose - this only runs once,
by hand, so there's nothing to gain from async here. The FastAPI app itself
uses the *async* side of psycopg3 (see database.py) since it's handling
concurrent HTTP requests.
"""

import psycopg

from config import DATABASE_URL
from security import hash_password

TEST_EMAIL = "test@example.com"
TEST_PASSWORD = "password123"


def main():
    with psycopg.connect(DATABASE_URL) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id FROM users WHERE email = %s", (TEST_EMAIL,))
            if cur.fetchone() is not None:
                print(f"User already exists: {TEST_EMAIL}")
                return

            cur.execute(
                "INSERT INTO users (email, hashed_password) VALUES (%s, %s)",
                (TEST_EMAIL, hash_password(TEST_PASSWORD)),
            )
        conn.commit()
    print(f"Seeded user: {TEST_EMAIL} / {TEST_PASSWORD}")


if __name__ == "__main__":
    main()

# convert.py — конвертація MovieLens 1M (.dat) → CSV.

import csv
import os
import re

SRC_DIR = "."      # де лежать .dat файли
OUT_DIR = "import" # куди писати .csv

MAX_RATINGS = None # None = усі 1_000_209 оцінок, або число для швидких прогонів на слабкій машині

os.makedirs(OUT_DIR, exist_ok=True)

# Рік випуску у назві винесемо в окрему колонку: "Toy Story (1995)" → title="Toy Story", year=1995.
# Це робить вузол Movie чистішим і дозволяє фільтрувати/сортувати за роком без парсингу в Cypher.
YEAR_RE = re.compile(r"\s*\((\d{4})\)\s*$")


def convert_movies():
    src = os.path.join(SRC_DIR, "movies.dat")
    dst = os.path.join(OUT_DIR, "movies.csv")
    with open(src, encoding="latin-1") as f_in, \
         open(dst, "w", newline="", encoding="utf-8") as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["movieId", "title", "year", "genres"])
        for line in f_in:
            movie_id, title, genres = line.rstrip("\n").split("::")
            m = YEAR_RE.search(title)
            year = m.group(1) if m else ""
            clean_title = YEAR_RE.sub("", title).strip()
            writer.writerow([movie_id, clean_title, year, genres])
    print(f"movies.csv готовий → {dst}")

def convert_users():
    src = os.path.join(SRC_DIR, "users.dat")
    dst = os.path.join(OUT_DIR, "users.csv")
    with open(src, encoding="latin-1") as f_in, \
         open(dst, "w", newline="", encoding="utf-8") as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["userId", "gender", "age", "occupation"])
        for line in f_in:
            parts = line.rstrip("\n").split("::")
            # UserID::Gender::Age::Occupation::Zip — поштовий індекс відкидаємо
            writer.writerow(parts[:4])
    print(f"users.csv готовий → {dst}")

def convert_ratings(limit=None):
    src = os.path.join(SRC_DIR, "ratings.dat")
    dst = os.path.join(OUT_DIR, "ratings.csv")
    written = 0
    with open(src, encoding="latin-1") as f_in, \
         open(dst, "w", newline="", encoding="utf-8") as f_out:
        writer = csv.writer(f_out)
        writer.writerow(["userId", "movieId", "rating", "timestamp"])
        for line in f_in:
            # UserID::MovieID::Rating::Timestamp
            writer.writerow(line.rstrip("\n").split("::"))
            written += 1
            if limit is not None and written >= limit:
                break
    print(f"ratings.csv готовий ({written} рядків) → {dst}")


if __name__ == "__main__":
    convert_movies()
    convert_users()
    convert_ratings(MAX_RATINGS)
    print("Готово. Файли у папці import/ - Neo4j прочитає їх через file:///")

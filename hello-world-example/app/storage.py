import psycopg


class StorageUnavailable(Exception):
    pass


def store_url(url: str, domain: str) -> tuple[int, bool]:
    try:
        with psycopg.connect() as conn:
            row = conn.execute("SELECT id FROM urls WHERE url = %s", (url,)).fetchone()
            if row:
                return row[0], False

            url_id = conn.execute(
                "INSERT INTO urls (url, domain) VALUES (%s, %s) RETURNING id",
                (url, domain),
            ).fetchone()[0]
            return url_id, True
    except psycopg.OperationalError as e:
        raise StorageUnavailable() from e

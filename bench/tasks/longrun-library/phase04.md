Two things for the library service in this repo.

1. We're changing one of our API conventions: page sizes are too small. From now on the default `limit` is **50** and the maximum is **200**, for every list endpoint — the existing ones and every one we add from here on.
2. `GET /books` accepts an optional `author` filter: exact match, ignoring case.

Next for the library service in this repo: search.

`GET /books/search?q=...` returns books whose title or author contains `q`, ignoring case, oldest first, paginated like every other list. A missing or empty `q` is a validation error. Characters such as `%` and `_` in `q` match literally.

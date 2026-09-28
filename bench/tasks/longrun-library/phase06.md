Next for the library service in this repo: book reviews.

- `POST /books/{id}/reviews` `{"member_id", "rating", "text"?}` → `201` `{"id", "book_id", "member_id", "rating", "text", "created_at"}`. `rating` is an integer 1–5; `text` is optional (`null` when absent), at most 500 characters. Only a member who has borrowed that book at some point may review it (validation error otherwise), and only once (conflict). Unknown book or member → not found.
- `GET /books/{id}/reviews` → its reviews, newest first.
- `GET /books/{id}` gains `review_count` and `avg_rating` (mean rounded to 2 decimals; `null` with no reviews).

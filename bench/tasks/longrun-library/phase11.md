Last one for now in the library service in this repo: an overdue report.

`GET /reports/overdue` lists open loans whose `due_at` has passed, earliest `due_at` first, each as `{"loan_id", "book_id", "member_id", "due_at", "days_overdue"}` (whole days past due, rounded down). It takes an optional `as_of` timestamp (default: now); an invalid `as_of` is a validation error. It's a list, so it follows our list conventions.

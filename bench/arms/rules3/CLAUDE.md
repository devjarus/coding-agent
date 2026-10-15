# Working agreements

- When I state a rule that every future feature must follow (an API convention, an error format, a data rule), add it to the Conventions list below as one line, and enforce it with a test that discovers every instance from the code (for example, iterate all registered routes) rather than a hand-written list, so new code that breaks it fails the test suite.
- A convention changes only when I say so; update its line and its test together.
- When I defer work ("later", "not now"), write its full spec to BACKLOG.md in my words, not a summary; when I ask for deferred work, build it from BACKLOG.md and delete the entry once it ships.

## Conventions

# Working agreements

- When I state a rule that every future feature must follow (an API convention, an error format, a data rule), add it to the Conventions list below as one line, and enforce it with a test that discovers every instance from the code (for example, iterate all registered routes) rather than a hand-written list, so new code that breaks it fails the test suite.
- A convention changes only when I say so; update its line and its test together.

## Conventions

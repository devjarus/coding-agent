# Go Coding Patterns

## context.Context as First Parameter
```go
func (s *UserService) GetUser(ctx context.Context, id int64) (*User, error) {
    return s.repo.FindByID(ctx, id)
}
```

## Error Wrapping with %w
```go
user, err := s.repo.FindByID(ctx, id)
if err != nil {
    return nil, fmt.Errorf("getting user %d: %w", id, err)
}
```

## Small Interfaces at the Consumer
```go
// Define at point of use, not in the implementation package
type UserStore interface {
    FindByID(ctx context.Context, id int64) (*User, error)
    Save(ctx context.Context, u *User) error
}
```

## Table-Driven Tests
```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 1, 2, 3},
        {"negative", -1, -2, -3},
        {"zero", 0, 0, 0},
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            require.Equal(t, tc.expected, Add(tc.a, tc.b))
        })
    }
}
```

## Struct Embedding for Composition
```go
type BaseHandler struct {
    logger *slog.Logger
    db     *sql.DB
}

type UserHandler struct {
    BaseHandler
    userSvc UserService
}
```

## Graceful Shutdown
```go
srv := &http.Server{Addr: ":8080", Handler: router}
go func() {
    if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
        log.Fatal(err)
    }
}()

quit := make(chan os.Signal, 1)
signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
<-quit

ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
defer cancel()
if err := srv.Shutdown(ctx); err != nil {
    log.Fatal("Server forced to shutdown:", err)
}
```

## Useful Zero Values
Design types so the zero value is meaningful and ready to use. Avoid constructors when a zero-value struct works correctly.

## Package Organization
- Small, focused packages with clear single responsibilities
- Avoid circular imports -- use `internal/` for non-public packages
- Package names: short, lowercase, no underscores (`userstore` not `user_store`)

## Structured Logging
Use `log/slog` (Go 1.21+) for structured JSON logging:
```go
slog.Info("user created", "user_id", user.ID, "email", user.Email)
```

# Dependency Injection by Language

The same pattern in every language: define interface → accept via constructor → wire in one place → pass fakes in tests.

## TypeScript / Node.js

**Pattern:** Factory functions + composition root

```typescript
// composition-root.ts — the ONLY file that knows concrete classes
export function createApp() {
  const config = loadConfig();
  const db = new Pool(config.database);
  const logger = createLogger(config.logLevel);
  const userRepo = new PostgresUserRepo(db, logger);
  const userService = new UserService(userRepo, logger);
  return { app: buildExpressApp(userService), db, logger };
}
```

**Testing:** Pass fakes directly, no mocking library needed.
```typescript
const fakeRepo: UserRepository = { findById: async () => null, save: async () => {} };
const service = new UserService(fakeRepo, fakeLogger);
```

**Upgrade to container (awilix):** When composition root exceeds ~100 lines or you need per-request scoping.

## Python

**Pattern:** Constructor injection. FastAPI's `Depends()` for web apps.

```python
# FastAPI — Depends() IS your DI system
def get_user_repo(db: AsyncSession = Depends(get_db)) -> PostgresUserRepo:
    return PostgresUserRepo(db)

@app.get("/users/{id}")
async def get_user(service: UserService = Depends(get_user_service)):
    return await service.get_user(id)
```

```python
# Non-FastAPI — manual composition root
def create_app():
    config = load_config()
    db = create_engine(config.db_url)
    user_repo = PostgresUserRepo(db)
    user_service = UserService(user_repo, logger)
    return build_flask_app(user_service)
```

**Testing:** `app.dependency_overrides` for FastAPI. Direct injection for everything else.

## Java / Kotlin

**Pattern:** Constructor injection. Spring when you need the ecosystem.

```kotlin
// Manual — works without any framework
class UserService(
    private val repo: UserRepository,
    private val logger: Logger,
)

// Composition root
fun main() {
    val config = Config.load()
    val db = HikariDataSource(config.dbConfig)
    val userRepo = JdbcUserRepo(db)
    val userService = UserService(userRepo, Slf4jLogger("app"))
    // wire into HTTP framework
}
```

**Spring — use constructor injection, not field injection:**
```kotlin
// GOOD — Spring autowires via constructor
@Service
class UserService(
    private val repo: UserRepository,
    private val logger: Logger,
)

// BAD — field injection, hidden dependencies
@Service
class UserService {
    @Autowired lateinit var repo: UserRepository  // DON'T
}
```

**Dagger 2:** For Android or when you need compile-time DI with no reflection.

## Go

**Pattern:** `New*` constructor functions. "Accept interfaces, return structs."

```go
// Accept interface
func NewUserService(repo UserRepository, logger Logger) *UserService {
    return &UserService{repo: repo, logger: logger}
}

// main.go IS the composition root
func main() {
    cfg := config.MustLoad()
    db := must(sql.Open("postgres", cfg.DatabaseURL))
    userRepo := postgres.NewUserRepo(db)
    userSvc := service.NewUserService(userRepo, logger)
    // wire into HTTP
}
```

**Key Go rule:** Interfaces are defined by the **consumer**, not the producer.

**Wire:** Consider when main.go exceeds ~100 lines of wiring or multiple binaries share the graph.

## Swift

**Pattern:** Protocol-oriented injection. SwiftUI Environment for UI layer.

```swift
// Protocol
protocol UserRepository {
    func findById(_ id: String) async throws -> User?
}

// Constructor injection
final class UserService {
    private let repo: UserRepository
    init(repo: UserRepository) { self.repo = repo }
}

// SwiftUI — @Environment for DI
struct ContentView: View {
    @Environment(\.userService) private var userService
}

// Wire at app root
@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.userService, realUserService)
        }
    }
}
```

## When to Upgrade from Manual DI

| Signal | Stay Manual | Use Container |
|--------|------------|---------------|
| < 50 lines of wiring | Yes | No |
| 50-150 lines | Group into factory functions | Maybe |
| 150+ lines | No | Yes |
| Multiple entry points (CLI, HTTP, worker) | Maybe | Yes |
| Need per-request scoping | No | Yes |
| Framework provides DI (FastAPI, Spring, SwiftUI) | Use framework | — |

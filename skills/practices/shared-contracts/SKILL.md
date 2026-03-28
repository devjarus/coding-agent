---
name: shared-contracts
description: Patterns for sharing types, API contracts, and validation schemas between frontend and backend. Use when multiple domains consume the same data shapes to prevent contract drift.
---

# Shared Contracts

## When to Apply

- Project has both frontend and backend in the same repo
- API endpoints are consumed by frontend components
- Multiple services share data types
- Planner identifies cross-domain data dependencies

---

## Priority Rules

### CRITICAL

- **SHR-01:** Define shared types/schemas in ONE location — both frontend and backend import from it
- **SHR-02:** API request/response shapes are defined as Zod schemas (or equivalent) — used for both runtime validation and TypeScript type inference

### HIGH

- **SHR-03:** Shared package lives at a known path (e.g., `packages/shared/`, `lib/shared/`, or `src/types/api.ts` in a monorepo)
- **SHR-04:** Changes to shared contracts require updating BOTH consumers — never change a contract in isolation
- **SHR-05:** API error response format is standardized and shared (not reinvented per endpoint)

### MEDIUM

- **SHR-06:** Use Zod `z.infer<typeof schema>` for TypeScript types — single source of truth for type AND validation
- **SHR-07:** For REST APIs, consider OpenAPI spec as the contract — generate client types from it
- **SHR-08:** For tRPC/GraphQL, the framework IS the contract — lean on it instead of manual types

---

## Patterns

### Pattern 1: Shared Zod Schemas (monorepo or full-stack app)

Define the schema once in a shared location. Both the API route and the frontend import from it — the schema drives runtime validation on the server and form validation + TypeScript types on the client.

```ts
// packages/shared/src/schemas/user.ts
import { z } from "zod"

export const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  role: z.enum(["admin", "member", "viewer"]),
})

export type CreateUserInput = z.infer<typeof CreateUserSchema>
```

```ts
// backend: apps/api/src/routes/users.ts
import { CreateUserSchema } from "@myapp/shared/schemas/user"

app.post("/users", async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body)
  if (!result.success) {
    return res.status(400).json({ error: result.error.flatten() })
  }
  // result.data is fully typed as CreateUserInput
  await createUser(result.data)
  res.status(201).json({ ok: true })
})
```

```ts
// frontend: apps/web/src/features/users/CreateUserForm.tsx
import { CreateUserSchema, type CreateUserInput } from "@myapp/shared/schemas/user"

function CreateUserForm() {
  const { register, handleSubmit } = useForm<CreateUserInput>({
    resolver: zodResolver(CreateUserSchema), // same schema, client-side validation
  })
  // ...
}
```

### Pattern 2: OpenAPI Contract-First

Define the OpenAPI spec as the single source of truth. Generate server stubs and client types from it so both sides are always in sync — no manual type duplication.

```yaml
# openapi.yaml
paths:
  /users:
    post:
      requestBody:
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/CreateUserInput"
      responses:
        "201":
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/User"
```

```bash
# generate server types
npx openapi-typescript openapi.yaml --output src/types/api.d.ts

# generate client (e.g., with orval or openapi-fetch)
npx orval --input openapi.yaml --output src/api/client.ts
```

Both the backend route handler and the frontend API client are typed from the same spec. A breaking change to the spec surfaces as a TypeScript error in both.

### Pattern 3: tRPC (Next.js full-stack)

The router definition IS the contract. The frontend gets a type-safe client automatically — no codegen step, no manual types, no drift possible.

```ts
// server/routers/user.ts
export const userRouter = router({
  create: publicProcedure
    .input(
      z.object({
        email: z.string().email(),
        name: z.string().min(1),
      })
    )
    .mutation(async ({ input }) => {
      return db.user.create({ data: input })
    }),
})
```

```ts
// frontend component
const { mutate } = trpc.user.create.useMutation()
// input is fully typed — TypeScript errors if shape drifts
mutate({ email: "a@b.com", name: "Alice" })
```

---

## Anti-Patterns

| Anti-pattern | Why it's harmful |
|---|---|
| **Duplicating types in `frontend/` and `backend/` separately** | The two copies drift immediately. Renaming a field on one side silently breaks the other. |
| **Using `any` at API boundaries** | Defeats TypeScript entirely. Runtime shape mismatches become silent bugs. |
| **Changing backend response without updating the frontend consumer** | The contract is broken the moment the PR merges. Only caught at runtime or in E2E tests. |
| **TypeScript types only — no runtime validation** | Types disappear at compile time. An unexpected server payload or a bad environment variable causes a runtime crash with no useful error. |

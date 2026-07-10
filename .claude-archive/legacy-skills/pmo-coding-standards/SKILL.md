---
name: Coding Standards
description: กำหนด coding convention per project — naming, folder structure, linting, formatting — ให้ทีม Dev ทำงานบน standard เดียวกัน
---

# PMO Skill: Coding Standards

> **Purpose:** สร้าง Coding Standards Document ให้แต่ละ project
> Dev ทุกคนใช้ convention เดียวกัน ลด conflict, ลด review time

---

## 1. When to Use

- เมื่อเริ่ม project ใหม่ที่มี Dev team
- เมื่อสร้าง Code Scaffold (auto-load คู่กัน)
- เมื่อ Dev ถามว่า "ตั้งชื่อยังไง" หรือ "ใช้ pattern ไหน"

---

## 2. Standards Document Template

สร้างไฟล์ `{ProjectFolder}/Scaffold/CODING-STANDARDS.md`:

### 2.1 Naming Convention

| Item | Convention | Example |
|------|-----------|---------|
| **Files** | kebab-case | `user-service.ts`, `order-model.py` |
| **Classes** | PascalCase | `UserService`, `OrderModel` |
| **Functions** | camelCase (JS/TS) / snake_case (Python/Go) | `getUser()`, `get_user()` |
| **Constants** | UPPER_SNAKE | `MAX_RETRY`, `API_BASE_URL` |
| **DB Tables** | snake_case plural | `users`, `order_items` |
| **DB Columns** | snake_case | `created_at`, `user_id` |
| **API Endpoints** | kebab-case plural | `/api/v1/order-items` |
| **Components** | PascalCase | `UserProfile.tsx`, `OrderList.vue` |

### 2.2 Folder Structure Pattern

| Pattern | When to Use |
|---------|------------|
| **Feature-based** | Project > 10 modules, ทีม > 3 คน |
| **Layer-based** | Project < 10 modules, ทีม <= 3 คน |
| **Domain-driven** | Complex business logic, multiple bounded contexts |

### 2.3 Code Style Rules

| Rule | Standard |
|------|----------|
| **Indentation** | 2 spaces (JS/TS) / 4 spaces (Python) |
| **Max line length** | 100 characters |
| **Imports** | Group by: stdlib → third-party → local, alphabetical within group |
| **Comments** | Thai OK for business logic, English for technical |
| **Error handling** | Always catch + log + meaningful message, never swallow errors |
| **API Response** | Consistent format: `{ success, data, error, meta }` |

### 2.4 Git Convention

| Item | Format |
|------|--------|
| **Branch** | `{type}/{project-code}/{short-desc}` e.g. `feat/P07/login-flow` |
| **Commit** | `{type}({project}): {description}` e.g. `feat(P07): add login API` |
| **PR Title** | `[{project}] {type}: {description}` |

Commit types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`

### 2.5 Testing Standards

| Item | Standard |
|------|----------|
| **Minimum coverage** | 80% |
| **Test naming** | `should {action} when {condition}` |
| **Test structure** | Arrange → Act → Assert |
| **Required tests** | Happy path + Error cases + Edge cases per module |

---

## 3. Workflow

1. **ถาม user:** tech stack (language, framework, DB, ORM)
2. **ถาม user:** ทีมกี่คน, folder structure preference
3. **Generate** CODING-STANDARDS.md ตาม template + tech stack
4. **ถาม user:** มี standard เพิ่มเติมที่ต้องการไหม
5. **Finalize** + log Activity Log

---

## 4. Language-Specific Rules (v2.1.0)

Auto-load ตาม tech stack ที่ user ระบุ:

| Language | Key Rules |
|----------|----------|
| **TypeScript** | ห้าม `any`, explicit return types, async/await, strict null checks, named exports |
| **Python** | Type hints required, Google docstrings, specific exceptions, f-strings, pathlib, dataclasses |
| **Go** | Explicit error handling, context propagation, interface-first, struct composition |
| **Rust** | Ownership patterns, minimize unsafe, Result/Option over panic |
| **Java** | Optional over null, immutable default, Stream API, proper exception hierarchy |
| **Swift** | Protocol-oriented, value types, async/await concurrency, optional handling |

## 5. AI-SaaS Standards (v2.1.0)

สำหรับ AI product projects: tenant isolation, cost tracking, provider abstraction, prompt safety, rate limiting, fallback chains, output validation

## 6. Security Standards (v2.1.0)

Auto-include ทุก project: input validation (whitelist), output encoding (XSS prevention), no secrets in code, auth on every operation, OWASP Top 10

## 7. Integration

- `pmo-code-scaffold` อ่าน CODING-STANDARDS.md เพื่อ generate code ตาม convention
- `pmo-dev-report` เทียบ code กับ CODING-STANDARDS.md
- `pmo-ci-cd-template` generate linter config ตาม standards
- `pmo-security-scan` ใช้ security standards เป็น baseline

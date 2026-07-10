# Project-Level CLAUDE.md Template

> **อ้างอิง ECC (everything-claude-code) project templates**
> ใช้เป็น template สำหรับสร้าง CLAUDE.md ภายใน project folder แต่ละ project
> เมื่อ project เข้า Dev Phase ให้สร้างไฟล์นี้ใน `{ProjectFolder}/CLAUDE.md`

---

## Template

```markdown
@../../AGENTS.md

# P{XX}-{CODE} — {Project Name}

## Tech Stack
- **Frontend:** {Next.js 15 / React / Vue / Flutter / etc.}
- **Backend:** {Python FastAPI / Go / Node.js / etc.}
- **Database:** {PostgreSQL / Supabase / MongoDB / etc.}
- **Deployment:** {Docker / Vercel / AWS / etc.}

## Language Rules

> เลือกเฉพาะ rules ที่ตรงกับ tech stack ของ project
> อ้างอิงจาก ECC language-specific rules

### {Primary Language} Rules
<!-- Copy relevant rules from ECC rules/{language}/ -->
<!-- Common sections: coding-style, testing, security, patterns -->

- **Coding Style:** {conventions เช่น camelCase, snake_case, file naming}
- **Testing:** {framework เช่น pytest, vitest, go test} — ขั้นต่ำ 80% coverage
- **Security:** {language-specific security rules}
- **Patterns:** {patterns ที่ใช้ เช่น Repository pattern, Clean Architecture}

## Project-Specific Rules

### File Structure
```
{ProjectFolder}/
+-- src/ or app/          <- Application code
+-- tests/                <- Test files
+-- docs/                 <- Documentation
+-- ...
```

### Key Conventions
- {Convention 1 — เช่น ใช้ TypeScript strict mode}
- {Convention 2 — เช่น ทุก API response ใช้ envelope format}
- {Convention 3 — เช่น ห้าม console.log ใน production}

### Environment Variables
- `DATABASE_URL` — Database connection string
- `API_KEY` — External API key
- {อื่นๆ ตาม project}

## Dev Workflow
1. Branch จาก `main` → `feature/{module-name}`
2. เขียน test ก่อน (TDD) → implement → review
3. PR ต้องผ่าน lint + test + review
4. Merge ผ่าน PR เท่านั้น

## Reference
- **SystemFlow:** `../SystemFlow/` — flow diagrams ของทุก module
- **Dev Handoff:** `../SystemFlow/DEV_Handoff_*.md` — spec สำหรับ dev
- **TaskBoard:** `../SystemFlow/TaskBoard.md` — card assignments
```

---

## Language Rules Quick Reference

> **เลือก copy จาก ECC ตาม tech stack:**

| Tech Stack | ECC Rules Path | Key Rules |
|-----------|---------------|-----------|
| **TypeScript/React/Next.js** | `rules/typescript/` | strict mode, no any, functional components, Zod validation |
| **Python/FastAPI/Django** | `rules/python/` | type hints, Pydantic models, async/await, pytest |
| **Go** | `rules/golang/` | error handling (no panic), go vet, golangci-lint |
| **Java/Spring** | `rules/java/` | Lombok, JUnit 5, Spring Security |
| **Kotlin/Android** | `rules/kotlin/` | coroutines, Jetpack Compose, Hilt DI |
| **Rust** | `rules/rust/` | ownership, Result<T,E>, clippy |
| **Swift/iOS** | `rules/swift/` | SwiftUI, Combine, XCTest |
| **PHP/Laravel** | `rules/php/` | PSR-12, Eloquent, PHPUnit |

### Common Rules (ใช้ได้ทุกภาษา)

| Category | Rule |
|----------|------|
| **Testing** | ขั้นต่ำ 80% coverage (unit + integration + E2E) |
| **Security** | ห้าม hardcode secrets, validate ทุก input, parameterized queries |
| **Git** | Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `docs:` |
| **Error Handling** | ห้ามแสดง technical error ให้ end user |
| **Code Size** | ไฟล์ไม่เกิน 400 บรรทัด (max 800) |
| **Dependencies** | npm audit / pip audit ก่อน deploy |

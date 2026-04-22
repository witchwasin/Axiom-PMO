---
name: CI/CD Template
description: Generate GitHub Actions pipeline config จาก tech stack ของ project — ครอบคลุม test, lint, build, deploy stages
---

# PMO Skill: CI/CD Template

> **Purpose:** สร้าง CI/CD pipeline config ให้แต่ละ project
> PM กรอก tech stack → AI generate GitHub Actions workflow ที่พร้อมใช้

---

## 1. Prerequisites

- Tech stack info (language, framework, DB, package manager)
- Coding Standards (ถ้ามี — เพื่อ generate linter config ที่ตรงกัน)
- Test framework (jest, vitest, pytest, go test)

---

## 2. Pipeline Stages

```
┌─────────┐   ┌──────┐   ┌───────┐   ┌────────┐   ┌────────┐
│ Install │ → │ Lint │ → │ Test  │ → │ Build  │ → │ Deploy │
└─────────┘   └──────┘   └───────┘   └────────┘   └────────┘
```

### Stage Details

| Stage | What | Fail Action |
|-------|------|-------------|
| **Install** | Install dependencies | Block pipeline |
| **Lint** | Run linter (ESLint, Ruff, golangci-lint) | Block pipeline |
| **Test** | Run unit + integration tests, coverage report | Block if < 80% |
| **Build** | Build application, Docker image | Block pipeline |
| **Deploy** | Deploy to staging/production | Manual approval for production |

---

## 3. Templates by Tech Stack

### 3.1 Node.js / Next.js

```yaml
# .github/workflows/ci.yml
name: CI Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run test -- --coverage
      - run: npm run build

  docker:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ github.repository }}:latest
```

### 3.2 Python / FastAPI / Django

```yaml
name: CI Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install -r requirements.txt
      - run: ruff check .
      - run: pytest --cov --cov-report=xml
      - run: ruff format --check .
```

### 3.3 Go

```yaml
name: CI Pipeline
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: golangci-lint run
      - run: go test -race -coverprofile=coverage.out ./...
      - run: go build ./...
```

---

## 4. Additional Configs Generated

| File | Purpose |
|------|---------|
| `.github/workflows/ci.yml` | Main CI pipeline |
| `.github/workflows/deploy-staging.yml` | Staging deployment (auto on develop) |
| `.github/workflows/deploy-prod.yml` | Production deployment (manual trigger) |
| `.github/dependabot.yml` | Auto dependency updates |
| `Dockerfile` | Multi-stage build |
| `docker-compose.yml` | Local dev environment |
| `.dockerignore` | Exclude unnecessary files |

---

## 5. Workflow

1. **ถาม** tech stack (ถ้ายังไม่มี)
2. **Load** `pmo-coding-standards` (ถ้ามี) เพื่อ align linter config
3. **Generate** CI/CD config ตาม tech stack template
4. **Generate** Dockerfile + docker-compose.yml
5. **Generate** .github/dependabot.yml
6. **Save** ทั้งหมดไว้ที่ `{ProjectFolder}/Scaffold/.github/` และ root
7. **Log** Activity Log
8. **แจ้ง user** สรุปไฟล์ที่สร้าง + วิธี setup

---

## 6. Output Location

`{ProjectFolder}/Scaffold/` (AI-Managed)

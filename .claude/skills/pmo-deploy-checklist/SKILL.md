---
name: Deploy Checklist
description: Validation checklist ก่อน deploy — เช็ค environment, DB migration, test coverage, security, monitoring — เหมือน 38-point แต่สำหรับ deployment
---

# PMO Skill: Deploy Checklist

> **Purpose:** ป้องกัน deploy ที่ไม่พร้อม — ตรวจทุกด้านก่อน go-live
> เหมือน 38-point diagram validation แต่สำหรับ infrastructure/deployment

---

## 1. Pre-Deploy Checklist (30 items)

### Category A: Code Quality (8 items)

| # | Check | Pass Criteria |
|:-:|-------|---------------|
| A1 | Test coverage | >= 80% overall |
| A2 | All tests passing | 0 failures |
| A3 | Lint clean | 0 errors (warnings OK) |
| A4 | No debug artifacts | No console.log, debugger, print() in production code |
| A5 | No hardcoded secrets | No API keys, passwords, tokens in code |
| A6 | No TODO/FIXME blocking | No critical TODO items remaining |
| A7 | Code review approved | PR approved by at least 1 reviewer |
| A8 | Build succeeds | CI pipeline green |

### Category B: Database (6 items)

| # | Check | Pass Criteria |
|:-:|-------|---------------|
| B1 | Migration scripts ready | All migration files created + tested locally |
| B2 | Rollback script ready | Reverse migration available |
| B3 | Seed data prepared | Initial data scripts ready (if needed) |
| B4 | Backup taken | Current DB backed up before migration |
| B5 | Index optimization | Critical queries have proper indexes |
| B6 | Schema matches spec | DB schema matches Data Model from handoff |

### Category C: Environment (6 items)

| # | Check | Pass Criteria |
|:-:|-------|---------------|
| C1 | Environment variables set | All .env.example vars configured in target |
| C2 | SSL/TLS configured | HTTPS enforced |
| C3 | Domain/DNS ready | Domain pointed, propagation confirmed |
| C4 | Firewall rules set | Only required ports open |
| C5 | Resource limits configured | CPU/memory/disk limits set |
| C6 | Logging configured | Application logs routed to monitoring |

### Category D: Security (5 items)

| # | Check | Pass Criteria |
|:-:|-------|---------------|
| D1 | Authentication working | Login/logout/token refresh tested |
| D2 | Authorization tested | Role-based access per SystemFlow |
| D3 | Input validation | All user inputs sanitized |
| D4 | CORS configured | Only allowed origins |
| D5 | Rate limiting active | API rate limits enforced |

### Category E: Monitoring & Observability (5 items)

| # | Check | Pass Criteria |
|:-:|-------|---------------|
| E1 | Health check endpoint | /health returns 200 |
| E2 | Error tracking setup | Sentry/equivalent configured |
| E3 | Uptime monitoring | Pingdom/UptimeRobot configured |
| E4 | Alert rules set | Notify team on downtime/errors |
| E5 | Log aggregation | Centralized logging accessible |

---

## 2. Scoring

| Score | Label | Action |
|:-----:|-------|--------|
| 30/30 | READY | Deploy ได้เลย |
| 25-29 | REVIEW | ตรวจ items ที่ไม่ผ่าน ถ้าไม่ critical deploy ได้ |
| 20-24 | WARN | มี items สำคัญที่ยังไม่ผ่าน ควรแก้ก่อน |
| < 20 | BLOCK | ห้าม deploy — ต้องแก้ก่อน |

---

## 3. Workflow

1. **อ่าน** project artifacts: CI/CD config, test results, DB migrations
2. **รัน** checklist 30 items ทีละข้อ
3. **ให้คะแนน** + สรุปผล
4. **แจ้ง user** items ที่ไม่ผ่าน + คำแนะนำ
5. **Log** Activity Log + Decision Log (ถ้า user ตัดสินใจ deploy แม้มี warnings)

---

## 4. Enhanced Security (v2.1.0)

Category D ขยายจาก 5 → 12 items โดยอ้างอิง `pmo-security-scan`:
- D6: Security scan passed (0 Critical)
- D7: No secrets in code (20 patterns)
- D8: Dependency audit clean
- D9: HTTPS enforced
- D10: CSRF protection
- D11: Security headers (X-Frame-Options, HSTS, CSP)
- D12: AI safety (prompt injection + rate limits, AI projects only)

**Total: 30 → 37 items**

## 5. Dependency Audit (v2.1.0)

Auto-check: vulnerable packages (CVEs), floating versions, deprecated packages

## 6. Integration

- `pmo-quality-gate` Post-Gate: deploy checklist = gate สุดท้าย
- `pmo-traceability` Change Log
- `pmo-ci-cd-template` cross-check CI config
- `pmo-security-scan` ผลลัพธ์เป็น input สำหรับ Category D

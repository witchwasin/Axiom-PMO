---
name: Security Scan
description: สแกน code ใน Scaffold/ ด้วย 53 security rules (6 หมวด) — secrets, permissions, injection, AI-specific, config, dependencies — ก่อน deploy หรือหลัง Dev report
---

# PMO Skill: Security Scan

> **Purpose:** ตรวจ code ที่ Dev เขียน / Scaffold ที่ generate ด้วย security rules 53 ข้อ
> ดึง concept จาก external execution-framework security scanning

---

## 1. When to Use

- หลัง Dev report เสร็จ (ก่อนส่ง QA)
- ก่อนรัน Deploy Checklist
- เมื่อ PM/Dev ขอ "scan security" หรือ "ตรวจความปลอดภัย"
- Auto-trigger จาก Quality Gate Post-Gate (ถ้า project มี Scaffold/)

---

## 2. Security Rules (53 Rules, 6 Categories)

### A: Secrets Detection (20 rules) — Critical/High
- Stripe, AWS, GitHub, Slack, Google Cloud, Azure, Twilio, SendGrid, Mailgun tokens
- RSA/EC/OpenSSH private keys, JWT tokens, npm tokens
- MongoDB/SQL connection strings, Docker registry auth
- .env files committed, hardcoded passwords, API keys in URLs, Firebase config

### B: Permissions (8 rules) — Critical/High
- chmod 777, sudo in script, Docker root, wildcard CORS
- Public S3/GCS buckets, disabled auth, weak CSP, missing RBAC

### C: Injection (11 rules) — Critical/High
- SQL concat, command injection, XSS (innerHTML/dangerously), path traversal
- SSRF, template injection (eval/Function), CRLF, LDAP, XXE, prototype pollution

### D: AI-Specific Security (8 rules) — Critical/High
- Prompt injection, model extraction, PII in AI context
- Unlimited token limits, unvalidated AI output, missing rate limit
- Cross-tenant data leakage, unmasked AI provider keys

### E: Configuration (3 rules) — Critical/High
- Debug mode in production, default credentials, missing HTTPS

### F: Dependencies (3 rules) — High/Medium
- Vulnerable packages, floating versions, deprecated packages

---

## 3. Scan Output

```markdown
# Security Scan Report — P{XX}-{CODE}
**Date:** {date} | **Files:** {count} | **Findings:** {total}

## Critical ({N})
| Rule | File | Line | Fix |
|------|------|------|-----|

## High ({N})
| Rule | File | Line | Fix |
|------|------|------|-----|

## Medium ({N})
| Rule | File | Line | Fix |
|------|------|------|-----|
```

---

## 4. Scoring

| Findings | Result | Action |
|----------|--------|--------|
| 0 Critical, 0 High | PASS | Deploy ได้ |
| 0 Critical, 1+ High | REVIEW | ตรวจก่อน deploy |
| 1+ Critical | FAIL | ห้าม deploy |

---

## 5. Integration

- `pmo-deploy-checklist` Category D อ้างอิงผลจาก scan
- `pmo-quality-gate` Post-Gate auto-trigger scan หลังสร้าง scaffold
- `pmo-dev-report` แนะนำ scan ก่อนส่ง QA
- `pmo-traceability` Log scan result ลง Activity Log

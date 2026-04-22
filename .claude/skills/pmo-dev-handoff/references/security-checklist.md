# OWASP Top 10 Security Checklist for Dev Handoff

> **อ้างอิง ECC security-review skill** — ใช้เสริม Security & Compliance section (Step 6) ของ Dev Handoff
> Dev ต้องตรวจ checklist นี้ก่อน deploy ทุกครั้ง

---

## Pre-Deployment Security Checklist

### 1. Secrets Management
- [ ] ไม่มี hardcoded secrets ใน code (API keys, passwords, tokens)
- [ ] ทุก secret อยู่ใน environment variables หรือ secret manager
- [ ] `.env` อยู่ใน `.gitignore` เสมอ
- [ ] ไม่มี secret ใน git history (ตรวจด้วย `git log --all -S "password"`)

### 2. Input Validation
- [ ] ทุก user input ผ่าน validation (Zod / Pydantic / Joi)
- [ ] Validate ทั้ง **frontend + backend** (frontend = UX, backend = security)
- [ ] File uploads: ตรวจ size, type, extension (ห้ามเชื่อ Content-Type อย่างเดียว)
- [ ] ตรวจ max length ทุก text field เพื่อป้องกัน buffer overflow

### 3. SQL Injection Prevention
- [ ] ทุก query ใช้ **parameterized queries** หรือ ORM
- [ ] ห้ามใช้ string concatenation สร้าง SQL
- [ ] ถ้าใช้ raw SQL ต้อง escape ทุก parameter
- [ ] Supabase: ใช้ `.eq()`, `.in()` ไม่ใช่ `.or('field.eq.value')`

### 4. Authentication & Authorization
- [ ] Token (JWT) เก็บใน **httpOnly cookie** (ห้าม localStorage)
- [ ] ใช้ `getUser()` ไม่ใช่ `getSession()` สำหรับ server-side auth check
- [ ] ทุก API endpoint ตรวจ **role/permission** ก่อนทำงาน
- [ ] Session timeout + concurrent session limit
- [ ] Password hashing ใช้ bcrypt/argon2 (ห้าม MD5/SHA1)
- [ ] Login: rate limit + lockout หลัง N attempts (ดูจาก SystemFlow)

### 5. XSS Prevention
- [ ] User-generated content ผ่าน **sanitization** ก่อนแสดงผล
- [ ] ใช้ framework auto-escaping (React JSX, Vue template)
- [ ] ห้ามใช้ `dangerouslySetInnerHTML` / `v-html` กับ user input
- [ ] CSP (Content-Security-Policy) headers configured

### 6. CSRF Protection
- [ ] CSRF token ใน form submissions
- [ ] SameSite cookie attribute = `Strict` หรือ `Lax`
- [ ] API endpoints ตรวจ Origin/Referer header

### 7. Rate Limiting
- [ ] ทุก public endpoint มี rate limit
- [ ] Login endpoint: stricter rate limit (เช่น 5 attempts / 15 min)
- [ ] API endpoints ที่เกี่ยวกับเงิน: stricter rate limit
- [ ] Return `429 Too Many Requests` พร้อม `Retry-After` header

### 8. Sensitive Data Exposure
- [ ] ห้าม log sensitive data (password, token, credit card)
- [ ] Error response ห้ามแสดง stack trace / internal details
- [ ] API response ส่งเฉพาะ field ที่จำเป็น (ห้าม `SELECT *`)
- [ ] HTTPS enforced ใน production

### 9. Dependency Security
- [ ] `npm audit` / `pip audit` / `go mod verify` ก่อน deploy
- [ ] Lock file (`package-lock.json`, `poetry.lock`) commit ใน repo
- [ ] ไม่มี dependency ที่มี known critical vulnerability

### 10. Access Control (RBAC)
- [ ] Row Level Security (RLS) enabled ถ้าใช้ Supabase/PostgreSQL
- [ ] ทุก data access ผ่าน permission check
- [ ] Admin endpoints แยก middleware
- [ ] CORS configured correctly (ไม่ใช่ `*` ใน production)

---

## Per-Module Security Assessment Template

> **ใส่ใน Dev Handoff Step 6 — ตรวจทุก module:**

```markdown
## Security Assessment

| Module | Auth | RBAC | Audit Log | PDPA | Rate Limit | Fraud Prevention | Risk Level |
|--------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Auth/Login | N/A | - | Y | - | Y (5/15min) | Lockout | HIGH |
| User Management | Y | Y | Y | Y (PII) | Y | - | HIGH |
| Dashboard | Y | Y | - | - | Y | - | LOW |
| Payment/Withdraw | Y | Y | Y | - | Y (strict) | Maker-Checker | CRITICAL |
| Report/Export | Y | Y | Y | Y (PII) | Y | - | MEDIUM |
```

### Risk Level Criteria

| Risk Level | เงื่อนไข |
|:---:|---|
| **CRITICAL** | เกี่ยวกับเงิน, Financial transactions, Approve/Reject flow |
| **HIGH** | เกี่ยวกับ Auth, PII data, Admin actions |
| **MEDIUM** | เกี่ยวกับ Data modification, Export, Report |
| **LOW** | Read-only, Dashboard, Search |

---

## Industry-Specific Security (เพิ่มตามประเภท project)

| อุตสาหกรรม | Security เพิ่มเติม |
|-----------|------------------|
| **FinTech / การเงิน** | KYC/AML (ปปง.), Reconciliation, Audit Trail ทุก transaction, Maker-Checker |
| **E-Commerce** | PCI-DSS (ถ้ารับ card), Fraud detection, Refund audit |
| **Healthcare** | HIPAA/Patient consent, Medical data encryption at rest, Emergency access log |
| **Education / เด็ก** | COPPA/PDPA age gate, Parental consent, Content moderation |
| **ทั่วไป** | PDPA consent flow (ถ้ามี PII), Audit trail (ถ้ามี action สำคัญ) |

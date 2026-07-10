# Realistic Scope Guide — แนวทางตั้ง Scope ให้สมจริง

> แนวคิดจาก Senior PM methodology: "ห้าม Gold Plate, ห้าม Fantasy Estimate"

---

## หลักการ Realistic Scope

### 1. Quote Exact Requirements — ห้ามเพิ่มเอง

เวลาแปลง MOM/REQ เป็น task:
- **อ้างอิงข้อความจริง** จาก MOM/REQ ไม่ใช่ตีความเอง
- **ห้ามเพิ่ม "luxury" features** ที่ไม่ได้อยู่ใน spec
- ถ้าเห็นว่าขาดอะไร → **ถามผู้ใช้** ไม่ใช่เพิ่มเอง

ตัวอย่าง:
- REQ บอก "ระบบ login" → task คือ "ระบบ login" ไม่ใช่ "ระบบ login + 2FA + social login + biometric"
- ถ้าเห็นว่าควรมี 2FA → ถามว่า "ต้องการ 2FA ด้วยไหม?" ก่อนเพิ่ม

### 2. Task Size — 30-60 นาที implementable

แต่ละ task ใน breakdown ควร:
- **Developer ทำจบได้ใน 30-60 นาที** (ถ้า task ใหญ่กว่านี้ ควรแตกย่อย)
- **มี Acceptance Criteria** ที่ทดสอบได้ชัดเจน
- **มี file/location** ที่ต้อง create/edit ชัดเจน

### 3. Acceptance Criteria — ทุก task ต้องมี

เพิ่ม column "Acceptance Criteria" ในตาราง task:

```markdown
| # | Task | Duration | Acceptance Criteria |
|---|------|----------|-------------------|
| 2.1 | สร้างหน้า Login | 2d | - หน้า login render ได้ไม่ error |
| | | | - กรอก email + password ได้ |
| | | | - กด login แล้ว redirect ไปหน้าหลัก |
| | | | - กรอกผิดแสดง error message |
```

### 4. Learning from Experience — Track สิ่งที่พลาด

บันทึก pattern ที่เจอบ่อย:

| Pattern | วิธีป้องกัน |
|---------|-----------|
| **Estimate ต่ำเกินไป** | คูณ 1.5 สำหรับงานที่ไม่เคยทำ |
| **ลืม integration testing** | เพิ่ม buffer 20% สำหรับ integration |
| **ลืม environment setup** | เพิ่ม task "Environment Setup" ใน Phase 1 เสมอ |
| **ลืม data migration** | ถามว่ามี data เดิมไหม ถ้ามี ต้องมี migration task |
| **Scope creep ระหว่างทาง** | Lock scope ด้วย sign-off ก่อนเริ่ม dev |

### 5. Revision Cycles — คิดเผื่อแก้ไข

การ implement ครั้งแรกมักต้องแก้ 2-3 รอบ:
- **รอบ 1:** Build ตาม spec
- **รอบ 2:** แก้ตาม feedback จาก PM/client
- **รอบ 3:** Polish + edge cases

ดังนั้น estimate ควรรวม revision buffer ไว้ด้วย โดยเฉพาะ task ที่เป็น UI/UX

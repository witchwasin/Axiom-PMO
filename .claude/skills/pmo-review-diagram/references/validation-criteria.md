# Review Diagram — Validation Criteria Reference

> เอกสารอ้างอิงสำหรับ pmo-review-diagram skill — อธิบายเกณฑ์การตรวจแต่ละข้อ

## 3 ระดับ Validation

### Level 1: Lark 7 Rules (Syntax)

ตรวจว่า .puml file render ผ่าน Lark Docs — load `pmo-lark-plantuml` skill สำหรับรายละเอียด

| Rule | สิ่งที่ตรวจ | Auto-fixable? |
|------|----------|---------------|
| 1. FLAT CODE | ไม่มี leading whitespace | ใช่ |
| 2. No Ampersand | ไม่มี & ในข้อความภาษาไทย | ใช่ (เปลี่ยนเป็น "และ") |
| 3. Start Keyword | บรรทัดแรกเป็น @startuml | ใช่ |
| 4. Single-line Action | ทุก action อยู่บรรทัดเดียว | ต้องเขียนใหม่ |
| 5. Elseif Label | elseif ต้องมี (label) | ต้องเพิ่ม label |
| 6. No Legend | ไม่ใช้ legend block | เปลี่ยนเป็น note |
| 7. Safe ASCII | ไม่มี special char ที่ Lark parse ไม่ได้ | ต้องเปลี่ยน char |

### Level 2: Case Analysis 20 ข้อ (Content)

ตรวจว่า diagram ครอบคลุม business logic ครบ — load `pmo-activity-diagram/references/case-checklist.md` สำหรับ checklist เต็ม

**สรุป 5 หมวดหลัก:**

| หมวด | ข้อที่ | สิ่งที่ตรวจ |
|------|-------|----------|
| **Happy Path** | 1-3 | Main flow ครบ, step เรียงถูก, ผลลัพธ์ถูก |
| **Alternative Path** | 4-8 | ทุกทางเลือกมี branch, condition ชัดเจน |
| **Exception/Error** | 9-13 | Error handling ครบ, retry/fallback มี |
| **Edge Case** | 14-17 | Boundary condition, concurrent, timeout |
| **Cross-cutting** | 18-20 | Security, logging, notification |

**เกณฑ์:**
- PASS: ข้อนั้นครอบคลุมใน diagram หรือ out of scope (ระบุเหตุผล)
- FAIL: ข้อนั้นควรมีแต่ไม่ได้ใส่ใน diagram

### Level 3: MOM Validation 7 ข้อ (Compliance)

ตรวจว่า diagram ตรงกับ MOM ที่ตกลงกับลูกค้า — load `pmo-activity-diagram/references/mom-validation.md` สำหรับ checklist เต็ม

| ข้อ | สิ่งที่ตรวจ | วิธีตรวจ |
|-----|----------|---------|
| 1. Requirement Coverage | ทุก requirement ใน MOM มี step ใน diagram | เทียบ MOM requirement กับ diagram step |
| 2. Business Rule Match | เงื่อนไข/กฎธุรกิจตรงกับ MOM | เทียบ condition ใน diagram กับ MOM |
| 3. Actor Complete | Actor ครบตาม MOM | เทียบ actor ใน diagram กับ MOM |
| 4. Case Complete | ครอบคลุมทุก case (Happy + Alt + Exception) | นับ case type ใน diagram |
| 5. No Gold Plating | ไม่มีอะไรเกินที่ MOM ตกลง | ตรวจทุก step ว่ามี MOM reference |
| 6. Terminology Match | คำศัพท์ตรงกับ MOM | เทียบ term ทีละตัว |
| 7. Phase Correct | อยู่ใน scope ที่ตกลง | ตรวจว่าไม่มี feature จาก phase อื่น |

---

## Severity Classification

เมื่อพบปัญหา ให้ classify ตามความรุนแรง:

| Severity | คำอธิบาย | ตัวอย่าง | Action |
|----------|----------|---------|--------|
| **Critical** | Logic ผิด / ขาด requirement สำคัญ | MOM กำหนด Maker-Checker แต่ diagram ไม่มี | ต้องแก้ก่อน finalize |
| **High** | ขาด case สำคัญ / Gold Plating | ไม่มี error handling สำหรับ payment failure | ต้องแก้ |
| **Medium** | Terminology ไม่ตรง / ลำดับ step ไม่ optimal | ใช้ "ผู้ดูแล" แทน "Admin" ที่ MOM ใช้ | ควรแก้ |
| **Low** | Style/formatting issue | สีไม่ตรง convention | แก้ได้ ไม่บังคับ |

---

## Review Output Format

```
=== Diagram Review: {filename} ===
Project: P{XX}-{CODE}
Ref: MOM#{X} - {Topic}
Review Date: YYYY-MM-DD

--- Level 1: Lark 7 Rules ---
Result: {N}/7 PASS
{แสดงเฉพาะข้อที่ FAIL พร้อม fix suggestion}

--- Level 2: Case Analysis ---
Result: {N}/20 PASS
{แสดงเฉพาะข้อที่ FAIL พร้อม severity + recommendation}

--- Level 3: MOM Validation ---
Result: {N}/7 PASS
{แสดงเฉพาะข้อที่ FAIL พร้อม MOM reference ที่ขัดแย้ง}

--- Summary ---
Total: Lark {N}/7 + Case {N}/20 + MOM {N}/7
Status: {VALIDATED / GAP FOUND — must fix N items}
Critical Issues: {count}
Action Required: {list ถ้ามี}
```

---

## Tips สำหรับ Reviewer

1. **อ่าน MOM ก่อน diagram** — เข้าใจ context ก่อนตรวจ ไม่ใช่ดูแค่ syntax
2. **ตรวจ Lark Rules ก่อน** — ถ้า syntax ไม่ผ่าน ไม่ต้องตรวจ content (แก้ syntax ก่อน)
3. **เน้น Critical/High ก่อน** — Medium/Low แก้ทีหลังได้
4. **Cross-reference Decision Log** — ถ้ามี decision ที่เกี่ยวข้อง ให้อ้างอิง Decision ID
5. **บันทึก Activity Log** — ทุกครั้งที่ validate ต้อง log ลง Activity Log ด้วย

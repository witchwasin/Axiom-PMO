# Use Case Diagram — Validation Checklist

> ใช้ตรวจ Use Case Diagram ก่อน finalize ทุกครั้ง

## Checklist (7 ข้อ)

### 1. Actor Completeness
- **ตรวจอะไร:** Actor ครบตาม MOM/REQ หรือไม่
- **วิธีตรวจ:** เทียบ actor ใน diagram กับ actor ที่ MOM/REQ ระบุ
- **PASS:** Actor ครบทุกตัว ไม่มี actor ที่ MOM ไม่ได้ระบุ
- **FAIL:** ขาด actor / มี actor เกินที่ MOM ไม่ได้ตกลง

### 2. Use Case Coverage
- **ตรวจอะไร:** Use Case ครอบคลุม requirement ทุกข้อหรือไม่
- **วิธีตรวจ:** เทียบ use case กับ REQ feature list ทีละข้อ
- **PASS:** ทุก requirement มี use case รองรับ
- **FAIL:** มี requirement ที่ไม่มี use case คู่กัน

### 3. System Boundary
- **ตรวจอะไร:** System boundary ถูกต้อง ครอบ use case ทั้งหมดที่อยู่ในระบบ
- **วิธีตรวจ:** ตรวจว่า rectangle/package ครอบ use case ที่เป็นของระบบ
- **PASS:** Boundary ครอบ use case ครบ ชื่อ system ตรงกับ MOM
- **FAIL:** Use case อยู่นอก boundary ทั้งที่เป็นของระบบ / ชื่อ system ไม่ตรง

### 4. Relationship Correctness
- **ตรวจอะไร:** ความสัมพันธ์ (include, extend, generalization) ถูกต้องตาม semantic
- **วิธีตรวจ:**
  - `<<include>>` = use case A ต้องทำ B เสมอ (mandatory)
  - `<<extend>>` = use case A อาจทำ B (optional/conditional)
  - Generalization = actor/use case สืบทอดจาก parent
- **PASS:** ทุก relationship ถูกประเภท ไม่สลับ include/extend
- **FAIL:** สลับ include กับ extend / ใช้ generalization ผิด

### 5. Terminology Match
- **ตรวจอะไร:** ชื่อ actor, use case, system ตรงกับ MOM/REQ
- **วิธีตรวจ:** เทียบชื่อทีละตัวกับ MOM/REQ
- **PASS:** ชื่อตรงทุกตัว ไม่มีการเปลี่ยนคำศัพท์เอง
- **FAIL:** ชื่อไม่ตรง / ใช้คำต่างจาก MOM

### 6. No Gold Plating
- **ตรวจอะไร:** ไม่มี use case หรือ actor ที่ MOM/REQ ไม่ได้ระบุ
- **วิธีตรวจ:** ตรวจทุก element ว่ามี MOM/REQ reference หรือไม่
- **PASS:** ทุก element มี source reference
- **FAIL:** มี use case/actor ที่ "เพิ่มเอง" โดยไม่มี source

### 7. MOM Reference
- **ตรวจอะไร:** Diagram title มี `[Ref: MOM#X - หัวข้อ]`
- **วิธีตรวจ:** ตรวจ title line ของ .puml file
- **PASS:** มี MOM reference ครบ ตรงกับ MOM ที่เป็น source
- **FAIL:** ไม่มี MOM reference / reference ผิด MOM

---

## Summary Format

```
Use Case Diagram Validation — {Module Name}
Checklist Result: {N}/7 PASS
1. Actor Completeness    — {PASS/FAIL}: {detail}
2. Use Case Coverage     — {PASS/FAIL}: {detail}
3. System Boundary       — {PASS/FAIL}: {detail}
4. Relationship Correct  — {PASS/FAIL}: {detail}
5. Terminology Match     — {PASS/FAIL}: {detail}
6. No Gold Plating       — {PASS/FAIL}: {detail}
7. MOM Reference         — {PASS/FAIL}: {detail}
Status: {VALIDATED / GAP FOUND}
```

---

## Common Mistakes

| ผิดบ่อย | สาเหตุ | วิธีแก้ |
|---------|--------|--------|
| สลับ include กับ extend | ไม่เข้าใจ semantic | include = ต้องทำเสมอ, extend = optional |
| Actor เกินจริง | เพิ่ม actor ที่ MOM ไม่ได้ตกลง | ตรวจ MOM ก่อนเพิ่ม actor |
| Use Case ซ้ำกัน | ตั้งชื่อต่างแต่ความหมายเดียวกัน | ใช้ชื่อจาก REQ เป็นมาตรฐาน |
| ไม่มี system boundary | ลืมใส่ rectangle | ต้องมี boundary ทุก diagram |

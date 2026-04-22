# Wireframe Review Checklist — Detailed Criteria

> **ใช้ checklist นี้ตรวจ wireframe ทุกครั้งก่อน deliver**
> ต้องผ่านทุกข้อ (12/12) จึงจะถือว่า PASS — ถ้า FAIL ข้อไหนต้องแก้ไขก่อน deliver

---

## 1. Requirement Coverage

**ตรวจอะไร:** wireframe ครอบคลุม feature ทั้งหมดที่ MOM/REQ กำหนดหรือไม่

**วิธีตรวจ:**
- เปิด `REQ/` → list feature ที่เกี่ยวกับหน้าจอนี้
- เปิด `MOM/` → list business rule ที่เกี่ยวข้อง
- ✅ เทียบทีละข้อว่า wireframe มี element รองรับครบ

**PASS เมื่อ:** ทุก feature/business rule มี element ใน wireframe
**FAIL เมื่อ:** มี feature ที่ไม่มี element รองรับ → ระบุว่าขาดข้อไหน

---

## 2. User Flow Alignment

**ตรวจอะไร:** wireframe ตรงกับ User Flow (`.puml`) ที่ validate แล้วหรือไม่

**วิธีตรวจ:**
- เปิด `UserFlow/` → หา flow ที่เกี่ยวข้อง
- ✅ เทียบ step-by-step: ทุก step ใน flow มีหน้าจอ/element รองรับ
- ✅ ทุก decision point ใน flow มี UI แสดงทางเลือก

**PASS เมื่อ:** wireframe สามารถ walk-through ตาม User Flow ได้ครบทุก step
**FAIL เมื่อ:** มี step ใน flow ที่ wireframe ไม่มีหน้าจอรองรับ → ระบุ step ที่ขาด

---

## 3. All States (Default, Empty, Loading, Error, Success)

**ตรวจอะไร:** wireframe แสดง state ครบทุกสถานะที่เป็นไปได้

**วิธีตรวจ:**
- ✅ **Default State** — หน้าจอเมื่อมีข้อมูลปกติ
- ✅ **Empty State** — หน้าจอเมื่อไม่มีข้อมูล (เช่น ตารางว่าง, ไม่มี transaction) → ต้องมี message + CTA (ถ้าเหมาะสม)
- ✅ **Loading State** — ขณะโหลดข้อมูล (spinner, skeleton, progress bar)
- ✅ **Error State** — เมื่อเกิดข้อผิดพลาด (API error, validation error, timeout) → ต้องมี error message + recovery action
- ✅ **Success State** — เมื่อทำ action สำเร็จ (success message, confirmation, redirect)

**PASS เมื่อ:** มี state ครบทั้ง 5 (หรือ annotate ว่า state ไหนไม่เกี่ยวข้อง + เหตุผล)
**FAIL เมื่อ:** ขาด state ที่ควรมี โดยไม่มีเหตุผล

---

## 4. Navigation

**ตรวจอะไร:** user รู้ว่าตัวเองอยู่ตรงไหน และไปไหนต่อได้

**วิธีตรวจ:**
- ✅ มี breadcrumb หรือ visual indicator บอกตำแหน่งปัจจุบัน
- ✅ Active menu item ถูก highlight
- ✅ มี back button หรือ navigation ไปหน้าก่อนหน้า (ถ้าเหมาะสม)
- ✅ CTA (Call-to-Action) หลักมองเห็นชัดเจน

**PASS เมื่อ:** user ไม่หลงทาง — รู้ตำแหน่ง + เห็นทางไปต่อ
**FAIL เมื่อ:** ไม่มี indicator บอกตำแหน่ง หรือ navigation ไม่ชัดเจน

---

## 5. Data Display

**ตรวจอะไร:** ข้อมูลจัดกลุ่มชัดเจนและอ่านง่าย

**วิธีตรวจ:**
- ✅ ข้อมูลจัดกลุ่มตาม hierarchy ที่สมเหตุสมผล (สำคัญสุดอยู่ด้านบน/ซ้าย)
- ✅ ตาราง/list มี pagination หรือ infinite scroll (ถ้าข้อมูลเยอะ)
- ✅ มี sort/filter ที่เหมาะสม (ถ้า MOM/REQ กำหนด)
- ✅ ตัวเลข/สกุลเงิน format ถูกต้อง
- ✅ วันที่/เวลา format เหมาะสมกับ locale

**PASS เมื่อ:** ข้อมูลอ่านง่าย จัดกลุ่มสมเหตุสมผล ไม่ต้องเดา
**FAIL เมื่อ:** ข้อมูลกระจัดกระจาย ไม่มี hierarchy ชัด

---

## 6. Actions

**ตรวจอะไร:** ปุ่ม/action ชัดเจน user รู้ว่ากดแล้วจะเกิดอะไร

**วิธีตรวจ:**
- ✅ Primary action มองเห็นชัดเจน (สี, ขนาด, ตำแหน่ง)
- ✅ Destructive action (ลบ, ยกเลิก) มี visual warning (สีแดง, confirmation dialog)
- ✅ Label ของปุ่มบอก action ชัด (ใช้ verb: "บันทึก", "ยืนยัน" ไม่ใช่ "ตกลง")
- ✅ Disabled state ชัดเจน — user รู้ว่าทำไมกดไม่ได้
- ✅ มี confirmation dialog สำหรับ action ที่ irreversible

**PASS เมื่อ:** ทุกปุ่ม/action มี label ชัด + user รู้ผลลัพธ์ก่อนกด
**FAIL เมื่อ:** มีปุ่มที่ label ไม่ชัด หรือ destructive action ไม่มี confirmation

---

## 7. Form & Input

**ตรวจอะไร:** validation rules ตรงกับ MOM/REQ + error message ชัดเจน

**วิธีตรวจ:**
- ✅ Required fields มีเครื่องหมาย (`*`)
- ✅ Input type เหมาะสม (number field ใส่ตัวอักษรไม่ได้, date picker สำหรับวันที่)
- ✅ Validation rules ตรงกับ MOM/REQ (เช่น password complexity, phone format)
- ✅ Error message อยู่ใกล้ field ที่ผิด + บอกวิธีแก้
- ✅ Form มี clear/reset option (ถ้า field เยอะ)
- ✅ มี placeholder text เป็นตัวอย่าง format

**PASS เมื่อ:** form validations ครบ + error messages ชัด + ตรงกับ MOM/REQ
**FAIL เมื่อ:** ขาด validation rules ที่ MOM กำหนด หรือ error message ไม่ชัด

---

## 8. Responsive

**ตรวจอะไร:** wireframe ทำงานได้กับหน้าจอขนาดต่างๆ

**วิธีตรวจ:**
- ✅ **Web (BOF):** Desktop-first แต่ต้อง annotate ว่า tablet/mobile จะแสดงยังไง (ถ้า MOM กำหนด)
- ✅ **Mobile App (CSA):** Mobile-first + annotate landscape behavior
- ✅ Content ไม่ล้น/ถูกตัดเมื่อหน้าจอเล็ก
- ✅ Navigation เปลี่ยนเป็น hamburger/bottom tab เมื่อหน้าจอเล็ก (ถ้าเหมาะสม)

**PASS เมื่อ:** มี annotation/design สำหรับ screen size ที่ MOM กำหนด
**FAIL เมื่อ:** ไม่มีการ consider responsive เลย (สำหรับ platform ที่ต้องการ)
**N/A เมื่อ:** platform ไม่ต้องการ responsive (เช่น BOF เฉพาะ desktop)

---

## 9. Terminology

**ตรวจอะไร:** ชื่อ/label ทุกจุดตรงกับ MOM/REQ ไม่เปลี่ยนเอง

**วิธีตรวจ:**
- ✅ ชื่อ field/label ตรงกับที่ MOM/REQ ใช้
- ✅ Status values ตรงกับที่กำหนด (เช่น "อนุมัติ" ไม่ใช่ "Approved" ถ้า MOM ใช้ภาษาไทย)
- ✅ Menu item / navigation ตรงกับ terminology ใน REQ
- ✅ Error message ใช้คำที่ user เข้าใจ (ไม่ใช่ technical term)

**PASS เมื่อ:** ทุก label/term ตรงกับ MOM/REQ
**FAIL เมื่อ:** มี label ที่ใช้คำต่างจาก MOM/REQ → ระบุจุดที่ไม่ตรง

---

## 10. No Gold Plating

**ตรวจอะไร:** ไม่มี feature/element ที่ MOM/REQ ไม่ได้ระบุ

**วิธีตรวจ:**
- ✅ ทุก element ใน wireframe trace กลับไป MOM/REQ ได้
- ✅ ไม่มี "nice-to-have" ที่ AI เพิ่มเอง
- ✅ ไม่มี feature จาก phase อื่นปนเข้ามา

**PASS เมื่อ:** ทุก element มีที่มาจาก MOM/REQ
**FAIL เมื่อ:** มี element ที่ trace ไม่ได้ → ระบุจุด + ลบออก หรือถามผู้ใช้

---

## 11. Consistency

**ตรวจอะไร:** style, spacing, color ตรงกับ wireframe หน้าอื่นใน project

**วิธีตรวจ:**
- ✅ สี/theme ตรงกัน (ถ้ามี design system / shared layout)
- ✅ Spacing/padding ใช้ pattern เดียวกัน
- ✅ Component style เหมือนกัน (ปุ่ม, table, form ที่ใช้ซ้ำ)
- ✅ Typography (font size, weight) ตรงกับหน้าอื่น
- ✅ Icon style เดียวกัน (outline vs filled, ขนาด)

**PASS เมื่อ:** style ตรงกับ wireframe อื่นใน project — ดูเป็นระบบเดียวกัน
**FAIL เมื่อ:** มี element ที่ style ไม่ตรง → ระบุจุด + แก้ให้ตรง
**N/A เมื่อ:** เป็น wireframe แรกของ project (ยังไม่มีอะไรเทียบ)

---

## 12. Reference Cited

**ตรวจอะไร:** wireframe มี comment อ้างอิง Refero reference ที่ใช้

**วิธีตรวจ:**
- ✅ มี HTML comment หรือ annotation ระบุ reference sources
- ✅ ระบุว่า pattern ไหนมาจาก product ไหน
- ✅ ถ้าไม่ได้ใช้ Refero → annotate ว่า "No Refero reference available" + เหตุผล

**PASS เมื่อ:** มีอย่างน้อย 3 references cited ใน wireframe header
**FAIL เมื่อ:** ไม่มี reference cited → เพิ่ม comment อ้างอิง

---

## Summary Format

หลังตรวจเสร็จ สรุปผลในรูปแบบนี้:

```markdown
## Wireframe Review: [Filename]

| # | หมวด | ผล | หมายเหตุ |
|---|------|-----|---------|
| 1 | Requirement Coverage | ✅ PASS | ครบ 8/8 features |
| 2 | User Flow Alignment | ✅ PASS | ตรงกับ UseF-01 |
| 3 | All States | ⚠️ FAIL | ขาด Empty State |
| ... | ... | ... | ... |

**Overall: X/12 PASS** → [PASS ✅ / FAIL ❌]
```

ถ้า FAIL → ระบุ action items ให้แก้ไข ก่อน deliver

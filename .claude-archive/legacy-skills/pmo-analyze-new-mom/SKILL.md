---
name: Analyze New MOM
description: อ่าน MOM ใหม่ → เทียบ REQ + MOM เก่า → สรุป Impact Report → log Traceability Matrix
---

# PMO Skill: Analyze New MOM

> **Related Skills:**
> - Load `pmo-traceability` for Traceability Matrix format
> - Load `pmo-activity-diagram` if impacted diagrams need updating

---

## Goal

เมื่อผู้ใช้ให้ MOM file ใหม่ → อ่าน วิเคราะห์ สรุป Impact Report พร้อม log การเปลี่ยนแปลงทั้งหมดให้อัตโนมัติ **ก่อนที่จะแก้ไข output ใดๆ ต้องรอผู้ใช้ approve**

---

## Workflow

### Step 1: ระบุ Project และอ่าน MOM ใหม่
- ถามผู้ใช้ว่า MOM นี้เป็นของ project ไหน (ถ้าไม่ระบุ)
- อ่าน MOM file ใหม่ทั้งหมด
- ระบุ MOM# ตามลำดับวันที่ (MOM ใหม่สุด = เลขสูงสุด)

### Step 2: อ่าน Context ที่มีอยู่
- อ่าน REQ/ ทั้งหมดของ project
- อ่าน MOM/ เก่าทั้งหมด (เพื่อเทียบ)
- อ่าน Transcription/ (ถ้ามี paired กับ MOM ใหม่)
- Scan SystemFlow/, UserFlow/, UseCase/ ที่มีอยู่

### Step 3: วิเคราะห์และเทียบ
- เทียบ MOM ใหม่กับ MOM เก่า → หาจุดที่เปลี่ยนแปลง/ขัดแย้ง
- เทียบ MOM ใหม่กับ REQ → หา requirement ใหม่ / ที่หายไป / ที่เปลี่ยน
- ตรวจ terminology → มีคำศัพท์ที่เปลี่ยนจากเดิมไหม
- ตรวจ scope/phase → มี feature ที่ย้าย phase ไหม

### Step 4: ตรวจจับความเสี่ยง
- ตรวจ business logic ที่มีความเสี่ยง (Fraud, Logic Broken, Missing Validation, Financial Risk)
- ถ้าพบ → ระบุในรายงาน พร้อม mitigation

### Step 5: สรุป Impact Report ให้ผู้ใช้

**Output Format:**

```markdown
# Impact Report: [MOM ชื่อไฟล์]
**Project:** P{XX}-{CODE} | **MOM#:** {N} | **วันที่:** YYYY-MM-DD

## สรุปสิ่งที่เปลี่ยนแปลง
- [สรุป 3-5 ข้อหลัก]

## ผลกระทบต่อไฟล์ที่มีอยู่
| ไฟล์ | ผลกระทบ | รายละเอียด |
|------|---------|-----------|

## ความเสี่ยงที่พบ (ถ้ามี)
| ประเภท | รายละเอียด | Mitigation |
|--------|-----------|-----------|

## Terminology ที่เปลี่ยน (ถ้ามี)
| คำเดิม | คำใหม่ | ไฟล์ที่ต้อง update |
|--------|-------|------------------|

## สิ่งที่แนะนำให้ทำ
1. [action items]

**รอผู้ใช้ตัดสินใจก่อนดำเนินการ**
```

### Step 6: Log Traceability Matrix
- บันทึกลง `SystemFlow/REQ_Traceability_Matrix.md` Change Log table ทันที
- ถ้ามี decision/กฎสำคัญ → update `CLAUDE.md` section "Project-Specific Decisions"

### Step 7: รอคำสั่งจากผู้ใช้
- **ห้ามแก้ไข diagram/output ใดๆ จนกว่าผู้ใช้จะ approve**
- เมื่อ approve แล้ว → โหลด skill ที่เกี่ยวข้องเพื่อ update output

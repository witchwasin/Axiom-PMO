# Workflow Discovery Checklist

> ใช้ checklist นี้เมื่อเข้า project ใหม่ หรือเมื่อได้รับ MOM/REQ ใหม่

## ค้นหาจาก PMO Documents

- [ ] อ่าน REQ ทุกข้อ — แต่ละ feature = potential workflow
- [ ] อ่าน MOM ทุกฉบับ — หา business rule, exception case
- [ ] อ่าน Transcription — หา requirement ที่ MOM ตกหล่น
- [ ] อ่าน WBS (ถ้ามี) — หา task ที่ imply workflow ที่ยังไม่ได้ spec
- [ ] อ่าน Mockup/Wireframe (ถ้ามี) — ทุกปุ่มกด = potential trigger
- [ ] อ่าน Gap Analysis (ถ้ามี) — gap = missing workflow

## คำถามที่ต้องถามทุก Workflow

| คำถาม | ทำไมสำคัญ |
|-------|----------|
| อะไร **trigger** flow นี้? | กำหนด entry point |
| **ใครทำ** แต่ละ step? | กำหนด actors/swimlanes |
| อะไรเกิดขึ้นถ้า **timeout**? | หา failure mode |
| อะไรเกิดขึ้นถ้า **ข้อมูลผิด**? | หา validation requirement |
| อะไร **สร้างขึ้นมา** ระหว่าง flow? | ใช้ทำ cleanup inventory |
| **ใครรับผิดชอบ** ถ้าพัง? | กำหนด recovery owner |
| ลูกค้า **เห็นอะไร** ระหว่างรอ? | กำหนด UX state |

## ค้นหา Implicit Workflows (Flow ที่ซ่อนอยู่)

สิ่งที่มักถูกลืม:

| ประเภท | ตัวอย่าง |
|--------|---------|
| **Onboarding** | ลูกค้าสมัครครั้งแรก → verify → activate |
| **Error Recovery** | Payment fail → retry → refund → notify |
| **Admin Override** | Admin แก้ไขข้อมูลที่ user ไม่สามารถแก้ได้ |
| **Notification** | Event เกิดขึ้น → แจ้ง user/admin ผ่าน channel ไหน |
| **Data Sync** | ข้อมูลเปลี่ยนที่ A → ต้อง sync ไป B |
| **Scheduled Jobs** | สิ่งที่ต้องทำอัตโนมัติทุกวัน/ชั่วโมง |
| **Deactivation** | ลบ account / ปิดระบบ / expire |

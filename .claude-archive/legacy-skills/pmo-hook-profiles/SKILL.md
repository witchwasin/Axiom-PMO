---
name: Hook Profiles — Performance Tuning
description: ปรับระดับ hook enforcement (minimal/standard/strict) ตามประเภทงาน — งานเร็วใช้ minimal, งาน deploy ใช้ strict
---

# Hook Profiles — Performance Tuning

> ไม่ใช่ทุกงานต้อง validate เท่ากัน — ปรับ hook intensity ตามประเภทงาน

## เมื่อไหร่ใช้

- Hook ทำให้งานช้าเกินไป → ลดเป็น minimal
- งาน deploy/release → เปิด strict ให้เช็คทุกอย่าง
- ต้องการ debug hook ทีละตัว → disable เฉพาะตัว
- เริ่ม session ใหม่ ต้องการกำหนด profile

## Profile Definitions

### `minimal` — Essential Only
**ใช้เมื่อ:** งาน quick fix, exploration, research, draft ร่างแรก

| Hook | Status | เหตุผล |
|------|--------|--------|
| Keyword Detector | ✅ ON | จำเป็น — route ไปหา skill |
| Phase Gate | ❌ OFF | ไม่จำเป็นสำหรับงานเล็ก |
| Quality Pre-Gate | ❌ OFF | ไม่จำเป็นสำหรับ exploration |
| Quality Post-Gate | ❌ OFF | ไม่ validate output |
| Cost Tracking | ✅ ON | เบามาก — เก็บ log เฉยๆ |
| Session End | ✅ ON | จำเป็น — save state |

**ผลลัพธ์:** เร็วที่สุด, 3/6 hooks active

### `standard` — Balanced (Default)
**ใช้เมื่อ:** งานทั่วไป — สร้าง diagram, implement feature, review

| Hook | Status | เหตุผล |
|------|--------|--------|
| Keyword Detector | ✅ ON | Route to skill |
| Phase Gate | ✅ ON | ป้องกันข้าม step |
| Quality Pre-Gate | ✅ ON | ตรวจ source files |
| Quality Post-Gate | ✅ ON | Validate output |
| Cost Tracking | ✅ ON | Log costs |
| Session End | ✅ ON | Save state |

**ผลลัพธ์:** สมดุล, 6/6 hooks active

### `strict` — Maximum Validation
**ใช้เมื่อ:** deploy, release, security audit, client delivery, phase gate review

| Hook | Status | เหตุผล |
|------|--------|--------|
| Keyword Detector | ✅ ON | Route to skill |
| Phase Gate | ✅ ON + **enhanced** | ตรวจ prerequisites + evidence |
| Quality Pre-Gate | ✅ ON + **enhanced** | ตรวจ source files + dependencies |
| Quality Post-Gate | ✅ ON + **enhanced** | Validate + score + evidence collection |
| Cost Tracking | ✅ ON | Log costs |
| Session End | ✅ ON + **enhanced** | Save state + generate session summary |
| **Evidence Check** | ✅ ON (เพิ่มใหม่) | ตรวจ evidence ก่อนเปลี่ยน card status |
| **Sensitive File Scan** | ✅ ON (เพิ่มใหม่) | Scan ทุก file operation สำหรับ secrets |

**ผลลัพธ์:** เข้มงวดที่สุด, 8/8 hooks active + enhanced mode

## วิธีใช้

### ตั้ง Profile

บอก Claude โดยตรง:

```
"ใช้ hook profile minimal"
"Set hook profile to strict"
"ปรับเป็น standard"
```

### Auto-Detection

ถ้าไม่ได้กำหนด — ระบบจะ auto-detect:

| Context | Auto Profile |
|---------|-------------|
| คำว่า "quick", "draft", "ลองดู", "explore" | `minimal` |
| งานทั่วไป (default) | `standard` |
| คำว่า "deploy", "release", "security", "client", "production", "go-live" | `strict` |
| Phase gate review | `strict` (auto) |
| Handoff to client | `strict` (auto) |

### Disable เฉพาะ Hook

```
"ปิด Quality Post-Gate hook"
"Disable phase gate สำหรับ session นี้"
```

### State Management

Profile state เก็บใน session state:

```json
{
  "hookProfile": "standard",
  "disabledHooks": [],
  "profileSetBy": "auto|user",
  "profileReason": "default / user requested / auto-detected from 'deploy'"
}
```

## Profile × Skill Matrix

บาง skill บังคับ profile เมื่อเรียกใช้:

| Skill | Minimum Profile | เหตุผล |
|-------|----------------|--------|
| `pmo-deploy-checklist` | `strict` | Deploy ต้องเช็คทุกอย่าง |
| `pmo-security-scan` | `strict` | Security ต้องเข้มงวด |
| `pmo-phase-gate-eval` | `strict` | Phase gate ต้องครบ |
| `pmo-verification-evidence` | `standard` | Evidence ต้อง validate |
| `pmo-blueprint` | `standard` | Plan ต้องผ่าน review |
| `pmo-deep-interview` | `minimal` OK | Research/exploration |
| `pmo-gap-analysis` | `standard` | Analysis ต้อง validate |

## Enhanced Mode (strict profile)

เมื่อ hook อยู่ใน strict mode, behavior เปลี่ยน:

### Phase Gate (Enhanced)
- ตรวจ prerequisites **ทั้ง hard + soft requirements**
- ต้องมี Evidence Record ก่อนเปลี่ยน phase
- Log ทุก gate check result

### Quality Post-Gate (Enhanced)
- คะแนน threshold สูงขึ้น: PASS ≥ 0.85 (ปกติ ≥ 0.8)
- ตรวจ MOM reference ทุก element
- Auto-generate Evidence Record จาก validation result

### Session End (Enhanced)
- Generate session summary report
- บันทึก decisions ที่เกิดขึ้นใน session
- อัพเดท Blueprint progress (ถ้ามี active blueprint)

## Integration

- **pmo-state-engine**: เก็บ/อ่าน profile state
- **pmo-verification-evidence**: strict profile auto-trigger evidence collection
- **pmo-quality-gate**: enhanced mode ปรับ threshold + behavior
- **settings.json**: profile ไม่ได้เปลี่ยน settings.json — ทำงานที่ behavioral level

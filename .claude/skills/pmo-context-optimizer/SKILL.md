---
name: Context Optimizer — Token Management
description: จัดการ context window ให้ไม่เต็ม — auto-compact เมื่อใกล้ limit, ลบ tool result เก่า, สรุป conversation history, รักษาข้อมูลสำคัญ
---

# Context Optimizer — Token & Context Management

> ป้องกัน context window เต็มก่อนงานจะเสร็จ — auto-detect, compact, และ prioritize ข้อมูลสำคัญ

## เมื่อไหร่ใช้

- Session ยาว (>20 tool calls)
- โปรเจคมี traceability + state + audit trail ขนาดใหญ่
- ต้อง read ไฟล์จำนวนมากใน 1 session
- User บอก "context เต็ม" หรือ "คำตอบสั้นลง"
- ก่อนเริ่มงานใหญ่ที่ต้องใช้ context เยอะ

## Core Strategies

### Strategy 1: Tool Result Compaction

เมื่ออ่าน file ไปแล้ว ผลลัพธ์ tool_result จะกิน context — compact ได้:

**Compactable tool results** (ลบได้หลังใช้):
- `Read` — เนื้อหาไฟล์ที่อ่านไปแล้ว (เก็บแค่ path + สรุป)
- `Bash` — output ของ command (เก็บแค่ exit code + สรุป)
- `Grep` — ผลค้นหา (เก็บแค่จำนวน match + key findings)
- `Glob` — รายชื่อไฟล์ (เก็บแค่จำนวน + pattern)

**Non-compactable** (ห้ามลบ):
- Decision Log entries
- User instructions
- Error messages ที่ยังไม่ได้แก้
- Current task context

**วิธี compact:**
```
[เดิม] Read /path/to/large-file.md → {2000 lines of content}
[compact] Read /path/to/large-file.md → [File read: 2000 lines, key: {3-line summary}]
```

### Strategy 2: Conversation Summary

เมื่อ conversation ยาว — สรุปส่วนเก่า:

1. **Identify segments:** แบ่ง conversation เป็น task segments
2. **Summarize completed tasks:** task ที่เสร็จแล้ว → สรุป 2-3 บรรทัด
3. **Keep active context:** task ปัจจุบัน + ข้อมูลที่เกี่ยวข้อง → เก็บ full
4. **Preserve decisions:** ทุก decision ที่ user ตัดสินใจ → เก็บ full

### Strategy 3: Smart File Reading

ก่อน read file — ประเมินว่าจำเป็นแค่ไหน:

| Situation | Action |
|-----------|--------|
| ต้องการแค่ structure | อ่าน 50 บรรทัดแรก |
| ต้องการ specific section | ใช้ Grep หา แล้ว Read เฉพาะ offset |
| ไฟล์ใหญ่ (>500 lines) | อ่านเป็น chunk, สรุปแต่ละ chunk |
| ไฟล์ที่อ่านแล้วใน session นี้ | ใช้ summary จากครั้งก่อน |

### Strategy 4: Priority-Based Context Retention

เมื่อต้อง compact — เรียงลำดับความสำคัญ:

```
Priority 1 (ห้ามลบ):
  - Current task instructions
  - User decisions (ทุก decision ที่ user ตัดสินใจ)
  - Active error context
  - Project state (phase, status)

Priority 2 (สรุปได้):
  - Completed task details → summary
  - File contents read → path + key findings
  - Command outputs → exit code + summary

Priority 3 (ลบได้):
  - Exploration results ที่ไม่เกี่ยวกับ task ปัจจุบัน
  - Duplicate reads (อ่านไฟล์เดิมซ้ำ)
  - Verbose command output (ls, git log ยาวๆ)
```

## Token Budget Awareness

### Estimation Rules
- **Text:** ~4 bytes ต่อ token (ภาษาอังกฤษ), ~2 bytes ต่อ token (JSON/code)
- **Thai text:** ~2-3 bytes ต่อ token
- **Safe margin:** เก็บ 15-20% ของ context window ว่างเสมอ

### Monitoring Triggers

| Context Usage | Action |
|--------------|--------|
| **<60%** | ทำงานปกติ |
| **60-75%** | เริ่ม compact tool results เก่า |
| **75-85%** | Summarize completed tasks + compact aggressively |
| **85-95%** | แนะนำ `/compact` + เก็บเฉพาะ Priority 1 |
| **>95%** | Emergency: สรุปทุกอย่างเป็น summary, แจ้ง user |

### Session Planning

ก่อนเริ่มงานใหญ่ — ประเมิน token budget:

```markdown
## Token Budget Estimate
- Current usage: ~{X}% of context window
- Available for this task: ~{Y} tokens
- Estimated task cost:
  - File reads: {N} files × ~{avg} tokens = {total}
  - Tool calls: {N} calls × ~{avg} tokens = {total}
  - Output generation: ~{X} tokens
- **Verdict:** {sufficient / tight / insufficient — need compact first}
```

## Auto-Compact Protocol

เมื่อ system ตรวจพบ context ใกล้เต็ม:

1. **Detect:** Monitor token usage ต่อ turn
2. **Warn:** แจ้ง user เมื่อถึง 75%
3. **Suggest:** แนะนำ `/compact` เมื่อถึง 85%
4. **Emergency:** ถ้า 95%+ — auto-summarize ส่วนเก่าทันที

## Best Practices สำหรับ PMO

1. **อ่านไฟล์ให้น้อยที่สุด** — ใช้ Grep ก่อน Read เสมอ
2. **อย่า read ทั้งไฟล์** — ใช้ offset + limit
3. **สรุป state จาก state-engine** แทนการ read audit-trail.jsonl ทั้ง file
4. **Blueprint plan** ช่วยแบ่งงาน — ไม่ต้องทำทุกอย่างใน session เดียว
5. **Traceability query** — อ่านเฉพาะ section ที่ต้องการ (Activity/Decision/Change)
6. **TaskBoard** — อ่านเฉพาะ card ที่เกี่ยวข้อง ไม่ต้องอ่านทั้ง board

## Integration

- **pmo-state-engine**: อ่าน state summary แทน full state file
- **pmo-blueprint**: ใช้ blueprint แบ่งงานข้าม session เพื่อลด context per session
- **pmo-traceability**: Query เฉพาะ section ที่ต้องการ
- **Cost Tracking Hook**: ใช้ cost data ประเมิน token usage pattern

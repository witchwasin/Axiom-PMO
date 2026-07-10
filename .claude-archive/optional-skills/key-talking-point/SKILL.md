---
name: key-talking-point
description: >
  Create color-coded teaching scripts / presenter talking-point documents (.md) that serve as a "live reading book" for speakers.
  The output is a markdown file where each color tells the presenter what to do: blue = speak this line, red = pronunciation guide,
  dark blue = slide header, black = stage direction & audience engagement, yellow box = terminology.
  Use this skill whenever the user mentions: teaching script, talking points, presenter script, key talking point,
  speaker notes, lecture script, training script, presentation script, สคริปต์การสอน, สคริปต์วิทยากร,
  คำพูดที่ต้องอ่าน, หนังสือสำหรับพูด, or any request to create a document that guides a speaker through a slide deck
  with exact words to say, pronunciation help, and stage directions.
  Also trigger when the user uploads a PowerPoint (.pptx) and asks to write a script, narration, or talking points for it.
---

# Key Talking Point — Color-Coded Presenter Script

## What This Skill Produces

A single `.md` file that acts as the presenter's "live reading book." When rendered (e.g. in VS Code preview, Obsidian, or a browser), each color instantly tells the speaker what to do — no guesswork on stage.

The document is designed so that a presenter can literally hold it (on a tablet or printed) and know at a glance: what to say, how to pronounce technical terms, when to pause, when to engage the audience, and what teaching technique to use.

## Color System

There are exactly 4 visual channels. Never invent new colors.

| Color | Hex | Purpose | Markdown Pattern |
|-------|-----|---------|-----------------|
| Blue | `#1565C0` | **Speech lines** — exact words the presenter reads aloud | `<span style="color:#1565C0">**text**</span>` |
| Red | `#C62828` | **Pronunciation guide** — phonetic reading of English terms | `<span style="color:#C62828">**(pronunciation)**</span>` |
| Dark blue | `#1A237E` | **Slide headers** — section titles, slide numbers, time codes | `<span style="color:#1A237E">**text**</span>` |
| Black | (no span) | **Stage directions & engagement** — actions, pauses, audience questions | Plain text, no color span |

Additionally:
- `> 💡 *text*` = Teaching technique tip (italic, blockquote)
- Yellow terminology box = `<div style="border-left: 4px solid #FFB300; background-color: #FFF8E1; padding: 10px; margin: 10px 0;">` for key vocabulary groups

## Critical Formatting Rules

These rules exist because even a single formatting error breaks the color rendering in markdown viewers, and the whole point of this document is that colors work perfectly.

### Bold spacing — the #1 source of bugs

The bold markers `**` must touch the text directly. A space between `**` and the first/last character makes the bold (and therefore the color) fail to render.

```
CORRECT:  <span style="color:#1565C0">**สวัสดีครับ**</span>
WRONG:    <span style="color:#1565C0">** สวัสดีครับ**</span>
WRONG:    <span style="color:#1565C0">**สวัสดีครับ **</span>
```

### Pronunciation pattern

When an English term appears in a speech line, split the span so the pronunciation sits between two blue spans:

```
<span style="color:#1565C0">**เทคโนโลยี AI**</span> <span style="color:#C62828">**(เอไอ)**</span> <span style="color:#1565C0">**ช่วยให้ทำนายได้**</span>
```

The red span always:
- Starts with `**(`
- Ends with `)**`
- Contains Thai phonetic transcription of the English term
- Has a space before and after the span (separating it from blue spans)

### Which terms need pronunciation?

Add pronunciation for English technical terms that are medium-to-hard difficulty for a Thai-speaking audience. Use your judgment:

- **Always add**: Multi-syllable technical terms (Servitization, Predictive Maintenance, Horizontal Integration, Sustainability, Resilience), acronyms on first use (SCADA, MES, ERP, OEE), brand/product names (Omniverse, EcoStruxure)
- **Skip**: Very common terms most Thai speakers know (AI, IT, WiFi, Email, Excel, PowerPoint), single-syllable words (Cloud, Smart, Flow), Thai transliterations already standard (ดิจิทัล, เทคโนโลยี)

### Slide header format

Every slide gets a header like this:

```
### <span style="color:#1A237E">**สไลด์ 12 — Topic Name `[3 นาที]`**</span>
```

- Use `###` (h3)
- Slide number + em dash + topic name + time allocation in backtick brackets
- Time allocation is the suggested speaking time for that slide

### Section divider format

```
## <span style="color:#1A237E">**ช่วงที่ 2: Session Title**</span>
### <span style="color:#1A237E">**09:10–10:30 | 80 นาที**</span>
```

### Stage directions (black text)

Stage directions are plain text (no color span) and describe physical actions, tone changes, or timing:

```
*หยุดสักครู่ ให้ผู้ฟังคิด*
*เปลี่ยนน้ำเสียง จริงจัง*
*ยิ้ม สบตาผู้ฟัง*
```

Use italics for brief directions. For longer directions, plain text is fine.

### Audience engagement (black text)

Engagement prompts are in black (no color span) to distinguish from main content. They include:

```
ถามผู้ฟัง: "ท่านไหนเคยเจอปัญหานี้บ้างครับ?"
Check-in: "จุดนี้สำคัญมากนะครับ จำไว้เลย"
```

Types of engagement:
- **ถามผู้ฟัง** — Direct question to audience
- **Check-in** — Quick comprehension/attention check
- **กิจกรรม** — Interactive activity (hand raising, think-pair-share)
- **ลองนึก/ลองคิด** — Think-along prompt

### Teaching technique tips

```
> 💡 *เปรียบ Dashboard กับ Google Maps ซูมเข้า ผู้ฟังเข้าใจทันที*
```

These are notes for the presenter about WHY a technique works — not spoken aloud.

### Terminology boxes

For introducing a cluster of related vocabulary:

```html
<div style="border-left: 4px solid #FFB300; background-color: #FFF8E1; padding: 10px; margin: 10px 0;">

**คำศัพท์สำคัญ:**
- **Horizontal Integration** <span style="color:#C62828">**(ฮอริซอนทัล อินทิเกรชั่น)**</span> — การเชื่อมข้อมูลแนวราบ
- **Vertical Integration** <span style="color:#C62828">**(เวอร์ทิคัล อินทิเกรชั่น)**</span> — การเชื่อมข้อมูลแนวดิ่ง

</div>
```

## Content Density

A 3-hour training session needs substantial content per slide. The target speaking pace for Thai is roughly **130 words per minute**, so:

| Allocated time | Target word count (Thai speech lines only) |
|----------------|-------------------------------------------|
| 1 minute | ~130 words |
| 2 minutes | ~260 words |
| 3 minutes | ~390 words |
| 5 minutes | ~650 words |

Every slide MUST have enough blue speech content to fill its allocated time. A 3-minute slide with only 2 sentences is a critical error — the presenter will finish in 15 seconds and stand there with nothing to say.

To fill time naturally:
- **Explain with analogies** — "เหมือนกับ..." comparisons to everyday things
- **Give concrete examples** — Real company names, real numbers, real outcomes
- **Build step by step** — Don't just state a fact; walk through the logic
- **Add context** — Why does this matter? What was it like before? What changed?

## Engagement Frequency

For a 3-hour session, aim for engagement every 3-5 minutes. This means roughly:
- 25-35 engagement moments total
- At least 1 per slide for content slides
- Mix of types (questions, activities, think-alongs, check-ins)

Engagement keeps the audience alert during long sessions. Without it, attention drops sharply after 10-15 minutes.

## Document Structure

```
# Title with span color:#1A237E
*Subtitle / course name*
*Instructor info*
*Date and duration*

---

### คำแนะนำการอ่าน Script:
(color legend — always include this)

---

## Section Divider (color:#1A237E)
### Time range

---

### Slide N — Topic [time] (color:#1A237E)

(stage direction in black)
(blue speech lines with red pronunciations)
(engagement in black)
(blue speech lines continue)
(teaching tip 💡)

---

(repeat for all slides)

---

## หมายเหตุสำหรับวิทยากร
(timing summary table)
(tips for the presenter)
```

## Workflow

1. **Gather inputs**: Get the slide deck (.pptx) or slide list, session duration, instructor info, date
2. **Analyze slides**: Understand the topic flow, identify technical terms, calculate time per slide
3. **Write the script**: Go slide by slide, expanding each into full speech with pronunciations and engagement
4. **Self-check before delivering**:
   - Bold spacing: zero instances of `** text` or `text **` inside spans
   - All slides accounted for (check slide numbers sequentially)
   - Pronunciation guides on all medium-hard English terms
   - Content density meets the word count targets
   - Engagement moments every 3-5 minutes
   - Color spans use exact hex codes (#1565C0, #C62828, #1A237E)
5. **Output**: Single `.md` file

## Language Notes

- Speech lines should sound like natural Thai speaking — conversational, not written-style
- Use ครับ/ค่ะ appropriately based on the instructor's gender (ask if unknown)
- Avoid stiff AI-sounding phrases; write as if a real instructor is talking to a live audience
- Numbers and statistics should be spoken naturally ("สามสิบเปอร์เซ็นต์" not "30%")
- For the reading guide section at the top, see `references/reading-guide-template.md`

## Reference Files

- `references/reading-guide-template.md` — The standard color legend block to paste at the top of every script
- `references/format-example.md` — A short example showing 3 slides in correct format (use as a sanity check)

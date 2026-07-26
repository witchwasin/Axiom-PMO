<!-- ppt-master-schema: design-spec/v1 -->
# Axiom-PMO Overview - Design Spec

## I. Project Information

| Item | Value |
| --- | --- |
| Project Name | Axiom-PMO Overview — หลักการทำงาน |
| Canvas Format | PPT 16:9, 1280×720 |
| Page Count | 15 |
| Target Audience | ทีมส่งมอบภายใน (PM / Dev / QA) ที่คุ้นเคยกับ software delivery แต่ยังไม่รู้จัก AI governance และผู้บริหาร/ลูกค้าที่ฟังในรอบเดียวกัน — ผู้ฟังผสม ต้องเริ่มจากภาพรวมแล้วค่อยลึก |
| Communication Intent | อธิบายกลไกของ Axiom-PMO ให้เห็นเหตุผลเป็นหลัก แล้วสอนให้ทีมนำไปใช้ต่อได้ พร้อมโน้มน้าวกลาย ๆ ว่าทำไม prompt อย่างเดียวไม่พอ — ลำดับคือ อธิบาย → สอน → โน้มน้าว |
| Desired Audience Outcome | ผู้ฟังอธิบายได้เองว่าทำไม "prompt ไม่ใช่ control" ไล่ชื่อ 4 หลักการได้ และบอกลำดับ gate `Draft → Scope → Design → Handoff → Release` พร้อมคำถามประจำแต่ละ gate ได้ |
| Core Message / Ask / Action | AI เขียนโค้ดได้ แต่ต้องไม่กุโปรเจกต์ขึ้นมาเอง — Axiom-PMO เปลี่ยนกฎที่เป็นแค่ข้อความ ให้กลายเป็นสัญญาที่เครื่องตรวจสอบได้ |
| Delivery Context | Presenter-led เป็นหลัก มีผู้พูดประกอบทุกหน้า; afterlife รองเป็น reader-led ให้คนที่ไม่ได้ฟังเปิดอ่านย้อนได้ผ่าน speaker notes |
| Artifact Afterlife | ใช้ส่งต่อและ onboarding ทีมใหม่ เป็นเอกสารอ้างอิงหลักการของ framework |
| Reading Mode | balanced |
| Content Strategy | สมดุล — จัดโครงเรื่องใหม่ให้ผู้ฟังผสมเข้าใจง่าย กลั่นข้อความใหม่ได้ แต่ข้อเท็จจริง ตัวเลข และคำพูดอ้างอิงทุกจุดมาจาก repo ทั้งหมด ไม่เติมข้อมูลนอกแหล่ง |
| Design Style | swiss-minimal — grid เข้ม พื้นขาว ตัวหนังสือเป็นตัวนำ accent เดียวสีแดงส้ม ไม่มีลูกเล่นตกแต่ง |
| Formula Policy | text-only |
| AI Image Acquisition Path | not applicable |
| Generation Mode | continuous |
| Spec Refinement | disabled |
| Created Date | 2026-07-26 |

## II. Canvas Specification

| Property | Value |
| --- | --- |
| Format | ppt169 |
| Dimensions | 1280 × 720 |
| viewBox | `0 0 1280 720` |
| Margins | 72px ซ้าย/ขวา, 56px บน/ล่าง |
| Content Area | 1136 × 608 (x 72–1208, y 56–664) |

## III. Visual Theme

### Theme Style

- **Mode**: instructional
- **Visual style**: swiss-minimal
- **Theme**: เอกสารวิศวกรรมที่อ่านง่าย — หน้าขาวสะอาด เส้น hairline คั่นโครงสร้าง ตัวหนังสือเรียงบน grid ที่มองเห็นได้ ไม่มีการ์ดเงา ไม่มีไล่สี ทุกอย่างที่เห็นบนหน้าต้องมีหน้าที่
- **Tone**: ตรงไปตรงมา มั่นใจ ไม่ขายของ — น้ำเสียงเดียวกับ repo ที่ยอมรับข้อจำกัดของตัวเองอย่างเปิดเผย

### Color Scheme

| Role | HEX | Purpose |
| --- | --- | --- |
| Background | #FFFFFF | พื้นหน้าหลักทุกหน้า |
| Secondary background | #F2F1ED | แถบพื้นรองสำหรับบล็อกอ้างอิง ตารางสลับแถว และโซนแยกเนื้อหา |
| Primary | #14161A | หัวข้อ ตัวเลขเด่น เส้นโครงสร้างหนัก |
| Accent | #D6360B | สีของ "สิ่งที่บล็อก" — FAIL, blocker, ข้อความที่ต้องหยุดอ่าน, เลขหน้าที่กำลังพูดถึง |
| Secondary accent | #2E6B5E | สีของ "ผ่านแล้ว" — PASS, verified, สถานะที่มีหลักฐานรองรับ |
| Body text | #3A3F45 | เนื้อความปกติทั้งหมด |
| Warning | #B36A00 | WARN และสถานะกึ่งกลางอย่าง inferred / accepted_risk |
| Surface | #FAFAF8 | พื้นบล็อกยกระดับบาง ๆ ใต้ตารางและ diagram |
| Grid | #DEDDD8 | เส้น hairline คั่นและเส้น grid ทั้งหมด |

## IV. Typography System

### Font Plan

| Role | Chinese | English | Fallback tail |
| --- | --- | --- | --- |
| Title | Tahoma | Tahoma | Arial, sans-serif |
| Body | Tahoma | Tahoma | Arial, sans-serif |
| Data | Consolas | Consolas | Courier New, monospace |

- **Title stack**: Tahoma, Arial, sans-serif
- **Body stack**: Tahoma, Arial, sans-serif
- **Data stack**: Consolas, Courier New, monospace
- **Role rationale**: เพิ่มบทบาท `Data` เป็น Consolas เพราะเด็คมีบล็อกผลลัพธ์จริงจาก validator และชื่อ rule ที่ต้องเรียงคอลัมน์ตรงกัน (P08, P11, P14, P15) ซึ่ง proportional font ทำให้อ่านผิดความหมาย — บล็อกเหล่านี้เป็นภาษาอังกฤษล้วน จึงไม่ต้องรองรับไทย ส่วน Title/Body ใช้ Tahoma ตระกูลเดียวแล้วเล่นน้ำหนักกับขนาดแทน ซึ่งเป็นวินัยแบบ swiss-minimal อยู่แล้ว และเป็นฟอนต์เดียวในกลุ่มที่ PowerPoint ติดตั้งมาให้ทั้ง Windows และ macOS พร้อมกลุ่มอักษรไทยครบ (Arial/Calibri/Segoe UI รองรับไทยไม่ครบ ส่วน Noto Sans Thai ไม่มีใน Windows มาตรฐาน จะ fallback เงียบ ๆ แล้วเลย์เอาต์พังบนเครื่องคนอื่น)
- **Thai script note**: ข้อความไทยทุกจุดต้องเผื่อความสูงบรรทัดมากกว่าละติน เพราะสระบน–ล่างและวรรณยุกต์ซ้อนกันได้สองชั้น — ใช้ระยะบรรทัดอย่างน้อย 1.55× ของขนาดตัวอักษรในย่อหน้าไทย และห้ามวางข้อความไทยชิดขอบกล่องบน/ล่าง

### Font Size Hierarchy

| Purpose | Anchor Size (px) |
| --- | ---: |
| Body | 24 |
| Title | 42 |
| Subtitle | 32 |
| Annotation | 18 |
| Hero | 84 |
| Lead | 30 |
| Footnote | 16 |
| Data | 18 |

## V. Layout Principles

### Page Structure

- **Header area**: เลขหน้าสองหลักและชื่อส่วน (Part) วางมุมบนซ้ายที่ระดับ y 56 ขนาด Annotation สีเทา ตามด้วยหัวข้อหน้าขนาด Title ใต้ลงมา คั่นด้วยเส้น hairline สี Grid เต็มความกว้าง content area — โครงนี้ซ้ำทุกหน้ายกเว้น P01
- **Content area**: ทำงานบน grid 12 คอลัมน์ ระยะห่างคอลัมน์ 24px ทุกบล็อกต้อง snap ขอบซ้าย/ขวาเข้าเส้นคอลัมน์ ความกว้างที่ใช้บ่อยคือ 12 (เต็ม), 8+4 (เนื้อหาหลัก+หมายเหตุ), 6+6 (เทียบคู่), 4+4+4 (สามเสา) — เลือกจากน้ำหนักข้อมูล ไม่ใช่จากความสวย
- **Footer area**: ชื่อเด็คและเวอร์ชัน `Axiom-PMO 1.1.1` มุมล่างขวาขนาด Footnote สี Grid ทุกหน้ายกเว้น P01 — ไม่มีโลโก้ ไม่มีวันที่

### Spacing Specification

| Element | Current Project |
| --- | --- |
| Safe margin | 72px ซ้าย/ขวา, 56px บน/ล่าง |
| Content block gap | 32px แนวตั้งระหว่างบล็อก, 24px ระหว่างคอลัมน์ |
| Icon-text gap | 12px |

## VI. Icon Usage Specification

- **Primary bundled library**: tabler-outline
- **Stroke Width**: 2

| Purpose | Icon Path | Page |
| --- | --- | --- |
| พฤติกรรมกุข้อมูลของ agent | tabler-outline/alert-triangle | P03 |
| ขอบเขตอำนาจที่ถูกข้าม | tabler-outline/lock-open | P03 |
| สัญญาที่เครื่องตรวจได้ | tabler-outline/shield-check | P04 |
| หลักฐานอ้างอิงแหล่งที่มา | tabler-outline/file-search | P06 |
| ระดับความเสี่ยง | tabler-outline/stack-2 | P07 |
| ด่านตรวจ | tabler-outline/git-branch | P08 |
| อำนาจของมนุษย์ | tabler-outline/user-check | P09 |
| ชั้นตรวจอัตโนมัติ | tabler-outline/binary-tree | P11 |
| ชั้นตรวจเชิงความหมาย | tabler-outline/eye-search | P11 |

## VII. Visualization Reference List

| Page | Template | Usage |
| --- | --- | --- |
| P08 | pipeline_with_stages | เรียงห้า gate เป็นสายเดียวพร้อมคำถามประจำด่าน |
| P12 | icon_grid | วางสิบสองเลนส์เป็นตารางคู่ขนานอ่านกวาดได้ |
| P13 | horizontal_bar_chart | เทียบน้ำหนักคะแนนเจ็ดมิติที่ชื่อยาว |

## VIII. Image Resource List

| Filename | Dimensions | Ratio | Purpose | Type | Layout pattern | Crop Policy | Acquire Via | Status | Reference | text_policy | page_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

## IX. Content Outline

### Part 1: ปัญหา — ทำไมต้องมี Axiom-PMO

#### Slide 01 - ปก

- **Audience move**: ยังไม่รู้ว่าเด็คนี้จะพูดเรื่องอะไร → รู้ทันทีว่าเป็นเรื่องการคุม AI agent ไม่ให้กุงานขึ้นมาเอง และรู้สึกว่าประโยคนี้ท้าทายพอจะฟังต่อ
- **Cover impact**: hook คือประโยคจาก README ที่ตัดสินทั้งเด็ค — "AI agents can write code. They should not invent the project." composition เป็น typographic poster: ตัวอังกฤษขนาด Hero กินพื้นที่สองในสามของหน้า ตัดคำเป็นสามบรรทัด คำว่า **should not** เป็นสี Accent เพียงจุดเดียวบนหน้า ที่เหลือเป็นพื้นขาวโล่ง มีเส้น hairline หนึ่งเส้นใต้ข้อความคั่นไปหาบรรทัดไทยและชื่อเวอร์ชัน — ไม่มีการ์ด ไม่มีสามคอลัมน์ ไม่มี agenda
- **Layout**: เต็มหน้าคอลัมน์เดียว ข้อความชิดซ้ายที่ margin 72px ยึดแนวตั้งค่อนไปทางบน เว้นล่างว่างมาก
- **Title**: AI agents can write code. They should not invent the project.
- **Core message**: เด็คนี้ว่าด้วยเส้นแบ่งระหว่าง "AI ทำงานให้ได้" กับ "AI ตัดสินใจแทนไม่ได้"
- **Content**: บรรทัดหลักภาษาอังกฤษขนาด Hero สามบรรทัด; ใต้เส้น hairline เป็นบรรทัดไทยขนาด Lead "AI เขียนโค้ดได้ แต่ต้องไม่กุโปรเจกต์ขึ้นมาเอง"; มุมล่างซ้ายบรรทัดเดียวขนาด Annotation "Axiom-PMO 1.1.1 — The Anti-Hallucination Framework for AI Agents / กรอบกำกับการทำงานของ AI Agent"

#### Slide 02 - คำถามที่เด็คนี้ตอบ

- **Audience move**: คิดว่านี่เป็นเรื่อง process เอกสารอีกชุด → เข้าใจว่าเป็นปัญหาความน่าเชื่อถือของงานที่ AI ส่งมา ซึ่งกระทบตัวเองโดยตรง
- **Layout**: หน้าหายใจ คอลัมน์เดียวกลางหน้า ข้อความน้อย เว้นขาวเยอะ — ตั้งใจให้จังหวะช้าลงก่อนเข้าเนื้อ
- **Title**: ปัญหาไม่ใช่ AI เขียนโค้ดไม่เป็น
- **Core message**: ปัญหาคือเราแยกไม่ออกว่าอะไรคือสิ่งที่ลูกค้าขอจริง กับอะไรคือสิ่งที่ AI คิดขึ้นเอง
- **Content**: ประโยคใหญ่ขนาด Subtitle สองบรรทัด "AI ส่งงานมาแล้ว — แต่คุณรู้ได้ยังไงว่าสิ่งที่มันทำ คือสิ่งที่ลูกค้าขอ?"; ใต้ลงมาสามบรรทัดสั้นขนาด Body เว้นระยะห่างกันมาก แต่ละบรรทัดขึ้นต้นด้วยเส้นขีดสั้นสี Accent — "requirement นี้มาจากไหน", "ใครอนุมัติ scope นี้", "ใครยืนยันว่าเทสต์ผ่าน"; บรรทัดปิดขนาด Annotation สีเทา "ถ้าตอบสามข้อนี้ไม่ได้ แปลว่ายังไม่มี governance"

#### Slide 03 - AI ที่ไม่ถูกคุมทำอะไรบ้าง

- **Audience move**: รู้สึกว่าปัญหายังลอย ๆ → เห็นพฤติกรรมห้าข้อที่จับต้องได้ และนึกออกว่าเคยเจอข้อไหนมาแล้วบ้าง
- **Layout**: คอลัมน์เดียวความกว้าง 10 คอลัมน์ ห้าแถวเรียงลง แต่ละแถวมีเลขลำดับสองหลักสี Grid ขนาดใหญ่ทางซ้าย คั่นแต่ละแถวด้วยเส้น hairline — เป็นรายการที่อ่านไล่ลง ไม่ใช่การ์ดกริด
- **Title**: AI ที่ไม่ถูกคุม จะทำห้าอย่างนี้เสมอ
- **Core message**: พฤติกรรมทั้งห้าไม่ใช่บั๊ก แต่เป็นสิ่งที่เกิดขึ้นตามธรรมชาติเมื่อไม่มีข้อจำกัด
- **Content**: ห้าแถว แต่ละแถวมีคำหลักภาษาอังกฤษตัวหนา + คำอธิบายไทยหนึ่งบรรทัด — **invent** กุ requirement, acceptance criteria, actor หรือการอนุมัติที่ไม่เคยมีใครให้; **silently expand scope** เติมฟีเจอร์ "ที่น่าจะดี" ซึ่งไม่มีใครขอ; **claim evidence** อ้างว่า "เทสต์ผ่าน" "QA อนุมัติแล้ว" ทั้งที่ตัวเองเป็นคนสร้างหลักฐานนั้น; **lose traceability** ทำให้สาวไม่ได้ว่าสิ่งที่ build มาจากคำขอข้อไหน; **cross authority boundaries** commit, push หรือ release โดยไม่มีมนุษย์คนไหนพูดว่าใช่; บรรทัดปิดขนาด Annotation "ทั้งห้าข้อนี้ AI ไม่ได้ตั้งใจโกหก — มันแค่เติมช่องว่างให้เต็ม"

#### Slide 04 - ทำไมการสั่งใน prompt ถึงไม่พอ

- **Audience move**: คิดว่าเขียน prompt ให้ดีกว่านี้ก็แก้ได้ → เข้าใจว่า prompt เป็นคำขอ ไม่ใช่กลไกบังคับ และเห็นเคสจริงที่พิสูจน์แล้ว
- **Layout**: แบ่ง 7+5 — ซ้ายเป็นข้อความหลักและประโยคอ้างอิง ขวาเป็นบล็อกเคสจริงบนพื้น Secondary background มีเส้นซ้ายหนา 4px สี Accent
- **Title**: prompt คือคำขอ ไม่ใช่ control
- **Core message**: กฎที่อยู่แค่ในข้อความ คือกฎที่ agent เลือกไม่ทำตามได้ และเคยไม่ทำตามมาแล้วจริง
- **Content**: ฝั่งซ้าย — ประโยคอ้างอิงขนาด Subtitle "A prompt that politely asks the agent not to do these things is not a control." ตามด้วยคำอธิบายไทยขนาด Body ว่า Axiom-PMO เปลี่ยนข้อห้ามแต่ละข้อให้เป็น machine-verifiable contract ที่มี validator คอย exit non-zero เมื่อสัญญาถูกละเมิด เหมือน linter ที่ทำให้ PR ไม่ผ่าน และปิดด้วยประโยค "Nothing is enforced by asking the agent nicely." เป็นตัวหนาสี Primary; ฝั่งขวา — หัวบล็อกขนาด Annotation สี Accent "เคสจริงที่ทำให้ framework นี้เกิด" ตามด้วยชื่อเคส "The Agent That Shipped Without Permission" และสรุปสามบรรทัด: agent commit และ push ขึ้น main เอง แก้ไปหลายร้อยไฟล์ โดยไม่มีใคร review diff; รายงานสถานะของตัวเองบอกว่า *ยังไม่ได้* commit หรือ push; สาเหตุราก — "The boundary lived only in prose."

### Part 2: ภาพรวมสถาปัตยกรรม

#### Slide 05 - Axiom-PMO อยู่ตรงไหนของงาน

- **Audience move**: ยังไม่เห็นว่าเครื่องมือนี้วางตัวยังไงกับของที่ทีมใช้อยู่ → เห็นว่ามันเป็นชั้นกำกับที่ครอบ execution framework ไม่ใช่ของที่มาแทน
- **Layout**: diagram แนวตั้งเต็มหน้า สี่บล็อกซ้อนลงมา เชื่อมด้วยลูกศรที่มี label กำกับ บล็อกกลางสองอันเป็นกรอบเส้นบนพื้น Surface ส่วนบล็อกบนสุดและล่างสุด (มนุษย์) เป็นพื้น Primary ตัวอักษรขาว — วนกลับเป็นวงปิด
- **Title**: Axiom-PMO เป็นชั้นกำกับ ไม่ใช่ชั้นลงมือ
- **Core message**: มันไม่แข่งกับ execution framework ที่ทีมใช้อยู่ แต่เป็นชั้นที่ framework เหล่านั้นทำงานอยู่ข้างใน
- **Visualization**: diagram เชิงโครงสร้าง วาดเองด้วย SVG ไม่ใช่ chart จากข้อมูล — ปรับจาก mermaid flowchart ใน README
- **Content**: บล็อก 1 (พื้นเข้ม) `Human / PM / Product Owner`; ลูกศรลง; บล็อก 2 `Axiom-PMO — Governance & Control Plane` ภายในมีเจ็ดรายการเรียงสองคอลัมน์: source-of-truth protection, requirement traceability, Lite/Standard/Strict modes, scope & design approval, evidence requirements, QA/security/release gates, human authority boundaries; ลูกศรลงกำกับว่า `approved execution contract`; บล็อก 3 `AI Execution Framework` ระบุ Superpowers / BMAD / spec-kit / OpenSpec / custom Claude Code และงานที่ทำคือ planning, TDD, implementation, code review, verification; ลูกศรลงกำกับว่า `candidate result + evidence`; บล็อก 4 `Axiom-PMO Validation` — scope compliance, evidence verification, traceability update, QA/security review, human release approval; ลูกศรวนกลับขึ้นหามนุษย์กำกับว่า `release readiness`; บรรทัดล่างขนาด Annotation อ้างอิง "Axiom-PMO is **not** an execution framework… It is the governance control plane those frameworks can operate inside."

### Part 3: สี่หลักการที่ทำให้มันทำงาน

#### Slide 06 - หลักการ 1 — ทุกข้ออ้างต้องมีหลักฐาน

- **Audience move**: คิดว่า "มีหลักฐาน" เป็นเรื่องนามธรรม → เห็นว่ามันคือสองฟิลด์ที่เขียนลงไฟล์จริง และเห็นว่าคำตอบว่า "ไม่รู้" ก็เป็นคำตอบที่ถูกต้อง
- **Layout**: แบ่งบน–ล่าง ครึ่งบนเป็นบล็อกโค้ด YAML บนพื้น Secondary background แสดงรูปทรงของ requirement จริง ครึ่งล่างเป็นห้าคอลัมน์เท่ากันของสถานะหลักฐาน แต่ละคอลัมน์มีแถบสีบางด้านบน
- **Title**: หลักการ 1 — Evidence: ทุกข้ออ้างต้องสาวกลับไปหาแหล่งได้
- **Core message**: requirement, decision, test และ release claim ทุกอันต้องพก `source_ref` และ `evidence_status` ติดตัวเสมอ
- **Content**: บล็อกบนเป็น YAML ฟอนต์ Data — `id: REQ-001`, `statement`, `source_ref` ที่มี `source_id` และ `locator`, `evidence_status: supported`, `acceptance_criteria`; ครึ่งล่างห้าคอลัมน์ แต่ละคอลัมน์มีชื่อสถานะเป็นฟอนต์ Data ตัวหนาและคำอธิบายไทยหนึ่งบรรทัด — `verified` มีแหล่งอ้างอิงตรง **และ** มนุษย์อนุมัติแล้ว (แถบสี Secondary accent); `supported` มีแหล่งอ้างอิงตรง แต่ยังรออนุมัติขั้นสุดท้าย (แถบสี Secondary accent จาง); `inferred` อนุมานจากแหล่งที่มีไม่ครบ **ต้องให้คนรีวิว** (แถบสี Warning); `missing` ไม่พบในแหล่ง **ห้ามกลายเป็น requirement** (แถบสี Accent); `conflict` แหล่งขัดกันเอง **ต้องเคลียร์ก่อนออกเอกสารจริง** (แถบสี Accent); บรรทัดปิดเต็มความกว้างขนาด Lead "inferred, missing และ conflict ไม่ใช่ความล้มเหลวของความซื่อสัตย์ — มันคือคำตอบที่ซื่อสัตย์"

#### Slide 07 - หลักการ 2 — ความเข้มของ process ผูกกับความเสี่ยง

- **Audience move**: กลัวว่า framework จะทำให้งานเล็กช้าลง → เข้าใจว่าโหมดเลือกตามความเสี่ยงต่อชิ้นงาน และงานเล็กแทบไม่มีภาระเพิ่ม
- **Layout**: สามคอลัมน์เท่ากันเทียบโหมด คอลัมน์ Strict มีเส้นกรอบหนากว่าและหัวคอลัมน์พื้น Accent ตัวอักษรขาว; ใต้สามคอลัมน์เป็นแถบเต็มความกว้างแสดง trigger ที่บังคับขึ้น Strict
- **Title**: หลักการ 2 — Risk Modes: เลือกโหมดเบาที่สุดที่ยังคุมความเสี่ยงจริงได้
- **Core message**: โหมดเลือกต่อชิ้นงาน ไม่ใช่ต่อโปรเจกต์ และมีเงื่อนไขที่บังคับให้ขึ้น Strict โดยไม่ต้องรอใครตัดสินใจ
- **Content**: สามคอลัมน์ Lite / Standard / Strict แต่ละคอลัมน์บอก ใช้เมื่อไหร่ / flow / เอกสารที่ต้องมี — Lite สำหรับบั๊กเล็กและงานความเสี่ยงต่ำ, flow `Requirement → AC → Develop → Test → Done`, owner ที่เป็นชื่อกลาง ๆ แค่เตือน; Standard สำหรับฟีเจอร์ปกติ, flow `Intake & Scope → Flow & UX → Plan & Handoff → Build & Verify → Release & Close`, owner กลาง ๆ = **fail**; Strict เมื่อพลาดแล้วกระทบธุรกิจ กฎหมาย เงิน ความเป็นส่วนตัว production หรือระบบภายนอก, ต้องมี RAID-log, decision-log, source_ref เต็ม, semantic review ที่หายหรือเก่า = **fail ไม่ใช่ warn**; แถบล่าง — หัวข้อขนาด Annotation "13 strict triggers บังคับขึ้นโหมดอัตโนมัติ" ตามด้วยรายการฟอนต์ Data ไหลต่อกัน: payment, financial calculation, PII, sensitive data, authentication, authorization, permission, irreversible action, external integration, legal/compliance, production data migration, critical infrastructure, public-sector formal acceptance; บรรทัดปิดตัวหนา "You can always do more; you cannot silently do less." พร้อมคำอธิบายไทยว่า AI ขยับขึ้นได้เอง แต่ลดลงจาก Strict ต้องให้ PM หรือ Tech Lead อนุมัติ

#### Slide 08 - หลักการ 3 — ด่านตรวจที่ถามคนละคำถาม

- **Audience move**: มองว่า gate คือขั้นตอนอนุมัติที่ซ้ำซ้อน → เห็นว่าแต่ละด่านถามคนละคำถาม และรู้ว่า Handoff เป็นด่านตรวจ ไม่ใช่ด่านอนุมัติ
- **Layout**: pipeline แนวนอนเต็มความกว้าง ห้าบล็อกเชื่อมด้วยลูกศร แต่ละบล็อกมีชื่อ gate ด้านบนและคำถามประจำด่านด้านล่าง; บล็อก Handoff เน้นด้วยกรอบสี Accent และมี label เล็ก ๆ ว่า `checking gate`; ใต้ pipeline เป็นบรรทัดอธิบายสองบรรทัด
- **Title**: หลักการ 3 — Gates: ห้าด่าน ห้าคำถาม
- **Core message**: การผ่านด่านไม่ใช่พิธีกรรม แต่ละด่านมีคำถามเดียวที่ต้องตอบให้ได้
- **Visualization**: pipeline เชิงโครงสร้าง อ้างอิง `pipeline_with_stages` เป็นแนวทาง ไม่ใช่ chart จากข้อมูล
- **Content**: ห้าบล็อกฟอนต์ Data สำหรับชื่อ gate และไทยสำหรับคำถาม — `Draft` โปรเจกต์นี้อยู่ในรูปที่ใช้งานได้แล้วหรือยัง; `Scope` requirement ทุกข้อมีแหล่งอ้างอิงและได้รับอนุมัติแล้วหรือยัง; `Design` ดีไซน์พร้อมและได้รับอนุมัติแล้วหรือยัง; `Handoff` **dev เริ่มงาน ต่อระบบ และเดโมได้จริงไหม**; `Release` เทสต์ รีวิว อนุมัติ และย้อนกลับได้แล้วหรือยัง; สองบรรทัดใต้ pipeline — "Handoff เป็นด่านตรวจ ไม่ใช่ด่านอนุมัติ: มันไม่เพิ่มการเซ็นอนุมัติใหม่ แต่ใช้ `Design Ready` เดิมที่อนุมัติไปแล้ว" และ "แต่ละ gate มีรายการเอกสารที่ต้องมีของตัวเอง แยกตามโหมด กำหนดใน `pmo-config/artifact-policy.json`"

#### Slide 09 - หลักการ 4 — เส้นที่ AI ข้ามไม่ได้

- **Audience move**: ไม่แน่ใจว่าปล่อยให้ AI ทำอะไรได้แค่ไหน → มีรายการชัดเจนที่เอาไปใช้ตัดสินได้ทันที
- **Layout**: แบ่ง 6+6 — ซ้ายหัวข้อ "AI ทำเองไม่ได้" มีรายการเจ็ดข้อ แต่ละข้อขึ้นต้นด้วยเครื่องหมายกากบาทเส้นสี Accent; ขวาหัวข้อ "AI ทำได้" มีรายการสั้นกว่า ขึ้นต้นด้วยเครื่องหมายถูกสี Secondary accent; ด้านล่างเต็มความกว้างเป็นประโยคสรุปบนพื้น Secondary background
- **Title**: หลักการ 4 — Human Authority: AI เสนอได้ แต่อนุมัติงานตัวเองไม่ได้
- **Core message**: ขอบเขตอำนาจไม่ได้อยู่ในคำสั่ง แต่อยู่ในกฎที่ทำให้ gate ไม่ผ่านเมื่อถูกข้าม
- **Content**: ฝั่งซ้ายเจ็ดข้อ — commit, push, tag หรือ deploy; อนุมัติ production release; อนุมัติ business scope; ทำเครื่องหมายว่า QA หรือ security ผ่าน; ย้ายแถวอนุมัติจาก pending เป็น approved; ปิด finding ที่ต้องใช้การตัดสินใจทางธุรกิจ กฎหมาย ความปลอดภัย หรือการค้า; เอาคะแนน readiness ไปเสนอเป็นข้อสรุป; ฝั่งขวา — เสนอว่าควรไป gate ถัดไป, บันทึก finding พร้อมหลักฐาน, ปิด finding ที่เอกสารแสดงชัดว่าแก้แล้ว, เตรียม diff ให้คนรีวิว; แถบล่างประโยคใหญ่ "An agent **may** recommend the next gate. It **may not** approve its own work." พร้อมบรรทัดไทยว่า commit ทำได้เฉพาะหลังมีคนอนุมัติ diff แล้ว ส่วน push, PR, merge และ production release ต้องมีการยืนยันจากมนุษย์เสมอ

### Part 4: เจาะลึก — ด่าน Handoff

#### Slide 10 - ห้าความพังที่เอกสารครบก็ยังเจอ

- **Audience move**: คิดว่าเอกสารครบแปลว่าพร้อมส่ง dev → เห็นว่าเอกสารครบทุกช่องยังส่งแผนที่ทำไม่ได้จริงให้ dev ได้ และแต่ละเคสกินเวลาเป็นวัน
- **Layout**: ห้าแถวเรียงลง แต่ละแถวแบ่ง 8+4 — ซ้ายเป็นคำบรรยายเหตุการณ์ ขวาเป็นราคาที่ต้องจ่ายด้วยตัวอักษรสี Accent ขนาด Annotation; คั่นด้วยเส้น hairline
- **Title**: ทำไมต้องมีด่าน Handoff
- **Core message**: กฎที่ตรวจแค่ว่า "ช่องนี้กรอกหรือยัง" มองไม่เห็นความพังทั้งห้าแบบนี้เลย
- **Content**: คำถามเปิดหน้าขนาด Subtitle "เอกสารชุดนี้ดีพอให้ dev เริ่มสร้าง และให้ทีมเดโมทันเวลาไหม"; ห้าแถว — schema กลางที่ทุกงานต้องใช้ ถูกจัดคิวไว้หลังงานที่เรียกใช้มัน / วิศวกรสองคนเสียไปทั้งวันแรก; ฟีเจอร์สแกนต้องใช้กล้อง แต่ไม่มีใครตัดสินว่าหน้าเว็บจะเสิร์ฟยังไง ทำงานบน localhost แต่พังบนแท็บเล็ตที่ยืมมา / code review จับไม่ได้ เพราะไม่มีอะไรผิดในโค้ด; เอกสารหนึ่งบอกว่าเก็บรูปไว้ในเครือข่ายไซต์ อีกเอกสารระบุอัปโหลดรูปโดยไม่จัดชั้นข้อมูล / คนเขียนทั้งสองหน้าถูกต้องในหน้าของตัวเอง; acceptance case อ้างพฤติกรรมกับ record ที่ seed data ไม่เคยสร้าง / เคสนั้นไม่เคยถูกรันจริง; งานถูก assign ให้ "Dev Team" / รอดทุกที่ประชุม แล้วตายเช้าวันจันทร์; บรรทัดปิดตัวหนา "Every one of these is invisible to a rule that checks whether a field is filled in. **Every one of them costs days.**"

#### Slide 11 - สองชั้นที่แยกกันโดยตั้งใจ

- **Audience move**: คิดว่า validator น่าจะฉลาดพอตรวจได้ทุกอย่าง → เข้าใจว่ามันตั้งใจไม่ตรวจเรื่องเชิงความหมาย และรู้ว่าใครรับผิดชอบส่วนไหน
- **Layout**: แบ่ง 6+6 สองบล็อกใหญ่เท่ากัน แต่ละบล็อกมีหัวเป็นแถบพื้นและเนื้อในเป็นรายการ; ใต้สองบล็อกเป็นแถบเต็มความกว้างสีพื้น Secondary background ระบุกฎเรื่องการปิด finding
- **Title**: สองชั้น — เครื่องตรวจสิ่งที่พิสูจน์ได้ คนตรวจสิ่งที่ต้องใช้วิจารณญาณ
- **Core message**: validator ไม่เดาความหมายเชิงโดเมนโดยตั้งใจ เพราะ validator ที่เดาผิดแย่กว่า validator ที่เงียบ
- **Content**: บล็อกซ้าย `Layer 1 — Deterministic` — ตรวจสิ่งที่พิสูจน์ได้จากเอกสาร, กฎ `HANDOFF-001` ถึง `HANDOFF-014`, อ่านเฉพาะสิ่งที่ผู้เขียนประกาศไว้แล้วเช็คว่าครบและสอดคล้องไหม, **ตัดสินไม่ได้** ว่ารูปถ่ายรถคือข้อมูลส่วนบุคคล — และไม่พยายามจะตัดสิน; บล็อกขวา `Layer 2 — Semantic review` — ตรวจว่าสัญญาทั้งชุดสมเหตุสมผลไหม, อ่านผ่าน 12 เลนส์, ผู้อ่านคือ AI หรือคน, บันทึกเป็น `HANDOFF-REVIEW.json`, **เป็นหลักฐานที่ยังไม่ได้รับรอง ไม่ใช่การอนุมัติ**; ระหว่างสองบล็อกมีประโยคอ้างอิงเล็ก ๆ ว่าทำไมไม่ฝังกฎเชิงโดเมน — "a validator that guesses wrong is worse than one that stays quiet — it teaches people to ignore it"; แถบล่าง — ใครปิด finding ได้: AI ปิดได้เฉพาะสถานะ `resolved` เท่านั้น ส่วนเลนส์ privacy และ environment ต้องให้คนปิด บังคับด้วยกฎ `HANDOFF-010` พร้อมประโยค "An instruction telling an agent not to close a privacy finding is not a control; a rule that fails the gate when it does is."

#### Slide 12 - สิบสองเลนส์ที่ใช้อ่านสัญญา

- **Audience move**: ไม่รู้ว่า "รีวิวเชิงความหมาย" แปลว่าตรวจอะไรบ้าง → เห็นรายการครบสิบสองข้อ และรู้ว่าสองข้อไหนที่ AI แตะไม่ได้
- **Layout**: ตารางสามคอลัมน์ สี่แถว รวมสิบสองช่อง แต่ละช่องมีเลขลำดับสี Grid ชื่อเลนส์ฟอนต์ Data และคำถามภาษาไทยหนึ่งบรรทัด; สองช่องที่เป็น human-only มีจุดสี Accent มุมขวาบน; คำอธิบายจุดอยู่ใต้ตาราง
- **Title**: 12 เลนส์ที่ใช้อ่านว่าสัญญานี้ทำได้จริงไหม
- **Core message**: สิบสองคำถามนี้คือสิ่งที่คนอ่านเก่ง ๆ ถามอยู่แล้ว แค่ถูกเขียนลงไฟล์ให้ถามครบทุกครั้ง
- **Visualization**: ตารางเชิงโครงสร้าง อ้างอิง `icon_grid` เป็นแนวทางการจัดวาง ไม่ใช่ chart จากข้อมูล
- **Content**: สิบสองช่อง — 01 `value_and_scope_slice` ขอบเขตที่ตัดมา ส่งมอบคุณค่าที่ milestone ต้องโชว์ไหม; 02 `capability_lifecycle` แต่ละความสามารถครบวงจรไหม ไม่ใช่แค่ happy path; 03 `data_cardinality_and_units` entity, จำนวน และหน่วย รองรับ use case ที่ประกาศไว้ไหม; 04 `state_transitions_and_rollback` ทุก state machine มี guard, terminal state และทางย้อนกลับไหม; 05 `concurrency_and_idempotency` เขียนพร้อมกัน, retry และการจอง id ซ้ำ ระบุไว้หรือยัง; 06 `dependencies_and_build_order` ลำดับ build ที่ประกาศไว้ รันตามลำดับนั้นได้จริงไหม; 07 `ownership_and_capacity` ทุกสายงานมีเจ้าของที่เป็นชื่อคน มี integrator และระบุกำลังคนไหม; 08 `acceptance_seed_reachability` แต่ละ acceptance case ไปถึงได้จาก seed data ที่มีไหม; 09 `automated_manual_test_split` แต่ละเคสระบุว่า automated หรือ manual พร้อม runner ไหม; 10 `privacy_and_data_classification` ข้อมูล ไฟล์ และ free text ที่ประกาศไว้ มีการตัดสินชั้นข้อมูลครบไหม **(คนเท่านั้น)**; 11 `environment_and_device_constraints` วิธีเสิร์ฟรองรับอุปกรณ์และ runtime ที่ประกาศไว้ไหม **(คนเท่านั้น)**; 12 `demo_startup_reset_and_recovery` เดโมมีทางเริ่ม รีเซ็ต ทำงานแบบลดทอน และกู้คืนไหม; บรรทัดใต้ตารางขนาด Annotation "ทุก finding ต้องอ้างหลักฐาน — finding ที่ไม่มีหลักฐานคือความเห็น ไม่ใช่ finding"

#### Slide 13 - ความพร้อมไม่ใช่คำตอบเดียว

- **Audience move**: อยากได้คำตอบเดียวว่าพร้อมหรือไม่พร้อม → เข้าใจว่าคำตอบเดียวบังคับให้เลือกผิดทั้งสองทาง และคะแนนไม่ใช่การอนุมัติ
- **Layout**: แบ่ง 5+7 — ซ้ายเป็นรายการหกด่านความพร้อมพร้อมช่องสถานะสามค่า; ขวาเป็นแท่งแนวนอนเจ็ดมิติของคะแนน เรียงจากน้ำหนักมากไปน้อย ต่อด้วยกล่องเพดานคะแนนสี่ข้อ
- **Title**: ความพร้อมรายงานเป็นหกด่าน ไม่ใช่ค่าเดียว
- **Core message**: ยุบทุกอย่างเป็นคำตอบเดียวคือการเลือกระหว่างหยุดทีมที่ทำงานได้ กับสัญญาเดโมที่จะไม่เกิด
- **Visualization**: แท่งแนวนอนเทียบน้ำหนักเจ็ดมิติ อ้างอิง `horizontal_bar_chart`; ค่าตัวเลขมาจาก `pmo-config/handoff-policy.json` โดยตรง
- **Native-ready**: no
- **Content**: ฝั่งซ้ายหกด่าน — Contract Valid, Ready to Start Development, Ready to Integrate, Ready to Demo, Ready for UAT, Ready for Release พร้อมหมายเหตุว่าแต่ละด่านมีสามค่าคือ `true` / `false` / `null` และคำอธิบายว่าทำไม `null` ถึงสำคัญ — ถ้ายังไม่มีการรีวิว แปลว่าไม่มี finding ที่ *ถูกบันทึกไว้* ซึ่งไม่เท่ากับไม่มี finding การรายงาน `true` ตรงนั้นคือการเปลี่ยน "ไม่มีหลักฐาน" ให้กลายเป็น "หลักฐานว่าไม่มี"; ฝั่งขวาเจ็ดแท่ง — Engineering contract 20, Source and scope integrity 15, Requirement and design traceability 15, Acceptance seed and testability 15, Dependency owner and capacity 15, Security privacy and environment 10, Demo and operational readiness 10; ใต้แท่งเป็นกล่องเพดานสี่ข้อฟอนต์ Data — deterministic FAIL ใด ๆ → `BLOCKED`; review หายหรือเก่า → สูงสุด 70; ไม่มีเจ้าของที่เป็นชื่อคน หรือลำดับ build รันไม่ได้ → สูงสุด 69; critical finding ที่บล็อก `before_build` → สูงสุด 49; บรรทัดปิดตัวหนาสี Accent "The score is not an approval."

### Part 5: พิสูจน์ว่าใช้ได้จริง

#### Slide 14 - สองโปรเจกต์ที่ผ่านทุกด่านของเวอร์ชันเดิม

- **Audience move**: ยังไม่เชื่อว่าต่างกันจริง → เห็นความต่างห้าจุดที่จับต้องได้ และเห็นว่าโปรเจกต์ที่แก้แล้วยังรายงานว่าเดโมไม่ได้ ซึ่งเป็นพฤติกรรมที่ถูกต้อง
- **Layout**: ครึ่งบนเป็นตารางห้าแถว สี่คอลัมน์ (rule / broken / fixed / ราคา) แถวสลับพื้น Surface; ครึ่งล่างแบ่ง 7+5 — ซ้ายเป็นบล็อกผลลัพธ์จริงฟอนต์ Data บนพื้น Secondary background ขวาเป็นคำอธิบายสองบล็อกเกอร์
- **Title**: สองโปรเจกต์ ผ่านเท่ากันหมด — แต่หนึ่งในนั้นสร้างไม่ได้เช้าวันจันทร์
- **Core message**: ความต่างห้าจุดนี้มองไม่เห็นจากการตรวจว่าเอกสารครบ แต่เห็นได้ทันทีเมื่อกฎอ่านสิ่งที่เอกสารประกาศ
- **Content**: ตารางห้าแถว — `HANDOFF-004` ลำดับ build `4 D-001 / 2 D-002 / 3 D-003 / 1 D-004` schema กลางอยู่ท้ายสุด → เรียงเป็น `1 / 2 / 3 / 4` ตาม dependency / วิศวกรสองคนเสียวันแรก; `HANDOFF-012` กล้องหลัง การตัดสินเรื่อง environment ยัง `open` → HTTPS ผ่าน local reverse proxy ที่แท็บเล็ตเชื่อถือใบรับรอง / ทำงานบนแล็ปท็อป พังบนแท็บเล็ตเดโม; `HANDOFF-011` รูปชิ้นส่วน sensitive `yes` แต่ช่องจัดชั้นว่าง → `internal-only, stays on the site network` / คำมั่นเรื่องความเป็นส่วนตัวขัดกับฟีเจอร์; `HANDOFF-007` AC-002 automated แต่ช่อง fixture ว่าง → fixture `parts-demo part P-0007` / เคสไม่เคยถูกรันจริง; `HANDOFF-003` เจ้าของงานคือ `Dev Team` → `R. Silva` / ไม่มีใครเริ่มงาน; บล็อกผลลัพธ์ฝั่งซ้ายล่างเป็นข้อความจริงจาก assess-handoff — `Verdict: READY TO BUILD, NOT READY TO DEMO` ตามด้วยหกบรรทัดสถานะ YES/NO และ `Score: 92 / 100`; ฝั่งขวาล่างอธิบายว่าบล็อกเกอร์สองตัวมาจากคนละเอกสาร — semantic review เจอตัวหนึ่ง คืออุปกรณ์เดโมที่ทีมไม่ได้เป็นเจ้าของ ส่วน `HANDOFF.md` ประกาศอีกตัว คือใบรับรองที่ยังไม่ได้ติดตั้งบนเครื่องนั้น ทั้งคู่หยุดการเดโม แต่ไม่มีตัวไหนหยุดการเขียนโค้ดวันนี้ gate จึงไม่แกล้งบอกว่าหยุด; บรรทัดปิด "คะแนนเป็น 92 ไม่ใช่ 100 เพราะโปรเจกต์ที่เอกสารตัวเองบอกว่าเดโมไม่ได้ ไม่ควรอ่านออกมาว่าสมบูรณ์แบบ"

#### Slide 15 - สิ่งที่บังคับใช้จริง

- **Audience move**: เข้าใจแนวคิดแล้ว แต่ยังไม่รู้ว่ามีของจริงแค่ไหนและเริ่มยังไง → เห็นขนาดของสิ่งที่มีอยู่จริง และรู้คำสั่งที่พิมพ์ได้ทันที
- **Closing impact**: สิ่งที่ผู้ฟังต้องกลับไปพร้อมกับคำเดียวคือ กฎที่บังคับไม่ได้ ไม่ใช่กฎ — composition คือแถบตัวเลขใหญ่พาดกลางหน้าที่พิสูจน์ว่าของมีจริงและถูกทดสอบจริง แล้วปิดด้วยประโยค North Star สองบรรทัดขนาด Subtitle บนพื้นเข้มเต็มความกว้างด้านล่าง ไม่ใช่หน้าขอบคุณและไม่ใช่การเอาปกมาพูดซ้ำ
- **Layout**: สามแถบแนวนอน — บนสุดเป็นแถวตัวเลขหกช่องขนาด Hero ย่อ; กลางเป็นสองคอลัมน์ ซ้ายกลไกป้องกันตัวเอง ขวาคำสั่งที่ใช้จริงฟอนต์ Data; ล่างสุดเป็นแถบพื้น Primary ตัวอักษรขาวสำหรับประโยคปิด
- **Title**: กฎที่บังคับไม่ได้ ไม่ใช่กฎ
- **Core message**: ทั้งหมดนี้ไม่ได้อยู่ในเอกสาร แต่อยู่ในโค้ดที่รันได้ ทดสอบแล้ว และล้มเหลวเมื่อควรล้มเหลว
- **Content**: แถวตัวเลขหกช่อง — `82` validation rules, `14` handoff rules, `12` review lenses, `148` fixture test cases, `7` skills โหลดตามงาน, `5,414` บรรทัด PowerShell; คอลัมน์ซ้าย "engine ป้องกันตัวเองยังไง" สี่ข้อ — config-mutation test พิสูจน์ว่า JSON policy มีผลจริง แก้ policy แล้วกฎต้องเปลี่ยนพฤติกรรม; เทสต์ยืนยันว่า scaffold ที่ generate ออกมาใหม่แต่ยังไม่กรอก **ต้อง fail** ที่ด่าน Handoff เพราะ generator ที่ปล่อยของผ่านได้เท่ากับกำลังผลิตหลักฐานปลอม; `DOCTOR-009` ทำให้ build ล้มถ้ากฎอ้างถึงหน้าเอกสารที่ไม่มีอยู่จริง; CI มีขั้น fault injection ที่กลับด้าน assertion เพื่อพิสูจน์ว่าตัวรันเทสต์ไม่กลืนความล้มเหลวของลูก; คอลัมน์ขวา "เริ่มใช้ยังไง" เป็นคำสั่งฟอนต์ Data — `validate-project.ps1 -ProjectPath <project> -Mode Standard -Gate Handoff`, `assess-handoff.ps1 -ProjectPath <project> -Mode Standard`, `pmo-doctor.ps1`, `run-validation-tests.ps1` พร้อมบรรทัด exit code `0` ผ่าน `1` fail `2` warning ที่บล็อกเมื่อเปิด `-FailOnWarning` และหมายเหตุตัวเล็กว่า Windows PowerShell 5.1 คือขาอ้างอิงที่บล็อกใน CI ส่วน Linux/macOS ผ่าน pwsh 7 ยังเป็น experimental; แถบปิดพื้นเข้ม — `AI can build.` / `Axiom-PMO verifies the source, scope, evidence, tests, and authority behind the work.`

## X. Speaker Notes Requirements

- **Filename**: match each SVG filename under `notes/`
- **Content**: ผู้พูดเป็นคนแบกรายละเอียด สไลด์แบกข้อสรุป — โน้ตแต่ละหน้าต้องมี ประโยคเปิดที่เชื่อมจากหน้าก่อน, คำอธิบายขยายทุกจุดที่หน้าพูดสั้น, อย่างน้อยหนึ่งจุดที่เตรียมไว้ตอบคำถามผู้ฟังสายเทคนิค และประโยคส่งไปหน้าถัดไป; ทุกตัวเลขและคำพูดอ้างอิงต้องระบุไฟล์ต้นทางใน repo กำกับไว้ให้ผู้พูดตอบได้เมื่อถูกถามว่ามาจากไหน; หน้าที่มีผู้ฟังผสม (P05, P10, P13, P14) ต้องมีทั้งประโยคสำหรับผู้บริหารและประโยคสำหรับทีมเทคนิค แยกให้ผู้พูดเลือกตามห้อง; ห้ามเติมข้อเท็จจริงที่ไม่มีในแหล่ง — ถ้าไม่มีให้เขียนว่าไม่มี
- **Total duration**: 20–25 นาที (เฉลี่ยหน้าละ 80–100 วินาที โดย P10, P13 และ P14 ยาวกว่าค่าเฉลี่ย)
- **Notes style**: conversational — เขียนเป็นภาษาพูดที่หยิบไปพูดได้เลย ไม่ใช่ bullet ย่อ
- **Presentation purpose**: instruct เป็นหลัก โดยมี inform รองรับช่วงต้น และ persuade แทรกในหน้า P04 และ P14

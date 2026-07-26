<!-- ppt-master-schema: spec-lock/v1 -->
# Execution Lock

## canvas
- viewBox: 0 0 1280 720
- format: PPT 16:9

## communication
- audience: ทีมส่งมอบภายใน (PM / Dev / QA) ที่คุ้นเคยกับ software delivery แต่ยังไม่รู้จัก AI governance และผู้บริหาร/ลูกค้าที่ฟังในรอบเดียวกัน
- objective: อธิบายกลไกของ Axiom-PMO ให้ผู้ฟังผสมเข้าใจแล้วนำไปใช้ต่อได้ จนอธิบายเองได้ว่าทำไม prompt ไม่ใช่ control ไล่ชื่อสี่หลักการได้ และบอกลำดับ gate พร้อมคำถามประจำแต่ละด่านได้
- core_message: AI เขียนโค้ดได้ แต่ต้องไม่กุโปรเจกต์ขึ้นมาเอง — Axiom-PMO เปลี่ยนกฎที่เป็นแค่ข้อความ ให้กลายเป็นสัญญาที่เครื่องตรวจสอบได้
- consumption_mode: balanced

## mode
- mode: instructional

## visual_style
- visual_style: swiss-minimal

## colors
- background: #FFFFFF
- secondary_bg: #F2F1ED
- primary: #14161A
- accent: #D6360B
- secondary_accent: #2E6B5E
- body_text: #3A3F45
- warning: #B36A00
- surface: #FAFAF8
- grid: #DEDDD8

## typography
- font_family: Tahoma, Arial, sans-serif
- title_family: Tahoma, Arial, sans-serif
- body_family: Tahoma, Arial, sans-serif
- data_family: Consolas, Courier New, monospace
- body: 24
- title: 42
- subtitle: 32
- annotation: 18
- hero: 84
- lead: 30
- footnote: 16
- data: 18

## icons
- library: tabler-outline
- stroke_width: 2
- inventory: tabler-outline/alert-triangle, tabler-outline/lock-open, tabler-outline/shield-check, tabler-outline/file-search, tabler-outline/stack-2, tabler-outline/git-branch, tabler-outline/user-check, tabler-outline/binary-tree, tabler-outline/eye-search

## page_rhythm
- P01: anchor
- P02: breathing
- P03: dense
- P04: dense
- P05: anchor
- P06: dense
- P07: dense
- P08: anchor
- P09: dense
- P10: dense
- P11: dense
- P12: dense
- P13: dense
- P14: dense
- P15: anchor

## page_charts
- P08: pipeline_with_stages
- P12: icon_grid
- P13: horizontal_bar_chart

## pptx_structure
- mode: flat

## forbidden
- `mask`, `<style>`, `class`, external CSS, `<foreignObject>`, `textPath`, `@font-face`, `<animate*>`, `<set>`, `<script>` / event attributes, `<iframe>`
- HTML named entities in text; write typography as raw Unicode and escape XML reserved characters

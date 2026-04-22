# DESIGN.md 9-Section Format Reference

> Based on [Google Stitch DESIGN.md format](https://stitch.withgoogle.com/docs/design-md/format/)
> ใช้เป็น template เมื่อสร้าง custom DESIGN.md

---

## Section 1: Visual Theme & Atmosphere

อธิบาย mood, density, design philosophy ของ project

**ต้องมี:**
- Overall design philosophy (1-2 paragraphs)
- Key characteristics (bullet points)
- Visual tone: professional, playful, minimal, bold, luxurious, etc.
- What makes this design distinctive

**ตัวอย่าง:**
> The design is clean and professional with generous whitespace. It feels like a premium SaaS product that values clarity over decoration. The signature blue primary color anchors every interactive element while keeping the UI calm and focused.

---

## Section 2: Color Palette & Roles

ระบุสีทุกตัวพร้อม semantic role

**ต้องมี:**
- Primary colors (brand, CTA, heading)
- Accent colors (highlight, warning, success, error)
- Neutral scale (text levels, borders, backgrounds)
- Surface & shadow colors
- Interactive states (hover, active, focus, disabled)
- ทุกสีต้องมี: Name, Hex, Role/Usage

**Format:**
```markdown
### Primary
- **Brand Blue** (`#0066FF`): Primary CTA, links, active states

### Accent
- **Success Green** (`#22C55E`): Success badges, positive indicators
- **Error Red** (`#EF4444`): Error states, destructive actions

### Neutral
- **Heading** (`#111827`): Primary headings, nav text
- **Body** (`#6B7280`): Body text, descriptions
- **Border** (`#E5E7EB`): Card borders, dividers

### Surface
- **Background** (`#FFFFFF`): Page background
- **Surface** (`#F9FAFB`): Card background, section background
```

---

## Section 3: Typography Rules

ระบุ font family และ hierarchy table

**ต้องมี:**
- Font family (primary, secondary, monospace) + fallbacks
- OpenType features (ถ้ามี)
- Full hierarchy table with: Role, Font, Size, Weight, Line Height, Letter Spacing

**Format:**
```markdown
### Font Family
- **Primary**: Inter, system-ui, sans-serif
- **Monospace**: JetBrains Mono, monospace

### Hierarchy
| Role | Size | Weight | Line Height | Letter Spacing |
|------|------|--------|-------------|----------------|
| Display | 48px | 700 | 1.1 | -0.02em |
| H1 | 36px | 700 | 1.2 | -0.01em |
| H2 | 30px | 600 | 1.3 | 0 |
| H3 | 24px | 600 | 1.3 | 0 |
| Body | 16px | 400 | 1.6 | 0 |
| Small | 14px | 400 | 1.5 | 0 |
| Caption | 12px | 500 | 1.4 | 0.02em |
```

---

## Section 4: Component Stylings

ระบุ spec ของ component หลักๆ

**ต้องมี:**
- Buttons (primary, secondary, ghost + all states)
- Cards (padding, border, shadow, radius)
- Inputs (height, border, focus state, error state)
- Navigation (sidebar, topbar, tabs)
- Tables (ถ้ามี)
- Modals/Dialogs (ถ้ามี)
- Distinctive/branded components

**Format per component:**
```markdown
### Buttons
**Primary:**
- Background: {hex}
- Text: {hex}
- Border Radius: {px}
- Padding: {px} {px}
- Font: {weight} {size}
- Hover: {description}
- Active: {description}
- Disabled: {description}
```

---

## Section 5: Layout Principles

ระบุ spacing system และ grid

**ต้องมี:**
- Spacing scale (4px-based or 8px-based)
- Grid system (columns, gutter, max-width)
- Container widths per breakpoint
- Whitespace philosophy
- Border radius scale

**Format:**
```markdown
### Spacing Scale
4 / 8 / 12 / 16 / 24 / 32 / 48 / 64 / 96 / 128 px

### Grid
- Columns: 12
- Gutter: 24px
- Max Width: 1280px

### Border Radius Scale
- None: 0px
- Small: 4px
- Medium: 8px
- Large: 12px
- XL: 16px
- Full: 9999px
```

---

## Section 6: Depth & Elevation

ระบุ shadow system

**ต้องมี:**
- Shadow levels (subtle, default, medium, large, xl)
- Usage per level (when to use each)
- Decorative depth effects (ถ้ามี)

**Format:**
```markdown
### Shadow System
| Level | Value | Usage |
|-------|-------|-------|
| Subtle | 0 1px 2px rgba(0,0,0,0.05) | Cards at rest |
| Default | 0 1px 3px rgba(0,0,0,0.1), 0 1px 2px rgba(0,0,0,0.06) | Interactive cards |
| Medium | 0 4px 6px rgba(0,0,0,0.1) | Dropdowns, popovers |
| Large | 0 10px 15px rgba(0,0,0,0.1) | Modals |
| XL | 0 20px 25px rgba(0,0,0,0.15) | Floating elements |
```

---

## Section 7: Do's and Don'ts

Design guardrails

**Format:**
```markdown
### Do's
- Use primary color only for CTAs and key interactive elements
- Maintain minimum 4.5:1 contrast ratio for text
- Use consistent border radius across all components

### Don'ts
- Don't use more than 3 colors in a single view
- Don't mix rounded and sharp corners
- Don't use shadows on flat/flush elements
```

---

## Section 8: Responsive Behavior

ระบุ breakpoints และ mobile behavior

**ต้องมี:**
- Breakpoints (mobile, tablet, desktop, wide)
- Touch target minimum size
- Layout collapsing strategy
- Mobile-specific adjustments

**Format:**
```markdown
### Breakpoints
| Name | Width | Layout |
|------|-------|--------|
| Mobile | < 640px | Single column |
| Tablet | 640-1024px | 2 columns |
| Desktop | 1024-1280px | Full layout |
| Wide | > 1280px | Centered max-width |

### Touch Targets
- Minimum: 44x44px
- Recommended: 48x48px
```

---

## Section 9: Agent Prompt Guide

Quick reference สำหรับ AI agents

**ต้องมี:**
- Quick color reference (5-8 key colors)
- Ready-to-use prompts (2-3 example prompts)
- Key rules summary

**Format:**
```markdown
### Quick Colors
Primary: #0066FF | Accent: #22C55E | Background: #FFFFFF | Text: #111827 | Border: #E5E7EB

### Ready-to-Use Prompts
- "Build a dashboard page using this design system"
- "Create a settings form with proper validation states"
- "Design a data table with sorting and filtering"

### Key Rules
1. Always use Primary for CTAs, never for backgrounds
2. Body text is always #6B7280, headings are #111827
3. Cards always have 1px border + subtle shadow
```

# Common Lark PlantUML Violations — Quick Fix Guide

> จากประสบการณ์ debug P01-PROJECT 14 ไฟล์ (2026-02-24/25) รวบรวม pattern ที่ผิดบ่อยที่สุด

---

## Top 5 Violations (เรียงตามความถี่)

### 1. Leading Whitespace (Rule 1) — พบบ่อยที่สุด

**สาเหตุ:** AI มักจะ indent code ตาม hierarchy อัตโนมัติ เช่น indent ภายใน if/else, note, partition

**Pattern ที่ผิดบ่อย:**
```
' ภายใน if/else block
if (เงื่อนไข?) then (ใช่)
  :ทำงาน A;
else (ไม่ใช่)
  :ทำงาน B;
endif

' ภายใน note block
note right
  **หมายเหตุ**
  รายละเอียด
end note

' ภายใน partition/group
partition "Module A" {
  :ทำงาน 1;
  :ทำงาน 2;
}
```

**Fix:** ลบ whitespace ทั้งหมดที่อยู่หน้าบรรทัด — ทุกบรรทัดต้องเริ่มที่ column 0
```
if (เงื่อนไข?) then (ใช่)
:ทำงาน A;
else (ไม่ใช่)
:ทำงาน B;
endif

note right
**หมายเหตุ**
รายละเอียด
end note
```

---

### 2. Ampersand in Thai text (Rule 2)

**สาเหตุ:** ภาษาไทยมักใช้ `&` แทน "และ" ในชื่อ field, label, business term

**Pattern ที่ผิดบ่อย:**
```
:ตรวจสอบ T&C;
:อ่าน Terms & Conditions;
:Session & Token Validation;
```

**Fix:** แทน `&` ด้วย `and` หรือ "และ"
```
:ตรวจสอบ T and C;
:อ่าน Terms and Conditions;
:Session and Token Validation;
```

---

### 3. Multi-line Action Block (Rule 4)

**สาเหตุ:** ข้อความยาว AI มักจะ wrap ให้อ่านง่าย แต่ Lark ไม่รองรับ

**Pattern ที่ผิดบ่อย:**
```
:13e. แสดง "กรุณาลองใหม่"
(เหลืออีก {N} ครั้ง);

:5. ส่ง OTP ไปยัง
เบอร์ที่ลงทะเบียน;
```

**Fix:** รวมเป็นบรรทัดเดียว ใช้ `\n` สำหรับ line break
```
:13e. แสดง "กรุณาลองใหม่\n(เหลืออีก {N} ครั้ง)";
:5. ส่ง OTP ไปยัง\nเบอร์ที่ลงทะเบียน;
```

---

### 4. Elseif Without Label (Rule 5)

**สาเหตุ:** Standard PlantUML ยอมให้ elseif ไม่มี label ได้ แต่ Lark ไม่ยอม

**Pattern ที่ผิดบ่อย:**
```
if (เลือกอะไร?) then (สมัครใหม่)
:แสดงฟอร์มสมัคร;
elseif (เปลี่ยนรหัส) then
:แสดงฟอร์มเปลี่ยนรหัส;
endif
```

**Fix:** เพิ่ม condition question ก่อน then + label หลัง then
```
if (เลือกอะไร?) then (สมัครใหม่)
:แสดงฟอร์มสมัคร;
elseif (เลือกอะไร?) then (เปลี่ยนรหัส)
:แสดงฟอร์มเปลี่ยนรหัส;
endif
```

---

### 5. Unicode Characters in Comments (Rule 7)

**สาเหตุ:** Copy/paste จาก Word หรือ Web ที่มี Unicode special characters

**Pattern ที่ผิดบ่อย:**
```
' ✓ 1. Requirement Coverage — ครบทุก FR
' → ปุ่มดำเนินการ
' ✗ Missing: ไม่มี error handling
```

**Fix:** ใช้ ASCII equivalents
```
' + 1. Requirement Coverage - ครบทุก FR
' -> ปุ่มดำเนินการ
' x Missing: ไม่มี error handling
```

---

## Auto-Fix Script

```bash
FILE="$1"
# Rule 1: Remove leading whitespace
sed -i 's/^[[:space:]]*//' "$FILE"
# Rule 2: Replace & with and
sed -i 's/&/and/g' "$FILE"
# Rule 7: Replace common Unicode
sed -i 's/✓/+/g; s/✗/x/g; s/→/->/g; s/—/-/g; s/⚠/[!]/g; s/❌/[X]/g' "$FILE"
echo "Auto-fix applied to $FILE — manually check Rule 3,4,5,6"
```

> **หมายเหตุ:** Rule 3 (start keyword), Rule 4 (single-line action), Rule 5 (elseif label), Rule 6 (legend block) ต้องแก้ manual เพราะต้องเข้าใจ context

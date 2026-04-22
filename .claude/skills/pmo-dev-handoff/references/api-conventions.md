# REST API Conventions for Dev Handoff

> **อ้างอิง ECC api-design skill** — ใช้เป็น standard เมื่อสร้าง API Spec ใน Dev Handoff Package
> Dev ที่ได้รับ Handoff ต้องทำตาม conventions นี้

---

## 1. URL Naming

```
# GOOD
GET    /api/v1/customers              # plural, kebab-case
GET    /api/v1/customers/123          # specific resource
GET    /api/v1/customers/123/orders   # nested relationship
POST   /api/v1/customers              # create
PUT    /api/v1/customers/123          # full update
PATCH  /api/v1/customers/123          # partial update
DELETE /api/v1/customers/123          # delete

# BAD
GET /api/v1/getCustomers              # verb in URL
GET /api/v1/customer                  # singular
GET /api/v1/customer_list             # snake_case
POST /api/v1/customers/create         # redundant verb
```

**Rules:**
- ใช้ **plural nouns** เสมอ (`/customers` ไม่ใช่ `/customer`)
- ใช้ **kebab-case** สำหรับ multi-word (`/team-members` ไม่ใช่ `/teamMembers`)
- **ห้ามใส่ verb** ใน URL (HTTP method บอกอยู่แล้ว)
- **Versioning** ใน URL path: `/api/v1/...`

---

## 2. Response Envelope

**ทุก API response ต้องใช้ format เดียวกัน:**

### Success Response
```json
{
  "success": true,
  "data": { ... },
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "has_next": true
  }
}
```

### Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [
      {
        "field": "email",
        "message": "Must be a valid email address",
        "code": "INVALID_FORMAT"
      }
    ]
  }
}
```

---

## 3. HTTP Status Codes

| Status | เมื่อไหร่ใช้ | ตัวอย่าง |
|:---:|---|---|
| **200** | Success (GET, PUT, PATCH, DELETE) | ดึงข้อมูลสำเร็จ, อัพเดทสำเร็จ |
| **201** | Created (POST) | สร้าง resource ใหม่สำเร็จ |
| **204** | No Content (DELETE) | ลบสำเร็จ ไม่ return body |
| **400** | Bad Request | Input validation failed |
| **401** | Unauthorized | ไม่ได้ login / token expired |
| **403** | Forbidden | Login แล้วแต่ไม่มีสิทธิ์ |
| **404** | Not Found | Resource ไม่มี |
| **409** | Conflict | Duplicate entry, version conflict |
| **422** | Unprocessable Entity | Business rule validation failed |
| **429** | Too Many Requests | Rate limit exceeded |
| **500** | Internal Server Error | Server error (ห้ามแสดง stack trace) |

---

## 4. Pagination

### Offset-Based (เหมาะกับ list ขนาดเล็ก-กลาง)
```
GET /api/v1/customers?page=2&per_page=20
```
Response meta:
```json
{
  "meta": { "page": 2, "per_page": 20, "total": 150, "total_pages": 8 }
}
```

### Cursor-Based (เหมาะกับ list ขนาดใหญ่)
```
GET /api/v1/transactions?cursor=eyJpZCI6MTIzfQ&limit=20
```
Response meta:
```json
{
  "meta": { "has_next": true, "next_cursor": "eyJpZCI6MTQzfQ" }
}
```

**เลือกแบบไหน:**
- **Offset** — ถ้า total < 10,000 records และ user ต้อง jump to page
- **Cursor** — ถ้า total > 10,000 records หรือ infinite scroll

---

## 5. Filtering & Sorting

```
GET /api/v1/customers?status=active&sort=-created_at&search=John
```

| Parameter | Description | Example |
|-----------|-------------|---------|
| `status` | Filter by field value | `?status=active` |
| `sort` | Sort (prefix `-` = DESC) | `?sort=-created_at` |
| `search` | Text search | `?search=keyword` |
| `from_date` | Date range start | `?from_date=2026-01-01` |
| `to_date` | Date range end | `?to_date=2026-03-31` |

---

## 6. Error Codes

**Error code ต้องเป็น SCREAMING_SNAKE_CASE และจัดกลุ่มตาม domain:**

| Prefix | Domain | ตัวอย่าง |
|--------|--------|---------|
| `AUTH_` | Authentication | `AUTH_TOKEN_EXPIRED`, `AUTH_WRONG_PASSWORD` |
| `VALIDATION_` | Input validation | `VALIDATION_REQUIRED_FIELD`, `VALIDATION_INVALID_EMAIL` |
| `FORBIDDEN_` | Authorization | `FORBIDDEN_NO_PERMISSION`, `FORBIDDEN_ROLE_REQUIRED` |
| `RESOURCE_` | Resource not found / conflict | `RESOURCE_NOT_FOUND`, `RESOURCE_DUPLICATE` |
| `BUSINESS_` | Business logic | `BUSINESS_INSUFFICIENT_BALANCE`, `BUSINESS_KYC_REQUIRED` |
| `SYSTEM_` | Internal error | `SYSTEM_INTERNAL_ERROR`, `SYSTEM_SERVICE_UNAVAILABLE` |

---

## วิธีใช้ใน Dev Handoff

เมื่อสร้าง API Spec ใน Step 3 ของ Handoff:
1. **URL** ต้องตาม naming rules ด้านบน
2. **Response** ต้องใช้ envelope format
3. **Error codes** ต้องใช้ prefix ตาม domain
4. **Pagination** ต้องระบุว่าใช้ offset หรือ cursor
5. **Status codes** ต้องเลือกให้ถูกตาม table

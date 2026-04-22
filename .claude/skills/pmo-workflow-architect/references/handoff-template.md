# Handoff Contract Template

> ใช้ทุกครั้งที่ workflow มีจุดที่ระบบ A ส่งต่อให้ระบบ B

## Template

```markdown
## HANDOFF: [ระบบ A] → [ระบบ B]

**Endpoint / Channel:** [API endpoint, message queue, event bus]

**Payload (ข้อมูลที่ส่ง):**
| Field | Type | คำอธิบาย |
|-------|------|---------|
| order_id | string | รหัส order |
| amount | number | จำนวนเงิน (สตางค์) |
| currency | string | สกุลเงิน (THB) |

**Success Response:**
| Field | Type | คำอธิบาย |
|-------|------|---------|
| transaction_id | string | รหัสรายการจาก B |
| status | string | "completed" |

**Failure Response:**
| Field | Type | คำอธิบาย |
|-------|------|---------|
| error | string | ข้อความ error |
| code | string | ERROR_CODE |
| retryable | boolean | ลองใหม่ได้ไหม |

**Timeout:** X วินาที
**Recovery เมื่อ Timeout:** [retry / rollback / alert admin]
```

## ตัวอย่าง: Frontend → Backend API

```markdown
## HANDOFF: Frontend App → Backend API

**Endpoint:** POST /api/v1/orders
**Payload:**
| Field | Type | คำอธิบาย |
|-------|------|---------|
| customer_id | string | รหัสลูกค้า |
| items | array | รายการสินค้า [{sku, qty, price}] |
| payment_method | string | "credit_card" / "bank_transfer" |

**Success (201):** { order_id, status: "pending", estimated_time }
**Failure (400):** { error: "Invalid items", code: "INVALID_PAYLOAD", retryable: false }
**Failure (503):** { error: "Service unavailable", code: "DOWNSTREAM_ERROR", retryable: true }
**Timeout:** 15 วินาที
**Recovery:** retry 1 ครั้ง → แสดง "ระบบไม่ตอบสนอง กรุณาลองใหม่"
```

## กฎสำคัญ

- **ทุก handoff ต้องมี timeout** — ไม่มี "รอตลอดไป"
- **ทุก handoff ต้องมี failure response** — ไม่มี "assume success"
- **ทุก failure ต้องระบุว่า retryable หรือไม่** — เพื่อ recovery ถูกต้อง

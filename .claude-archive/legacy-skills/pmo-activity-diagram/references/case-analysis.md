# Case Analysis - Detailed Categories with Examples

> Reference for `pmo-activity-diagram` skill.
> Contains 14 case categories with PlantUML syntax examples.

---

## 7.1 Happy Case (Main Success Path)

Main path where everything succeeds normally:

- User enters correct data -> system processes successfully -> shows success
- This is the primary flow - always draw first
- Every diagram must have at least 1 Happy Case path

```
:5. Submit data;

|#FFF9E0|Backend API|
:6. Validate and Save success;

|#EDF7E8|Frontend App|
:7. Display "Save successful";
```

## 7.2 Alternative Case

Valid paths different from Happy Case - user chooses another system-supported action:

- Choose different payment method (transfer vs QR vs credit card)
- Choose Approve vs Reject
- Choose Suspend vs Unlock
- Cancel and return to list (Cancel flow)
- Edit data instead of deleting

**Use `if/elseif/else` to split paths:**

```
if (Choose action?) then (Approve)
:9a. Process Approve;
elseif (What to do?) then (Reject)
:9b. Process Reject;
else (Cancel)
:9c. Return to list;
endif
```

## 7.3 Exception Case (Error Handling)

Cases where system errors or operations fail:

| Error Type | Example | Handling |
|-----------|---------|----------|
| **Validation Error** | Incomplete data, wrong format, duplicates | Show Error Message with field, allow retry |
| **Auth Error** | Expired token, no access | Redirect to Login / show "No access" |
| **Business Rule Violation** | Insufficient balance, over limit, wrong status | Show reason, suggest fix |
| **Server / API Error** | API Timeout, 500, DB Error | Show "System error, please retry", log error |
| **3rd Party Error** | Payment Gateway fail, SMS fail | Retry mechanism, Fallback, notify Admin |
| **Concurrency** | Data modified by another user | Show "Data changed, please refresh" |

```
|#FFF9E0|Backend API|
:6. Validate data;

if (Validation passed?) then (Passed)
:7. Save data;
else (Failed)
|#EDF7E8|Frontend App|
:7e. Show Error Message;
note right
**Validation Errors:**
- Name: required
- Email: invalid format
- Phone: must be 10 digits
end note
:8e. Let user fix and resubmit;
stop
endif
```

## 7.4 Edge Case

Uncommon but must-support cases:

| Type | Example |
|------|---------|
| **Empty State** | 0 records in list, search finds nothing |
| **Boundary Value** | Max/min allowed values, very long data, many decimals |
| **Duplicate Action** | Double Submit, create duplicate item |
| **Concurrent Access** | 2 admins editing same data simultaneously |
| **Session / Timeout** | Session expires during work, API Timeout |
| **Data Dependency** | Referenced data deleted/status changed |
| **Partial Success** | Batch: some succeed, some fail |
| **Large Data** | Pagination for large data, large export |

```
|#FFF9E0|Backend API|
:4. Query list;

|#EDF7E8|Frontend App|
if (Found data?) then (Found)
:5. Display list;
else (Not found)
:5e. Show Empty State;
note right
**Empty State:**
"No data found"
Show button: Clear filters
end note
stop
endif
```

## 7.5 Permission / Authorization Case

Access control cases:

- User can view but not edit (Read-only)
- User cannot access page at all
- Action requires higher Role (e.g., Super Admin only)
- Permissions changed while user is working

```
|#FFF9E0|Backend API|
:2. Check Authorization;

if (Has permission?) then (Yes)
:3. Continue;
else (No)
|#EDF7E8|Frontend App|
:3e. Show "You don't have access";
stop
endif
```

## 7.6 Confirmation / Cancellation Case

Cases requiring confirmation or cancellation:

- User clicks "Confirm" -> proceed
- User clicks "Cancel" -> return to previous page / close Modal
- User closes window (X) during work
- User clicks Back in Browser during flow

**Every Modal/Dialog with impact (delete, suspend, approve) must have Confirmation:**

```
|#EDF7E8|Frontend App|
:9. Show Confirmation Modal;
note right
**Confirmation Dialog:**
- Message: "Do you want to delete this item?"
- Buttons: [Confirm] [Cancel]
end note

|#E8F0FE|Admin|
if (Confirm?) then (Confirm)
:10. Process delete;
else (Cancel)
:10c. Close Modal, return to page;
stop
endif
```

## 7.7 Notification / Communication Case

Notification cases:

- Notify relevant users (Customer, Admin, Finance)
- Which channels (In-app, Email, SMS, Push Notification)
- Notification send fails -> Retry or Log
- Different message per case (success vs rejected)

```
|#FFF9E0|Backend API|
:14. Send Notification;
note right
**Notification:**
- **Channel:** In-app + Email
- **To:** Customer
- **Content:**
Success: "Your item has been approved"
Rejected: "Item rejected. Reason: {reason}"
- **Retry:** 3 times if send fails
end note
```

## 7.8 Audit / Logging Case

Every important action must record Audit Log:

- Who (Admin ID / User ID) did what
- When (Timestamp)
- Before/After State
- IP Address / Device Info (if needed)

```
|#FFF9E0|Backend API|
:15. Log Activity;
note right
**Audit Log:**
- Action: "Suspend Customer"
- Performed by: Admin #{admin_id}
- Target: Customer #{customer_id}
- Before: Active -> After: Suspended
- Reason: "{reason}"
- Timestamp: {datetime}
end note
```

## 7.9 Rollback / Undo Case

Cases needing rollback:

- Undo recent action (e.g., Unsuspend after Suspend)
- Rollback when transaction fails midway
- Revert status when 3rd Party responds with failure

```
|#FFF9E0|Backend API|
:12. Process Transaction;

if (All successful?) then (Success)
:13. Commit Transaction;
else (Partial failure)
:13e. Rollback Transaction;
note right
**Rollback:**
- Restore original state for all steps
- Refund money (if deducted)
- Log error for investigation
end note
:14e. Notify Admin to investigate;
stop
endif
```

## 7.10 State Transition Case

Entity status change cases:

- All statuses transition correctly per business rules?
- Any dead state (entered but can't exit)?
- What conditions for each status change?
- Who has permission to change which status?

```
note right
**State Transition:**
- Pending -> Approved (by Admin)
- Pending -> Rejected (by Admin)
- Approved -> Completed (by System)
- Rejected -> [X] (terminal state)
- [!] Verify no dead states exist
end note
```

## 7.11 Cross-Module / Cross-Platform Case

Cases where flow impacts other modules or platforms:

- Does this flow affect other modules in the same project?
- If project has multiple platforms (e.g., BOF + CS App), does this flow affect other platforms?
- Does BOF config affect CS App?

```
note right
**Cross-Platform Impact:**
- BOF Feature Toggle -> CS App must show/hide buttons accordingly
- BOF Transaction Limit -> CS App must limit amounts accordingly
- BOF Customer Suspend -> CS App must block immediately
end note
```

## 7.12 Data Integrity Case

Data correctness cases:

- Balance / stock consistent after operation completes?
- If money/stock deducted and operation fails, how to refund?
- Is there data reconciliation?

```
note right
**Data Integrity Check:**
- Balance before - fee - purchase amount = Balance after
- Stock before - sold quantity = Stock after
- [!] Must reconcile daily
end note
```

## 7.13 Regulatory Compliance Case

Legal requirement cases:

- Need compliance steps? (PDPA consent, KYC verification, AML screening)
- What data must be stored by law? For how long?
- Any data retention / deletion policy?

```
note right
**Regulatory Compliance:**
- PDPA: Must get consent before collecting personal data
- KYC: Must verify identity before transactions
- AML: Must report suspicious transactions
- Data Retention: Keep transaction data 10 years
end note
```

## 7.14 Multi-Device / Multi-Session Case

Cases where user uses multiple devices or sessions simultaneously:

- If user logs in from multiple devices, how to handle?
- If transaction from device A, does device B see correct state?
- Session management policy?

```
note right
**Multi-Device/Session:**
- Single session only? Or allow multiple sessions?
- Real-time sync between devices?
- Force logout old device on new login?
end note
```

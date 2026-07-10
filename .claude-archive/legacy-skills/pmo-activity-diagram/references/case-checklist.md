# Case Analysis Checklist (20 Items)

> Reference for `pmo-activity-diagram` skill.
> Use this checklist before creating every Activity Diagram.

---

## 20-Item Checklist

| # | Category | Question | Required |
|---|---------|---------|----------|
| 1 | **Happy Case** | Main success path complete? | Always |
| 2 | **Alternative Case** | Other valid paths the user can take? | If applicable |
| 3 | **Validation Error** | What happens if data is wrong/incomplete? | If has Form |
| 4 | **API / Server Error** | What if Backend fails? | Always |
| 5 | **3rd Party Error** | What if external system fails? | If calls 3rd Party |
| 6 | **Permission** | All Roles can access? Where to check permissions? | Always |
| 7 | **Empty State** | What to show with no data? | If has List/Table |
| 8 | **Confirmation** | Which actions need confirmation? What if cancelled? | If has impactful Action |
| 9 | **Duplicate / Idempotent** | What if done twice? Need Double Submit prevention? | If has Submit |
| 10 | **Concurrent Access** | What if multiple people do it simultaneously? | Context-dependent |
| 11 | **Notification** | Who to notify? Which channel? When? | If affects others |
| 12 | **Audit Log** | Does this action need logging? What to log? | For important Actions |
| 13 | **Rollback / Undo** | If fails midway, need Rollback? Can Undo? | If multi-step Transaction |
| 14 | **Timeout / Session** | What if Session expires during work? | Context-dependent |
| 15 | **Large Data / Pagination** | What if data is very large? | If has List/Table |
| 16 | **State Transition** | All statuses transition correctly? Any dead states? | If entity has status |
| 17 | **Cross-Module / Cross-Platform** | Does this flow affect other modules/platforms? | If multi-module/platform project |
| 18 | **Data Integrity** | Balance/stock consistent after operation? | If involves financial data |
| 19 | **Regulatory Compliance** | Need compliance steps? (PDPA, KYC, AML) | If regulated industry |
| 20 | **Multi-Device / Multi-Session** | What if user uses multiple devices simultaneously? | If user-facing app |

---

## Grouping Cases in Diagrams

When a flow has many cases, organize systematically:

### Use Section Comments to Group

```
' --- Happy Case: Create Order ---
' --- Alternative Case: Cancel Order ---
' --- Exception Case: Payment Failed ---
```

### Split Sub-diagrams by Case Type (if very complex)

- **Module X-A:** Happy Case (Main Flow)
- **Module X-B:** Alternative Cases
- **Module X-C:** Exception and Error Handling
- **Module X-D:** Edge Cases and Special Scenarios

### Use Note to Summarize Cases Covered

At the end of diagram, add summary note (as Lark-safe comments):

```
' Cases Covered (XX-X):
' + Happy Case: Created item successfully
' + Alt Case: Cancelled during creation
' + Alt Case: Chose different payment method
' + Exception: Validation Error
' + Exception: Payment Gateway failed
' + Edge Case: Double Submit
' + Edge Case: Session Timeout
```

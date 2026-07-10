# Industry Implicit Requirements and Cross-Platform Dependencies

> Reference for `pmo-traceability` skill.
> Check these before creating first diagram of every project.

---

## Industry Implicit Requirements Checklist

> Before creating the first diagram for any project, check the industry-specific checklist to identify requirements the client may not have stated but the system must have.

**Procedure:**
1. Identify the project's industry type
2. Check the checklist below for matching type
3. Report to user for decision: add / don't add / ask client first
4. **Never add to diagram without user confirmation**

### FinTech / Financial / Asset Trading

| # | Implicit Requirement | Why needed | Example |
|---|---------------------|-----------|---------|
| 1 | **PDPA / Data Privacy** | PDPA law requires it | Consent flow, right to delete data, data retention policy |
| 2 | **KYC / AML** | Anti-money laundering law | Identity verification, suspicious transaction reporting |
| 3 | **Fraud Prevention** | Financial standard | Velocity limit, anomaly detection, IP/device tracking |
| 4 | **Reconciliation** | Financial accuracy | Reconcile balance/stock/transactions daily |
| 5 | **T&C / Legal Documents** | Legal requirement | Terms acceptance flow + version management |
| 6 | **Audit Trail** | Compliance + investigation | Log every action related to money/assets |
| 7 | **Transaction Limits** | Risk prevention | Daily/Monthly limit, single transaction limit |
| 8 | **Refund / Reversal Flow** | Customer protection | Refund steps, error transaction handling |

### E-Commerce / Marketplace

| # | Implicit Requirement | Why needed |
|---|---------------------|-----------|
| 1 | **Payment Security** | PCI-DSS compliance |
| 2 | **Refund / Return Policy** | Consumer protection law |
| 3 | **Order Status Tracking** | Customer experience |
| 4 | **Inventory Sync** | Prevent oversell |
| 5 | **Notification System** | Order confirmation, shipping update |

### Healthcare / Medical

| # | Implicit Requirement | Why needed |
|---|---------------------|-----------|
| 1 | **HIPAA / Health Data Privacy** | Health data protection law |
| 2 | **Patient Consent** | Must get consent before data access |
| 3 | **Medical Data Retention** | Must store data per legally required duration |
| 4 | **Access Control (Role-based)** | Doctor/Nurse/Admin access different data |

> **Note:** If project doesn't match any type above, ask user about any special regulatory requirements.

---

## Cross-Platform Dependency Checklist

> When project has multiple platforms (e.g., Back Office + Customer App + Admin Portal), check connections between platforms before designing.

| # | Dependency Type | Question to Answer | Example |
|---|----------------|-------------------|---------|
| 1 | **Feature Toggle** | Platform A enables/disables feature -> how does Platform B react? | BOF disables gold buying -> CS App must hide buy button |
| 2 | **Config / Limits** | Config set in Platform A -> does Platform B use same value? | BOF sets Transaction Limit -> CS App limits amounts accordingly |
| 3 | **User State** | User status change in Platform A -> affects Platform B? | BOF Suspends Customer -> CS App blocks immediately |
| 4 | **Data Sync** | Data created/modified in Platform A -> Platform B sees it immediately? | BOF changes gold price -> CS App shows new price real-time |
| 5 | **Notification** | Event in Platform A -> must notify Platform B? | BOF Approves Withdraw -> CS App notifies Customer |
| 6 | **Shared Resources** | Do Platform A and B share resources? | BOF + CS App share Gold Stock |

**Procedure:**
1. Identify how many platforms the project has and what they are
2. Create dependency mapping table per checklist above
3. Add dependencies as notes in related diagrams
4. Flag points needing additional client clarification

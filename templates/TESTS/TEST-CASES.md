# TEST-CASES - <PROJECT_NAME>

> Status: specified
> Mode: <MODE>
> Derived Target Cases: <COUNT>

## Test Cases Inventory

| Case ID | Category | Target Type | Target ID | Description | Preconditions | Input / Action | Expected Result | Pass Criteria | Strict Trigger | Source Ref | Evidence Status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| TC-001 | happy_path | requirement | REQ-001 | Verify successful user login with valid credentials | User account is active and verified | Submit valid username and password | User session created and redirected to dashboard | HTTP 200 and session token issued | none | MOM-20260710 item-1 | supported |
| TC-002 | negative | requirement | REQ-001 | Verify rejection on invalid credentials | User account exists | Submit incorrect password | Authentication rejected with 401 error | HTTP 401 and error message displayed | auth | MOM-20260710 item-1 | supported |

# Security

## Sensitive Data

Do not commit:

- `.env` files
- private keys
- credentials
- tokens
- customer confidential source
- raw PII
- pricing or quotation files unless explicitly approved

## AI Handling

Strict mode is required for:

- payment
- financial calculation
- PII
- sensitive customer data
- authentication
- authorization
- permission
- external integration
- compliance
- production migration

AI must not:

- push
- tag
- deploy
- approve production
- approve business scope

These actions require explicit human confirmation.

## Validation Scope

`validate-project.ps1` includes a sensitive file pre-check, not a full security scan.

Strict projects still need separate manual security/privacy review.


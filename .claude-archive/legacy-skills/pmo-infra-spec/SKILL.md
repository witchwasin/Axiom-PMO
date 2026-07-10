---
name: Infrastructure Spec
description: สร้าง Infrastructure Specification Document สำหรับ DevOps handoff — Docker, server requirements, scaling plan, cost estimation
---

# PMO Skill: Infrastructure Spec

> **Purpose:** สร้าง "Handoff Document สำหรับ DevOps" เหมือนที่ `pmo-dev-handoff` สร้างสำหรับ Dev
> ครอบคลุม server spec, Docker config, scaling strategy, estimated cost

---

## 1. Prerequisites

- Tech stack info (language, framework, DB)
- Expected traffic / user count (ถาม user ถ้ายังไม่มี)
- Budget range (ถ้า user ต้องการ cost estimation)

---

## 2. Document Template

สร้างไฟล์ `{ProjectFolder}/Scaffold/INFRA-SPEC.md`:

### 2.1 Architecture Overview

```
┌─────────────┐     ┌──────────────┐     ┌───────────────┐
│   Client     │────>│  Load Balancer│────>│  App Server(s)│
│  (Browser/   │     │  (Nginx/ALB) │     │  (Docker)     │
│   Mobile)    │     └──────────────┘     └───────┬───────┘
└─────────────┘                                   │
                                          ┌───────┴───────┐
                                          │   Database     │
                                          │  (PostgreSQL)  │
                                          └───────────────┘
```

### 2.2 Server Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **App Server** | 2 vCPU, 4GB RAM | 4 vCPU, 8GB RAM | Per instance |
| **Database** | 2 vCPU, 4GB RAM, 50GB SSD | 4 vCPU, 8GB RAM, 100GB SSD | Managed preferred |
| **Cache** | 1GB Redis | 2GB Redis | Optional for MVP |
| **Storage** | 20GB | 50GB | File uploads |

### 2.3 Docker Configuration

```yaml
# docker-compose.production.yml
version: '3.8'
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: postgres:16
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      - POSTGRES_PASSWORD=${DB_PASSWORD}

  redis:
    image: redis:7-alpine
    command: redis-server --maxmemory 256mb

volumes:
  pgdata:
```

### 2.4 Scaling Strategy

| Traffic Level | Strategy | Infra |
|--------------|----------|-------|
| **MVP** (< 100 users) | Single server | 1 app + 1 DB |
| **Growth** (100-1K users) | Horizontal scale | 2 app + 1 DB + Redis |
| **Scale** (1K-10K users) | Load balanced | 3+ app + DB read replica + Redis cluster |
| **Enterprise** (10K+ users) | Auto-scaling | K8s cluster + managed DB + CDN |

### 2.5 Cloud Provider Options

| Provider | Service | Estimated Monthly Cost (MVP) |
|----------|---------|----------------------------|
| **AWS** | ECS Fargate + RDS | $50-150 |
| **GCP** | Cloud Run + Cloud SQL | $40-120 |
| **Vercel + Supabase** | Serverless | $25-80 |
| **Railway** | Managed containers | $20-60 |
| **DigitalOcean** | Droplet + Managed DB | $30-80 |

### 2.6 Backup & Recovery

| Item | Strategy | Frequency |
|------|----------|-----------|
| **Database** | Automated snapshot | Daily + before migration |
| **File Storage** | Cross-region replication | Real-time |
| **Application Config** | Git versioned | Every change |
| **Recovery RTO** | < 1 hour | - |
| **Recovery RPO** | < 24 hours | - |

---

## 3. Workflow

1. **ถาม** expected traffic + budget range
2. **อ่าน** Dev Handoff Package (tech stack, modules, data model)
3. **Generate** INFRA-SPEC.md ตาม template
4. **Customize** ตาม project needs (ถ้า project มี file upload = เพิ่ม storage)
5. **Log** Activity Log
6. **แจ้ง user** สรุป + cloud provider recommendation

---

## 4. Output Location

`{ProjectFolder}/Scaffold/INFRA-SPEC.md` (AI-Managed)

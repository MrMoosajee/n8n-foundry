# 🏭 FOUNDRY v3.0 - COMPLETE SETUP GUIDE
## From Empty n8n → 60+ Worker Autonomous Swarm

**Target:** Solo AI Startup | South African Market  
**Status:** Phase 1 Implementation  
**Date:** 2026-02-04  

---

## 📋 PREREQUISITES

### Hardware
- ✅ Dell 3520 (Intel i3, 32GB RAM) - Current setup
- ✅ Pop!_OS (Linux) - Current OS
- ✅ Docker & Docker Compose installed

### Software
- ✅ n8n (Docker-based) - Currently empty instance
- ✅ PostgreSQL 14+ (via Docker)
- ❌ Ollama (needs installation for local models)
- ❌ ChromaDB (future phases)

### API Keys (Free Tier)
- ✅ Google Gemini API Key (get from: https://aistudio.google.com/app/apikey)
- ✅ Groq API Key (get from: https://console.groq.com/keys)

---

## ⚡ QUICK START (30 Minutes)

### Step 1: Deploy Database Schema (5 min)

```bash
# Navigate to project directory
cd /path/to/foundry

# Copy the v3.0 schema
cp foundry_v3_init_db.sql /tmp/

# Deploy to existing Postgres container
docker exec -i foundry_db psql -U foundry -d foundry < /tmp/foundry_v3_init_db.sql

# Verify deployment
docker exec -it foundry_db psql -U foundry -d foundry -c "
SELECT 
    'v3.0 Schema Deployed' as status,
    (SELECT COUNT(*) FROM foundry_departments) as departments,
    (SELECT COUNT(*) FROM foundry_cto_approvals WHERE status = 'pending') as pending_approvals;
"
```

**Expected Output:**
```
       status        | departments | pending_approvals
--------------------+-------------+-------------------
 v3.0 Schema Deployed|          11 |                 1
```

---

### Step 2: Configure n8n Credentials (10 min)

Open n8n: `http://localhost:5678`

#### A. Google Gemini API

1. Navigate to: **Settings** → **Credentials**
2. Click **Add Credential**
3. Search: **"Google API"** (use generic Google API, not Gemini-specific)
4. Configure:
   - **Name:** `Foundry Gemini Pro`
   - **Authentication:** API Key
   - **API Key:** `AIza...` (your Gemini key)
5. Click **Save**

#### B. Groq API (Llama 3.3)

1. Click **Add Credential**
2. Search: **"Header Auth"**
3. Configure:
   - **Name:** `Foundry Groq`
   - **Header Name:** `Authorization`
   - **Header Value:** `Bearer gsk_...` (your full Groq key with "Bearer " prefix)
4. Click **Save**

#### C. PostgreSQL (Already configured from v2.1)

If not present:
1. Click **Add Credential**
2. Search: **"Postgres"**
3. Configure:
   - **Name:** `Foundry DB`
   - **Host:** `foundry_db` (Docker service name)
   - **Database:** `foundry`
   - **User:** `foundry`
   - **Password:** `m4aucaJZWMv6J1FXtRA0StNH` (from docker-compose.yml)
   - **Port:** `5432`
   - **SSL:** `disable`
4. **Test Connection** → Should succeed
5. Click **Save**

---

### Step 3: Import Prompt Master Workflow (5 min)

1. In n8n, click **Workflows** → **Import from File**
2. Select: `foundry_v3_prompt_master_workflow.json`
3. Click **Import**

#### Link Credentials

After import, n8n will show credential warnings. Fix:

1. Click **"Gemini: Generate MRS"** node
   - Credentials dropdown → Select **"Foundry Gemini Pro"**
   - Save

2. Click **ALL Postgres nodes** (there are 6):
   - `Store MRS in Postgres`
   - `Log Schema Violation`
   - `Escalate to CTO`
   - `Request CTO Approval`
   - `Add to Job Queue`
   
   For each:
   - Credentials dropdown → Select **"Foundry DB"**
   - Save

3. **Save Workflow** (Ctrl+S / Cmd+S)

4. **Activate Workflow** (toggle switch to ON)

---

### Step 4: Test Prompt Master (5 min)

#### Test via curl:

```bash
# Get the webhook URL from n8n (click on Webhook Trigger node)
# It should be: http://localhost:5678/webhook/prompt-master

curl -X POST http://localhost:5678/webhook/prompt-master \
  -H "Content-Type: application/json" \
  -d '{
    "request": "Build a REST API for managing customer appointments in a hair salon. Needs SMS reminders and calendar integration.",
    "priority": 5,
    "context": "For a small salon in Johannesburg. Must work during load-shedding."
  }'
```

#### Expected Response:

```json
{
  "success": true,
  "mrs_id": 1,
  "job_id": 1,
  "status": "queued",
  "assigned_department": "software_development",
  "priority": 5,
  "message": "Job added to queue. Processing will begin automatically."
}
```

#### Verify in Database:

```bash
docker exec -it foundry_db psql -U foundry -d foundry
```

```sql
-- Check MRS was created
SELECT id, goal, required_team, estimated_complexity, schema_valid 
FROM foundry_mrs 
ORDER BY id DESC 
LIMIT 1;

-- Check job was queued
SELECT id, job_type, assigned_department, status, priority 
FROM foundry_job_queue 
ORDER BY id DESC 
LIMIT 1;
```

**Expected:** Both queries return 1 row with your test data.

---

### Step 5: Install Ollama for Local Models (5 min)

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Pull required models (this will take 10-30 minutes)
ollama pull qwen2.5-coder:14b
ollama pull phi4:14b
ollama pull glm-4-flash
ollama pull llama3.2:3b

# Verify installation
ollama list
```

**Expected Output:**
```
NAME                    SIZE    MODIFIED
qwen2.5-coder:14b      8.3 GB  2 minutes ago
phi4:14b               8.1 GB  5 minutes ago
glm-4-flash            2.7 GB  7 minutes ago
llama3.2:3b            2.0 GB  9 minutes ago
```

---

## 🎯 NEXT STEPS: Deploy Department Workflows

Now that the foundation is ready, you'll deploy the 11 department lead workflows. I'm creating the first one as a template.

### The 11 Departments:

1. ✅ **Prompt Master** (Deployed above) - Translation layer
2. ⏳ **Software Development** - Code generation (creating next)
3. ⏳ **Technical Architecture** - System design
4. ⏳ **Creative & Social** - Brand building
5. ⏳ **Code Review** - Quality & security
6. ⏳ **Reliability Engineering** - Error handling
7. ⏳ **Systems Architecture** - Infrastructure
8. ⏳ **IT Operations** - Local environment
9. ⏳ **Git Management** - Version control
10. ⏳ **Executive Admin** - Scheduling & logging
11. ⏳ **Brand Strategy** - Client proposals
12. ⏳ **Documentation** - PRDs & wikis

---

## 🛡️ ZERO-DRIFT MONITORING

The system automatically monitors for schema drift. Check drift incidents:

```sql
-- Real-time drift alerts
SELECT * FROM v_drift_alerts;

-- All schema violations
SELECT 
    agent_name,
    department_name,
    violation_type,
    severity,
    detected_at,
    remediation_status
FROM v_drift_alerts
WHERE detected_at > NOW() - INTERVAL '24 hours'
ORDER BY severity DESC, detected_at DESC;
```

---

## 📊 MONITORING DASHBOARD

### Swarm Health

```sql
-- Check all departments and agents
SELECT * FROM v_swarm_health;

-- Job queue status
SELECT * FROM v_job_queue_summary;

-- Agent performance
SELECT 
    a.agent_name,
    d.department_name,
    a.total_jobs_completed,
    a.error_rate,
    a.status,
    a.capacity - a.current_load as available_capacity
FROM foundry_agents a
JOIN foundry_departments d ON d.id = a.department_id
ORDER BY a.total_jobs_completed DESC
LIMIT 20;
```

---

## 🚨 TROUBLESHOOTING

### Issue: Webhook not responding

**Fix:**
1. Check n8n logs: `docker logs n8n --tail 100`
2. Verify workflow is **activated** (toggle ON)
3. Check webhook URL in browser: `http://localhost:5678/webhook/prompt-master`
   - Should return: "This is a webhook endpoint. Use POST to trigger."

### Issue: "Schema drift detected"

**This is WORKING AS INTENDED.** The system is protecting you from invalid output.

**Action:**
1. Check escalation: `SELECT * FROM foundry_error_escalations ORDER BY created_at DESC LIMIT 1;`
2. Review the validation errors
3. If Gemini is consistently failing, the prompt needs refinement
4. Contact Claude (me) with the error details for prompt tuning

### Issue: Database connection errors

**Fix:**
```bash
# Restart Postgres
docker-compose restart foundry_db

# Verify it's running
docker exec foundry_db pg_isready -U foundry

# Test connection from n8n
docker exec n8n nc -zv foundry_db 5432
```

---

## 🔐 CTO APPROVAL WORKFLOW

For high-priority jobs (priority 1-3) or extreme complexity:

### 1. Check Pending Approvals

```sql
SELECT 
    id,
    approval_type,
    request_data->>'goal' as goal,
    approval_token,
    requested_at
FROM foundry_cto_approvals
WHERE status = 'pending'
ORDER BY requested_at ASC;
```

### 2. Approve via CLI

```bash
# Approve a job
docker exec -it foundry_db psql -U foundry -d foundry -c "
UPDATE foundry_cto_approvals 
SET status = 'approved', 
    reviewed_at = NOW(), 
    review_notes = 'Approved by CTO' 
WHERE approval_token = 'FOUNDRY_APPROVAL_XXX';
"

# Then update the job status
docker exec -it foundry_db psql -U foundry -d foundry -c "
UPDATE foundry_job_queue 
SET status = 'queued' 
WHERE status = 'awaiting_cto_approval' 
  AND id = (SELECT id FROM foundry_job_queue WHERE status = 'awaiting_cto_approval' ORDER BY created_at ASC LIMIT 1);
"
```

### 3. Reject a Job

```bash
docker exec -it foundry_db psql -U foundry -d foundry -c "
UPDATE foundry_cto_approvals 
SET status = 'rejected', 
    reviewed_at = NOW(), 
    review_notes = 'Project scope too large' 
WHERE approval_token = 'FOUNDRY_APPROVAL_XXX';
"
```

---

## 📈 SCALING TO 60+ WORKERS

After deploying all 11 department leads, you'll have:

- **11 Lead agents** (1 per department)
- **49 Senior/Worker agents** (4-6 per department)
- **Total: 60 agents**

Each agent is registered in the `foundry_agents` table and can process jobs concurrently.

**Current Status:** Foundation deployed ✅  
**Next:** Deploy department workflows (in progress)

---

## 💾 BACKUP & RECOVERY

### Backup Database

```bash
# Full backup
docker exec foundry_db pg_dump -U foundry foundry > foundry_backup_$(date +%Y%m%d).sql

# Backup to compressed file
docker exec foundry_db pg_dump -U foundry foundry | gzip > foundry_backup_$(date +%Y%m%d).sql.gz
```

### Restore Database

```bash
# Stop n8n to prevent conflicts
docker-compose stop n8n

# Restore
gunzip < foundry_backup_20260204.sql.gz | docker exec -i foundry_db psql -U foundry -d foundry

# Restart n8n
docker-compose start n8n
```

---

## 🎓 UNDERSTANDING THE ARCHITECTURE

```
CTO Request
    ↓
Prompt Master (Gemini 1.5 Pro)
    ↓
MRS Validation (Zero-Drift Check)
    ↓
Job Queue (Postgres)
    ↓
Department Assignment
    ↓
Lead Agent (Cloud or Local model)
    ↓
Worker Agents (4-6 per dept, mostly local Ollama)
    ↓
Artifacts stored → Ready for next phase
```

**Key Principle:** Every step is logged, every output is validated, CTO has final control.

---

## ✅ SETUP COMPLETE

You now have:
- ✅ Enhanced v3.0 database schema (11 departments, 60+ agent capacity)
- ✅ Prompt Master workflow (MRS generation with zero-drift enforcement)
- ✅ CTO approval gates (for high-priority work)
- ✅ Full audit trail (every action logged)
- ✅ Ollama ready (for local model deployment)

**Next:** I'll create the first Department Lead workflow (Software Development) as a template for the other 10.

---

🏭 **"FROM EMPTY N8N TO AUTONOMOUS SWARM IN 30 MINUTES"**

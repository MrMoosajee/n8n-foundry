-- ================================================================
-- FOUNDRY v3.0 DATABASE INITIALIZATION
-- 60+ Worker Swarm - Enhanced Schema for Complete State Management
-- ================================================================
-- Date: 2026-02-04
-- Purpose: Foundation for Pentad Council → 11 Departments → 60+ Workers
-- Lead Architect: Claude Sonnet 4.5
-- ================================================================

-- ----------------------------------------------------------------
-- CORE PROJECT TABLES (Foundational)
-- ----------------------------------------------------------------

-- Main projects table (stores MRS + Stack Decision - from v2.1 init_db.sql)
CREATE TABLE IF NOT EXISTS foundry_projects (
    id SERIAL PRIMARY KEY,
    project_name VARCHAR(255) NOT NULL,
    description TEXT,
    mrs_data JSONB NOT NULL,
    stack_decision JSONB,
    status VARCHAR(50) DEFAULT 'intake',
    priority INTEGER DEFAULT 5,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP
);

-- Indexes for performance
DROP INDEX IF EXISTS idx_project_status;
CREATE INDEX IF NOT EXISTS idx_project_status ON foundry_projects(status);
DROP INDEX IF EXISTS idx_project_priority;
CREATE INDEX IF NOT EXISTS idx_project_priority ON foundry_projects(priority DESC);
DROP INDEX IF EXISTS idx_created_at;
CREATE INDEX IF NOT EXISTS idx_created_at ON foundry_projects(created_at DESC);

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_foundry_projects_updated_at ON foundry_projects;
DROP FUNCTION IF EXISTS update_updated_at_column();
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_foundry_projects_updated_at
    BEFORE UPDATE ON foundry_projects
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------

-- ----------------------------------------------------------------
-- GOVERNANCE LAYER: PENTAD COUNCIL & CTO APPROVALS
-- ----------------------------------------------------------------

-- CTO approval gates for critical decisions
CREATE TABLE IF NOT EXISTS foundry_cto_approvals (
    id SERIAL PRIMARY KEY,
    approval_type VARCHAR(50) NOT NULL, -- 'project_start', 'budget_approval', 'tech_stack', 'deployment'
    request_data JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'escalated'
    requested_by VARCHAR(100) NOT NULL, -- agent_role that requested approval
    requested_at TIMESTAMP DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    review_notes TEXT,
    approval_token VARCHAR(255) UNIQUE -- for CLI-based approval
);

DROP INDEX IF EXISTS idx_cto_approval_status;
CREATE INDEX idx_cto_approval_status ON foundry_cto_approvals(status);
DROP INDEX IF EXISTS idx_cto_approval_type;
CREATE INDEX idx_cto_approval_type ON foundry_cto_approvals(approval_type);

-- Pentad Council voting records
CREATE TABLE IF NOT EXISTS foundry_pentad_votes (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    council_member VARCHAR(50) NOT NULL, -- 'strategy_chief', 'security_chief', 'quality_chief', 'resource_chief', 'customer_chief'
    vote VARCHAR(20) NOT NULL, -- 'approve', 'reject', 'abstain', 'needs_info'
    vote_weight INTEGER DEFAULT 1, -- Strategy & Security Chiefs have 2x weight
    reasoning TEXT NOT NULL,
    risk_score DECIMAL(3,2), -- 0.00 to 10.00
    model_used VARCHAR(100),
    voted_at TIMESTAMP DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_pentad_project;
CREATE INDEX idx_pentad_project ON foundry_pentad_votes(project_id);
DROP INDEX IF EXISTS idx_pentad_member;
CREATE INDEX idx_pentad_member ON foundry_pentad_votes(council_member);

-- ----------------------------------------------------------------
-- MANAGEMENT LAYER: PM & SCRUM MASTER STATE
-- ----------------------------------------------------------------

-- Job queue managed by n8n PM
CREATE TABLE IF NOT EXISTS foundry_job_queue (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    job_type VARCHAR(100) NOT NULL, -- 'code_generation', 'architecture_review', 'documentation', etc.
    assigned_department VARCHAR(100), -- Maps to one of 11 departments
    assigned_lead VARCHAR(100), -- Specific lead agent
    priority INTEGER DEFAULT 5, -- 1 (urgent) to 10 (low)
    status VARCHAR(50) DEFAULT 'queued', -- 'queued', 'assigned', 'in_progress', 'blocked', 'completed', 'failed'
    input_data JSONB NOT NULL,
    output_data JSONB,
    dependencies JSONB, -- Array of job_ids that must complete first
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    created_at TIMESTAMP DEFAULT NOW(),
    assigned_at TIMESTAMP,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT
);

DROP INDEX IF EXISTS idx_job_status;
CREATE INDEX idx_job_status ON foundry_job_queue(status);
DROP INDEX IF EXISTS idx_job_priority;
CREATE INDEX idx_job_priority ON foundry_job_queue(priority DESC, created_at ASC);
DROP INDEX IF EXISTS idx_job_project;
CREATE INDEX idx_job_project ON foundry_job_queue(project_id);
DROP INDEX IF EXISTS idx_job_department;
CREATE INDEX idx_job_department ON foundry_job_queue(assigned_department);

-- Sprint tracking for Scrum Master
CREATE TABLE IF NOT EXISTS foundry_sprints (
    id SERIAL PRIMARY KEY,
    sprint_name VARCHAR(100) NOT NULL,
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'planning', -- 'planning', 'active', 'review', 'completed'
    velocity_target INTEGER, -- Target story points
    velocity_actual INTEGER, -- Actual completed points
    created_at TIMESTAMP DEFAULT NOW()
);

-- Sprint-Job relationship
CREATE TABLE IF NOT EXISTS foundry_sprint_jobs (
    sprint_id INTEGER REFERENCES foundry_sprints(id) ON DELETE CASCADE,
    job_id INTEGER REFERENCES foundry_job_queue(id) ON DELETE CASCADE,
    story_points INTEGER DEFAULT 1,
    PRIMARY KEY (sprint_id, job_id)
);

-- ----------------------------------------------------------------
-- PROMPT MASTER: MRS GENERATION & VALIDATION
-- ----------------------------------------------------------------

-- Machine Readable Specs (MRS) tracking
CREATE TABLE IF NOT EXISTS foundry_mrs (
    id SERIAL PRIMARY KEY,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    raw_input TEXT NOT NULL, -- Original human-speak request
    mrs_version INTEGER DEFAULT 1,
    goal TEXT NOT NULL,
    constraints JSONB NOT NULL, -- Array of constraint objects
    priority_score INTEGER NOT NULL CHECK (priority_score BETWEEN 1 AND 10),
    required_team VARCHAR(100) NOT NULL, -- Maps to department
    target_format VARCHAR(100), -- 'code', 'document', 'design', 'report'
    estimated_complexity VARCHAR(20), -- 'low', 'medium', 'high', 'extreme'
    schema_valid BOOLEAN DEFAULT TRUE,
    validation_errors JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    approved_by_cto BOOLEAN DEFAULT FALSE
);

DROP INDEX IF EXISTS idx_mrs_project;
CREATE INDEX idx_mrs_project ON foundry_mrs(project_id);
DROP INDEX IF EXISTS idx_mrs_team;
CREATE INDEX idx_mrs_team ON foundry_mrs(required_team);
DROP INDEX IF EXISTS idx_mrs_priority;
CREATE INDEX idx_mrs_priority ON foundry_mrs(priority_score DESC);

-- ----------------------------------------------------------------
-- DEPARTMENT LAYER: 11 LEADS + WORKERS
-- ----------------------------------------------------------------

-- Department registry
CREATE TABLE IF NOT EXISTS foundry_departments (
    id SERIAL PRIMARY KEY,
    department_name VARCHAR(100) UNIQUE NOT NULL,
    lead_agent VARCHAR(100) NOT NULL,
    description TEXT,
    primary_model VARCHAR(100), -- e.g., 'qwen2.5-coder:14b'
    backup_model VARCHAR(100),
    worker_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Seed the 11 departments
INSERT INTO foundry_departments (department_name, lead_agent, description, primary_model, worker_count) VALUES
('software_development', 'Lead Software Developer', 'High-logic code generation and implementation', 'qwen2.5-coder:14b', 6),
('technical_architecture', 'Senior Technical Architect', 'System design, repo structure, tech stack decisions', 'qwen2.5-coder:14b', 5),
('creative_social', 'Creative Director', 'Brand building, social media, SA market positioning', 'gemini-1.5-pro', 4),
('code_review', 'Code Reviewer', 'Syntax auditing, security scanning, quality assurance', 'glm-4-flash', 5),
('reliability_engineering', 'Senior Reliability Engineer', 'Error handling, drift monitoring, uptime optimization', 'phi-4:14b', 5),
('systems_architecture', 'Lead Systems Architect', 'Cloud/local infrastructure, Docker, Kubernetes', 'qwen2.5-coder:14b', 4),
('it_operations', 'Lead IT Engineer', 'Pop!_OS maintenance, local environment management', 'phi-4:14b', 4),
('git_management', 'Lead Git Engineer', 'Repository ownership, branch strategy, CI/CD', 'qwen2.5-coder:14b', 4),
('executive_admin', 'Executive Secretary', 'Logging, scheduling, meeting management', 'llama-3.2:3b', 6),
('brand_strategy', 'Personal Brand Strategist', 'Client proposals, ghostwriting, SA market pitches', 'gemini-1.5-pro', 5),
('documentation', 'Chief Documentation Officer', 'PRDs, technical wikis, user guides', 'llama-3.2:3b', 6)
ON CONFLICT (department_name) DO NOTHING;

-- Agent registry (60+ workers)
CREATE TABLE IF NOT EXISTS foundry_agents (
    id SERIAL PRIMARY KEY,
    agent_name VARCHAR(100) UNIQUE NOT NULL,
    agent_role VARCHAR(100) NOT NULL, -- 'lead', 'senior_worker', 'worker', 'junior_worker'
    department_id INTEGER REFERENCES foundry_departments(id) ON DELETE CASCADE,
    model_primary VARCHAR(100) NOT NULL,
    model_fallback VARCHAR(100),
    specialization TEXT, -- e.g., 'Python FastAPI', 'React Components', 'SQL Optimization'
    capacity INTEGER DEFAULT 3, -- Max concurrent jobs
    current_load INTEGER DEFAULT 0,
    status VARCHAR(20) DEFAULT 'idle', -- 'idle', 'busy', 'offline', 'error'
    total_jobs_completed INTEGER DEFAULT 0,
    avg_execution_time_ms INTEGER,
    error_rate DECIMAL(5,2) DEFAULT 0.00,
    last_active TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_agent_department;
CREATE INDEX idx_agent_department ON foundry_agents(department_id);
DROP INDEX IF EXISTS idx_agent_status;
CREATE INDEX idx_agent_status ON foundry_agents(status);
DROP INDEX IF EXISTS "idx_agent_capacity";
CREATE INDEX "idx_agent_capacity" ON foundry_agents ((capacity - current_load)); -- Available capacity

-- ----------------------------------------------------------------
-- EXECUTION LAYER: AGENT ACTIONS & ARTIFACTS
-- ----------------------------------------------------------------

-- Enhanced agent log (replaces foundry_agent_log from v2.1)
CREATE TABLE IF NOT EXISTS foundry_agent_actions (
    id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES foundry_job_queue(id) ON DELETE CASCADE,
    agent_id INTEGER REFERENCES foundry_agents(id) ON DELETE SET NULL,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    action_type VARCHAR(100) NOT NULL, -- 'generate_code', 'review_code', 'write_doc', 'test_run', etc.
    input_data JSONB NOT NULL,
    output_data JSONB,
    artifacts JSONB, -- Array of {type, path, size, checksum}
    model_used VARCHAR(100) NOT NULL,
    execution_time_ms INTEGER,
    token_count INTEGER,
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    schema_drift_detected BOOLEAN DEFAULT FALSE, -- CRITICAL: Zero-drift monitoring
    drift_details JSONB,
    relevancy_score DECIMAL(3,2), -- 0.00 to 1.00 (how relevant was output to input)
    created_at TIMESTAMP DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_action_job;
CREATE INDEX idx_action_job ON foundry_agent_actions(job_id);
DROP INDEX IF EXISTS idx_action_agent;
CREATE INDEX idx_action_agent ON foundry_agent_actions(agent_id);
DROP INDEX IF EXISTS idx_action_project;
CREATE INDEX idx_action_project ON foundry_agent_actions(project_id);
DROP INDEX IF EXISTS idx_action_drift;
CREATE INDEX idx_action_drift ON foundry_agent_actions(schema_drift_detected) WHERE schema_drift_detected = TRUE;
DROP INDEX IF EXISTS idx_action_created;
CREATE INDEX idx_action_created ON foundry_agent_actions(created_at DESC);

-- Artifact storage metadata
CREATE TABLE IF NOT EXISTS foundry_artifacts (
    id SERIAL PRIMARY KEY,
    action_id INTEGER REFERENCES foundry_agent_actions(id) ON DELETE CASCADE,
    project_id INTEGER REFERENCES foundry_projects(id) ON DELETE CASCADE,
    artifact_type VARCHAR(50) NOT NULL, -- 'code', 'document', 'diagram', 'test_result', 'log'
    file_path VARCHAR(500) NOT NULL,
    file_size_bytes BIGINT,
    mime_type VARCHAR(100),
    checksum VARCHAR(64), -- SHA-256
    storage_location VARCHAR(100) DEFAULT 'local', -- 'local', 's3', 'postgres'
    content TEXT, -- For small artifacts (<1MB)
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_artifact_project;
CREATE INDEX idx_artifact_project ON foundry_artifacts(project_id);
DROP INDEX IF EXISTS idx_artifact_type;
CREATE INDEX idx_artifact_type ON foundry_artifacts(artifact_type);

-- ----------------------------------------------------------------
-- ERROR HANDLING & DRIFT DETECTION
-- ----------------------------------------------------------------

-- Schema validation failures (Zero-Drift enforcement)
CREATE TABLE IF NOT EXISTS foundry_schema_violations (
    id SERIAL PRIMARY KEY,
    action_id INTEGER REFERENCES foundry_agent_actions(id) ON DELETE CASCADE,
    agent_id INTEGER REFERENCES foundry_agents(id) ON DELETE SET NULL,
    expected_schema JSONB NOT NULL,
    actual_output JSONB NOT NULL,
    violation_type VARCHAR(50) NOT NULL, -- 'missing_field', 'wrong_type', 'invalid_value', 'extra_field'
    field_path VARCHAR(255), -- JSON path to violating field
    severity VARCHAR(20) DEFAULT 'error', -- 'warning', 'error', 'critical'
    auto_remediated BOOLEAN DEFAULT FALSE,
    remediation_action TEXT,
    detected_at TIMESTAMP DEFAULT NOW()
);

DROP INDEX IF EXISTS idx_violation_agent;
CREATE INDEX idx_violation_agent ON foundry_schema_violations(agent_id);
DROP INDEX IF EXISTS idx_violation_severity;
CREATE INDEX idx_violation_severity ON foundry_schema_violations(severity);
DROP INDEX IF EXISTS idx_violation_detected;
CREATE INDEX idx_violation_detected ON foundry_schema_violations(detected_at DESC);

-- Error escalation log
CREATE TABLE IF NOT EXISTS foundry_error_escalations (
    id SERIAL PRIMARY KEY,
    job_id INTEGER REFERENCES foundry_job_queue(id) ON DELETE CASCADE,
    error_source VARCHAR(100) NOT NULL, -- agent_name or system component
    error_type VARCHAR(50) NOT NULL,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    escalation_level INTEGER DEFAULT 1, -- 1 (department), 2 (management), 3 (CTO)
    assigned_to VARCHAR(100), -- Who's handling the escalation
    status VARCHAR(20) DEFAULT 'open', -- 'open', 'investigating', 'resolved', 'escalated_further'
    resolution TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP
);

DROP INDEX IF EXISTS idx_escalation_status;
CREATE INDEX idx_escalation_status ON foundry_error_escalations(status);
DROP INDEX IF EXISTS idx_escalation_level;
CREATE INDEX idx_escalation_level ON foundry_error_escalations(escalation_level DESC);

-- ----------------------------------------------------------------
-- PERFORMANCE & ANALYTICS
-- ----------------------------------------------------------------

-- Department performance metrics
CREATE TABLE IF NOT EXISTS foundry_department_metrics (
    id SERIAL PRIMARY KEY,
    department_id INTEGER REFERENCES foundry_departments(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,
    jobs_completed INTEGER DEFAULT 0,
    jobs_failed INTEGER DEFAULT 0,
    avg_execution_time_ms INTEGER,
    total_tokens_used BIGINT DEFAULT 0,
    drift_incidents INTEGER DEFAULT 0,
    uptime_percentage DECIMAL(5,2) DEFAULT 100.00,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(department_id, metric_date)
);

-- Agent performance leaderboard
CREATE TABLE IF NOT EXISTS foundry_agent_metrics (
    id SERIAL PRIMARY KEY,
    agent_id INTEGER REFERENCES foundry_agents(id) ON DELETE CASCADE,
    metric_date DATE NOT NULL,
    jobs_completed INTEGER DEFAULT 0,
    jobs_failed INTEGER DEFAULT 0,
    avg_relevancy_score DECIMAL(3,2),
    avg_execution_time_ms INTEGER,
    tokens_used BIGINT DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    drift_incidents INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(agent_id, metric_date)
);

-- ----------------------------------------------------------------
-- INTER-DEPARTMENT COMMUNICATION
-- ----------------------------------------------------------------

-- Message bus for agent-to-agent communication
CREATE TABLE IF NOT EXISTS foundry_messages (
    id SERIAL PRIMARY KEY,
    from_agent_id INTEGER REFERENCES foundry_agents(id) ON DELETE SET NULL,
    to_agent_id INTEGER REFERENCES foundry_agents(id) ON DELETE SET NULL,
    to_department_id INTEGER REFERENCES foundry_departments(id) ON DELETE CASCADE, -- If broadcast to dept
    message_type VARCHAR(50) NOT NULL, -- 'request', 'response', 'notification', 'escalation'
    subject VARCHAR(255),
    body TEXT NOT NULL,
    payload JSONB,
    priority INTEGER DEFAULT 5,
    status VARCHAR(20) DEFAULT 'unread', -- 'unread', 'read', 'processed', 'archived'
    created_at TIMESTAMP DEFAULT NOW(),
    read_at TIMESTAMP
);

DROP INDEX IF EXISTS idx_message_to_agent;
CREATE INDEX idx_message_to_agent ON foundry_messages(to_agent_id, status);
DROP INDEX IF EXISTS idx_message_to_dept;
CREATE INDEX idx_message_to_dept ON foundry_messages(to_department_id, status);
DROP INDEX IF EXISTS idx_message_priority;
CREATE INDEX idx_message_priority ON foundry_messages(priority DESC, created_at ASC);

-- ----------------------------------------------------------------
-- HELPER VIEWS FOR MONITORING
-- ----------------------------------------------------------------

DROP VIEW IF EXISTS v_swarm_health;
CREATE OR REPLACE VIEW v_swarm_health AS
SELECT 
    d.department_name,
    d.lead_agent,
    COUNT(DISTINCT a.id) as total_agents,
    SUM(CASE WHEN a.status = 'idle' THEN 1 ELSE 0 END) as idle_agents,
    SUM(CASE WHEN a.status = 'busy' THEN 1 ELSE 0 END) as busy_agents,
    SUM(CASE WHEN a.status = 'error' THEN 1 ELSE 0 END) as error_agents,
    SUM(a.capacity - a.current_load) as available_capacity,
    COALESCE(AVG(a.error_rate), 0)::DECIMAL(5,2) as avg_error_rate
FROM foundry_departments d
LEFT JOIN foundry_agents a ON a.department_id = d.id
WHERE d.is_active = TRUE
GROUP BY d.id, d.department_name, d.lead_agent
ORDER BY d.department_name;

DROP VIEW IF EXISTS v_job_queue_summary;
CREATE OR REPLACE VIEW v_job_queue_summary AS
SELECT 
    assigned_department,
    status,
    priority,
    COUNT(*) as job_count,
    MIN(created_at) as oldest_job,
    MAX(created_at) as newest_job
FROM foundry_job_queue
WHERE status NOT IN ('completed', 'failed')
GROUP BY assigned_department, status, priority
ORDER BY priority ASC, assigned_department;

DROP VIEW IF EXISTS v_drift_alerts;
CREATE OR REPLACE VIEW v_drift_alerts AS
SELECT 
    sv.id as violation_id,
    a.agent_name,
    d.department_name,
    sv.violation_type,
    sv.severity,
    sv.field_path,
    sv.detected_at,
    aa.action_type,
    CASE WHEN sv.auto_remediated THEN 'Auto-Fixed' ELSE 'Needs Review' END as remediation_status
FROM foundry_schema_violations sv
JOIN foundry_agent_actions aa ON aa.id = sv.action_id
JOIN foundry_agents a ON a.id = sv.agent_id
JOIN foundry_departments d ON d.id = a.department_id
WHERE sv.detected_at > NOW() - INTERVAL '24 hours'
ORDER BY sv.severity DESC, sv.detected_at DESC;

-- ----------------------------------------------------------------
-- TRIGGERS & AUTOMATION
-- ----------------------------------------------------------------

DROP TRIGGER IF EXISTS trigger_update_agent_metrics ON foundry_job_queue;
DROP FUNCTION IF EXISTS update_agent_metrics();
CREATE OR REPLACE FUNCTION update_agent_metrics()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        UPDATE foundry_agents
        SET 
            current_load = current_load - 1,
            total_jobs_completed = total_jobs_completed + 1,
            last_active = NOW()
        WHERE id = (
            SELECT agent_id FROM foundry_agent_actions 
            WHERE job_id = NEW.id 
            ORDER BY created_at DESC 
            LIMIT 1
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_agent_metrics
    AFTER UPDATE ON foundry_job_queue
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION update_agent_metrics();

DROP TRIGGER IF EXISTS trigger_alert_on_drift ON foundry_agent_actions;
DROP FUNCTION IF EXISTS alert_on_drift();
CREATE OR REPLACE FUNCTION alert_on_drift()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.schema_drift_detected = TRUE THEN
        INSERT INTO foundry_error_escalations (
            job_id,
            error_source,
            error_type,
            error_message,
            escalation_level
        ) VALUES (
            NEW.job_id,
            (SELECT agent_name FROM foundry_agents WHERE id = NEW.agent_id),
            'schema_drift',
            'Agent output deviated from expected schema: ' || COALESCE(NEW.error_message, 'See drift_details'),
            2 -- Escalate to management layer
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_alert_on_drift
    AFTER INSERT OR UPDATE ON foundry_agent_actions
    FOR EACH ROW
    WHEN (NEW.schema_drift_detected = TRUE)
    EXECUTE FUNCTION alert_on_drift();

-- ----------------------------------------------------------------
-- VERIFICATION & INITIALIZATION
-- ----------------------------------------------------------------

-- Seed initial CTO approval for system startup
INSERT INTO foundry_cto_approvals (
    approval_type,
    request_data,
    status,
    requested_by,
    approval_token
) VALUES (
    'system_initialization',
    '{"version": "3.0", "worker_count": 60, "departments": 11}'::jsonb,
    'pending',
    'system_bootstrap',
    'FOUNDRY_V3_INIT_' || substr(md5(random()::text), 1, 16)
) ON CONFLICT DO NOTHING;

-- ================================================================
-- DEPLOYMENT VERIFICATION
-- ================================================================

-- Check all critical tables exist
DO $$
DECLARE
    expected_tables TEXT[] := ARRAY[
        'foundry_cto_approvals',
        'foundry_pentad_votes',
        'foundry_job_queue',
        'foundry_sprints',
        'foundry_mrs',
        'foundry_departments',
        'foundry_agents',
        'foundry_agent_actions',
        'foundry_artifacts',
        'foundry_schema_violations',
        'foundry_error_escalations',
        'foundry_messages'
    ];
    _table_name_to_check TEXT; -- Declare the loop variable
    missing_count INTEGER := 0;
BEGIN
    FOREACH _table_name_to_check IN ARRAY expected_tables
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.tables AS t 
            WHERE t.table_schema = 'public' AND t.table_name = _table_name_to_check
        ) THEN
            RAISE WARNING 'Missing table: %', _table_name_to_check;
            missing_count := missing_count + 1;
        END IF;
    END LOOP;
    
    IF missing_count = 0 THEN
        RAISE NOTICE '✅ All % critical tables verified', array_length(expected_tables, 1);
    ELSE
        RAISE EXCEPTION '❌ Missing % critical tables', missing_count;
    END IF;
END $$;

-- Summary report
SELECT 
    'Foundry v3.0 Database Initialized' as status,
    (SELECT COUNT(*) FROM foundry_departments) as departments,
    (SELECT COUNT(*) FROM foundry_agents) as agents_registered,
    (SELECT COUNT(*) FROM foundry_cto_approvals WHERE status = 'pending') as pending_approvals,
    NOW() as initialized_at;

-- ================================================================
-- READY FOR N8N WORKFLOW DEPLOYMENT
-- ================================================================
-- Next steps:
-- 1. Deploy this schema: docker exec -i foundry_db psql -U foundry -d foundry < foundry_v3_init_db.sql
-- 2. Import Prompt Master workflow into n8n
-- 3. Import Department Lead workflows
-- 4. Initialize 60+ worker agents
-- 5. Request CTO approval to begin operations
-- ================================================================

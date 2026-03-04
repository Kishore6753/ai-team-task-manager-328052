-- AI Team Task Manager PostgreSQL Schema
-- Schema for: users, roles, projects, tasks, kanban columns, comments, notifications, sessions, attachments metadata
-- Last updated: 2024-06
-- 
-- This schema is designed with:
-- - Referential integrity (foreign keys)
-- - Cascading deletes where appropriate (e.g., deleting a project deletes tasks)
-- - Composite and unique indices for performance and constraints
-- - Modern conventions for user sessions & JWT refresh tokens
-- - Comments and doc blocks for maintainability


--------------------------
-- ROLE/USER/SESSION TABLES
--------------------------

-- Table: roles
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL UNIQUE,
    description TEXT
);

-- Table: users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(254) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(64) NOT NULL,
    role_id INTEGER REFERENCES roles(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: sessions (for JWT/refresh tokens)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(255) NOT NULL,
    user_agent TEXT,
    ip_address VARCHAR(48),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, refresh_token_hash)
);

--------------------------------
-- ORGANIZATION: PROJECTS/TASKS
--------------------------------

-- Table: projects
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(128) NOT NULL,
    description TEXT,
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_archived BOOLEAN NOT NULL DEFAULT FALSE
);

-- Table: project_members (user-per-project with role)
CREATE TABLE IF NOT EXISTS project_members (
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    member_role VARCHAR(32) NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (project_id, user_id)
);

-- Table: kanban_columns (per project)
CREATE TABLE IF NOT EXISTS kanban_columns (
    id SERIAL PRIMARY KEY,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(64) NOT NULL,
    position INTEGER NOT NULL,
    CONSTRAINT uniq_project_column UNIQUE(project_id, name),
    CONSTRAINT uniq_project_position UNIQUE(project_id, position)
);

-- Table: tasks
CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    column_id INTEGER NOT NULL REFERENCES kanban_columns(id) ON DELETE SET NULL,
    assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    title VARCHAR(256) NOT NULL,
    description TEXT,
    status VARCHAR(32) DEFAULT 'todo',
    priority INTEGER DEFAULT 0,
    order_in_column INTEGER NOT NULL,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    due_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_project_tasks ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_column_tasks ON tasks(column_id);

-- Table: comments
CREATE TABLE IF NOT EXISTS comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: attachments_metadata (for file metadata, not file blobs)
CREATE TABLE IF NOT EXISTS attachments_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
    comment_id UUID REFERENCES comments(id) ON DELETE SET NULL,
    filename VARCHAR(255) NOT NULL,
    file_url TEXT NOT NULL,
    uploaded_by UUID REFERENCES users(id) ON DELETE SET NULL,
    size_bytes BIGINT,
    mime_type VARCHAR(128),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

--------------------
-- NOTIFICATIONS
--------------------

-- Table: notifications (user targeted or project broadcast)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    read_at TIMESTAMPTZ
);

-----------------------------------------------------
-- INDEXING FOR FAST LOOKUP
-----------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_project_members_user ON project_members(user_id);
CREATE INDEX IF NOT EXISTS idx_comments_task_id ON comments(task_id);
CREATE INDEX IF NOT EXISTS idx_attachments_task_id ON attachments_metadata(task_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_project ON notifications(project_id);

-----------------------------------------------------
-- TRIGGERS & AUDITING
-- Optionally, add triggers for updated_at, soft delete, etc. if required by logic.
-----------------------------------------------------

-----------------------------------------------------
-- INITIAL SEED DATA FOR ROLES
-----------------------------------------------------
INSERT INTO roles (name, description)
    VALUES ('admin', 'Application Administrator')
ON CONFLICT (name) DO NOTHING;

INSERT INTO roles (name, description)
    VALUES ('member', 'Regular Team Member')
ON CONFLICT (name) DO NOTHING;

-----------------------------------------------------
-- END OF SCHEMA: See README or DB docs for instructions!
-----------------------------------------------------

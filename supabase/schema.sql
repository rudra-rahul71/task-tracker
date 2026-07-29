-- Task Tracker Supabase Database Schema
-- Paste this script into the Supabase SQL Editor to initialize all required tables and RLS security policies inside the dedicated 'task_tracker' schema.

-- 0. CREATE SCHEMA AND GRANT USAGE
CREATE SCHEMA IF NOT EXISTS task_tracker;
GRANT USAGE ON SCHEMA task_tracker TO anon, authenticated, service_role;

-- 1. Create TASK_GROUPS table
CREATE TABLE IF NOT EXISTS task_tracker.task_groups (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    name TEXT NOT NULL,
    "colorValue" BIGINT NOT NULL DEFAULT 4283215696, -- Default gold
    schedule JSONB,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create TASKS table
CREATE TABLE IF NOT EXISTS task_tracker.tasks (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    "groupId" TEXT REFERENCES task_tracker.task_groups(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    schedule JSONB,
    steps JSONB NOT NULL DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'pending',
    "lastCompletedAt" TIMESTAMPTZ,
    "lastResetAt" TIMESTAMPTZ,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Create TASK_HISTORY table
CREATE TABLE IF NOT EXISTS task_tracker.task_history (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    "taskId" TEXT NOT NULL REFERENCES task_tracker.tasks(id) ON DELETE CASCADE,
    "taskName" TEXT NOT NULL,
    "groupId" TEXT REFERENCES task_tracker.task_groups(id) ON DELETE SET NULL,
    date TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL DEFAULT 'completion',
    "completedSteps" JSONB NOT NULL DEFAULT '[]'::jsonb
);

-- 4. Create TRACKERS table
CREATE TABLE IF NOT EXISTS task_tracker.trackers (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'maintain',
    "durationType" TEXT NOT NULL DEFAULT 'indefinite',
    "measurementUnit" TEXT NOT NULL DEFAULT 'days',
    "durationValue" INT,
    "startDate" TIMESTAMPTZ NOT NULL,
    "endDate" TIMESTAMPTZ,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now(),
    "completedDates" JSONB NOT NULL DEFAULT '[]'::jsonb,
    "originalStartDate" TIMESTAMPTZ NOT NULL
);

-- 5. Create TRACKER_HISTORY table
CREATE TABLE IF NOT EXISTS task_tracker.tracker_history (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    "trackerId" TEXT NOT NULL REFERENCES task_tracker.trackers(id) ON DELETE CASCADE,
    "trackerName" TEXT NOT NULL,
    "trackerType" TEXT NOT NULL DEFAULT 'maintain',
    date TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL DEFAULT 'completion'
);

-- --- ENABLE ROW LEVEL SECURITY (RLS) ---
ALTER TABLE task_tracker.task_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tracker.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tracker.task_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tracker.trackers ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tracker.tracker_history ENABLE ROW LEVEL SECURITY;

-- --- CREATE SECURITY POLICIES ---
-- Users can only read and write their own data based on the 'userId' field matching their auth.uid()

-- task_groups policies
CREATE POLICY "Users can access their own task_groups" ON task_tracker.task_groups
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- tasks policies
CREATE POLICY "Users can access their own tasks" ON task_tracker.tasks
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- task_history policies
CREATE POLICY "Users can access their own task_history" ON task_tracker.task_history
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- trackers policies
CREATE POLICY "Users can access their own trackers" ON task_tracker.trackers
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- tracker_history policies
CREATE POLICY "Users can access their own tracker_history" ON task_tracker.tracker_history
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- --- GRANT PRIVILEGES TO AUTHENTICATED ROLE ---
-- This ensures the authenticated app user role has the required permissions to perform CRUD operations
GRANT ALL ON ALL TABLES IN SCHEMA task_tracker TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA task_tracker TO authenticated, service_role;

-- --- ENABLE REALTIME BROADCASTING ---
alter publication supabase_realtime add table task_tracker.task_groups;
alter publication supabase_realtime add table task_tracker.tasks;
alter publication supabase_realtime add table task_tracker.task_history;
alter publication supabase_realtime add table task_tracker.trackers;
alter publication supabase_realtime add table task_tracker.tracker_history;

-- --- ENABLE REALTIME DELETIONS (REPLICA IDENTITY FULL) ---
alter table task_tracker.task_groups replica identity full;
alter table task_tracker.tasks replica identity full;
alter table task_tracker.task_history replica identity full;
alter table task_tracker.trackers replica identity full;
alter table task_tracker.tracker_history replica identity full;
-- Task Tracker Supabase Database Schema
-- Paste this script into the Supabase SQL Editor to initialize all required tables and RLS security policies.

-- 1. Create TASK_GROUPS table
CREATE TABLE IF NOT EXISTS public.task_groups (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    name TEXT NOT NULL,
    "colorValue" BIGINT NOT NULL DEFAULT 4283215696, -- Default gold
    schedule JSONB,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create TASKS table
CREATE TABLE IF NOT EXISTS public.tasks (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    "groupId" TEXT REFERENCES public.task_groups(id) ON DELETE SET NULL,
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
CREATE TABLE IF NOT EXISTS public.task_history (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    "taskId" TEXT NOT NULL,
    "taskName" TEXT NOT NULL,
    "groupId" TEXT,
    date TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL DEFAULT 'completion',
    "completedSteps" JSONB NOT NULL DEFAULT '[]'::jsonb
);

-- 4. Create TRACKERS table
CREATE TABLE IF NOT EXISTS public.trackers (
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
CREATE TABLE IF NOT EXISTS public.tracker_history (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "userId" TEXT NOT NULL DEFAULT (auth.uid()::text),
    "trackerId" TEXT NOT NULL,
    "trackerName" TEXT NOT NULL,
    "trackerType" TEXT NOT NULL DEFAULT 'maintain',
    date TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL DEFAULT 'completion'
);

-- --- ENABLE ROW LEVEL SECURITY (RLS) ---
ALTER TABLE public.task_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.task_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trackers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tracker_history ENABLE ROW LEVEL SECURITY;

-- --- CREATE SECURITY POLICIES ---
-- Users can only read and write their own data based on the 'userId' field matching their auth.uid()

-- task_groups policies
CREATE POLICY "Users can access their own task_groups" ON public.task_groups
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- tasks policies
CREATE POLICY "Users can access their own tasks" ON public.tasks
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- task_history policies
CREATE POLICY "Users can access their own task_history" ON public.task_history
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- trackers policies
CREATE POLICY "Users can access their own trackers" ON public.trackers
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- tracker_history policies
CREATE POLICY "Users can access their own tracker_history" ON public.tracker_history
    FOR ALL USING (auth.uid()::text = "userId") WITH CHECK (auth.uid()::text = "userId");

-- --- GRANT PRIVILEGES TO AUTHENTICATED ROLE ---
-- This ensures the authenticated app user role has the required permissions to perform CRUD operations
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.task_groups TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.tasks TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.task_history TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.trackers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.tracker_history TO authenticated;

-- --- ENABLE REALTIME BROADCASTING ---
-- By default, Supabase does not broadcast real-time updates for security.
-- Run these statements to add your tables to the realtime replication publication
-- so the Flutter app's streams receive updates instantly when data changes.
alter publication supabase_realtime add table public.task_groups;
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.task_history;
alter publication supabase_realtime add table public.trackers;
alter publication supabase_realtime add table public.tracker_history;

-- --- ENABLE REALTIME DELETIONS (REPLICA IDENTITY FULL) ---
-- By default, Postgres replication only sends the primary key on deletions.
-- With RLS enabled, Supabase Realtime cannot verify ownership policies without all columns (like userId).
-- Setting replica identity to FULL ensures deleted rows are correctly broadcast to the Flutter UI.
alter table public.task_groups replica identity full;
alter table public.tasks replica identity full;
alter table public.task_history replica identity full;
alter table public.trackers replica identity full;
alter table public.tracker_history replica identity full;




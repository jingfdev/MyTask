-- ============================================
-- MyTask Database Schema
-- Run this SQL in your Supabase SQL Editor
-- ============================================

-- 1. USERS TABLE
-- Stores user profile information
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) NOT NULL UNIQUE,
  full_name VARCHAR(255),
  profile_image_url TEXT,
  auth_provider VARCHAR(50), -- 'google', 'email', etc.
  dark_mode BOOLEAN DEFAULT FALSE,
  notifications_enabled BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. CATEGORIES TABLE
-- Predefined task categories
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  color VARCHAR(7), -- hex color code, e.g., '#FF5733'
  icon VARCHAR(50), -- emoji or icon name
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, name)
);

-- 3. TASKS TABLE
-- Main task/to-do items
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  priority VARCHAR(20) DEFAULT 'medium', -- 'low', 'medium', 'high'
  category VARCHAR(100) DEFAULT 'Personal',
  is_completed BOOLEAN DEFAULT FALSE,
  due_date TIMESTAMP WITH TIME ZONE,
  reminder_time TIMESTAMP WITH TIME ZONE, -- when to send notification
  recurrence VARCHAR(50), -- 'none', 'daily', 'weekly', 'monthly'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. TASK_TAGS TABLE
-- Many-to-many relationship for task tags
CREATE TABLE IF NOT EXISTS task_tags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_name VARCHAR(50) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(task_id, tag_name)
);

-- 5. SUBTASKS TABLE
-- Subtasks for breaking down larger tasks
CREATE TABLE IF NOT EXISTS subtasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  is_completed BOOLEAN DEFAULT FALSE,
  order_index INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6. TASK_ATTACHMENTS TABLE
-- Store file references/URLs for tasks
CREATE TABLE IF NOT EXISTS task_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  file_url TEXT NOT NULL,
  file_name VARCHAR(255),
  file_type VARCHAR(50), -- 'image', 'document', 'audio', etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES (for better query performance)
-- ============================================

CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
CREATE INDEX idx_tasks_is_completed ON tasks(is_completed);
CREATE INDEX idx_subtasks_task_id ON subtasks(task_id);
CREATE INDEX idx_categories_user_id ON categories(user_id);
CREATE INDEX idx_task_tags_task_id ON task_tags(task_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE subtasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_attachments ENABLE ROW LEVEL SECURITY;

-- Users can only view/edit their own profile
CREATE POLICY "users_can_view_own_profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "users_can_update_own_profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Users can only view/edit/delete their own tasks
CREATE POLICY "users_can_view_own_tasks" ON tasks
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_can_create_tasks" ON tasks
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_update_own_tasks" ON tasks
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_can_delete_own_tasks" ON tasks
  FOR DELETE USING (auth.uid() = user_id);

-- Users can only view/edit/delete their own categories
CREATE POLICY "users_can_view_own_categories" ON categories
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "users_can_create_categories" ON categories
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_can_update_own_categories" ON categories
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "users_can_delete_own_categories" ON categories
  FOR DELETE USING (auth.uid() = user_id);

-- Users can only manage subtasks of their own tasks
CREATE POLICY "users_can_view_own_subtasks" ON subtasks
  FOR SELECT USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_create_subtasks" ON subtasks
  FOR INSERT WITH CHECK (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_update_own_subtasks" ON subtasks
  FOR UPDATE USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_delete_own_subtasks" ON subtasks
  FOR DELETE USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

-- Similar policies for task_tags and task_attachments
CREATE POLICY "users_can_view_own_task_tags" ON task_tags
  FOR SELECT USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_create_task_tags" ON task_tags
  FOR INSERT WITH CHECK (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_delete_own_task_tags" ON task_tags
  FOR DELETE USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_view_own_task_attachments" ON task_attachments
  FOR SELECT USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_create_task_attachments" ON task_attachments
  FOR INSERT WITH CHECK (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

CREATE POLICY "users_can_delete_own_task_attachments" ON task_attachments
  FOR DELETE USING (
    task_id IN (SELECT id FROM tasks WHERE user_id = auth.uid())
  );

-- ============================================
-- SAMPLE DATA (optional - for testing)
-- ============================================

-- Note: Replace 'user-uuid-here' with actual user IDs after testing
-- INSERT INTO categories (user_id, name, color, icon)
-- VALUES 
--   ('user-uuid-here', 'Personal', '#FF5733', '👤'),
--   ('user-uuid-here', 'Work', '#3498DB', '💼'),
--   ('user-uuid-here', 'Shopping', '#2ECC71', '🛒');

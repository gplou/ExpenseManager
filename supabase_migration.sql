-- ============================================================
-- Migración: Tabla de tareas
-- Ejecutar en Supabase > SQL Editor
-- ============================================================

-- Tipos personalizados
CREATE TYPE task_status AS ENUM ('pending', 'inProgress', 'completed');
CREATE TYPE task_priority AS ENUM ('low', 'medium', 'high');

-- Tabla de tareas
CREATE TABLE IF NOT EXISTS tasks (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT,
  status      task_status NOT NULL DEFAULT 'pending',
  priority    task_priority NOT NULL DEFAULT 'medium',
  due_date    TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

-- Índices para queries frecuentes
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_status ON tasks(user_id, status);
CREATE INDEX idx_tasks_due_date ON tasks(user_id, due_date);

-- Row Level Security (RLS) — OBLIGATORIO para Supabase
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Políticas: cada usuario solo ve y modifica sus propias tareas
CREATE POLICY "Users can view their own tasks"
  ON tasks FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own tasks"
  ON tasks FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own tasks"
  ON tasks FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own tasks"
  ON tasks FOR DELETE
  USING (auth.uid() = user_id);

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tasks_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

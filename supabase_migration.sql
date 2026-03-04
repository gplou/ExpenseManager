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

-- ============================================================
-- Migración: Suscripciones PRO
-- Ejecutar en Supabase > SQL Editor (después de la migración de tareas)
-- ============================================================

-- Tabla de suscripciones activas
CREATE TABLE IF NOT EXISTS subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- ID de transacción original de la tienda (Google Play / App Store)
  store_tx_id TEXT,
  -- Origen: 'google_play' | 'app_store' | 'promo_code'
  source      TEXT NOT NULL DEFAULT 'google_play',
  -- Fecha de expiración de la suscripción mensual
  expires_at  TIMESTAMPTZ NOT NULL,
  -- El usuario canceló: la suscripción sigue activa hasta expires_at
  cancelled   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ
);

-- Un solo registro de suscripción por usuario (UPSERT target)
CREATE UNIQUE INDEX idx_subscriptions_user_id ON subscriptions(user_id);

-- RLS
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own subscription"
  ON subscriptions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- Migración: Códigos promocionales
-- ============================================================

-- Tabla de códigos promo (solo admin puede insertar)
CREATE TABLE IF NOT EXISTS promo_codes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- El código que el usuario escribe (siempre en mayúsculas)
  code          TEXT NOT NULL UNIQUE,
  -- Días de PRO que otorga este código
  duration_days INTEGER NOT NULL DEFAULT 30,
  -- NULL = usos ilimitados
  max_uses      INTEGER,
  use_count     INTEGER NOT NULL DEFAULT 0,
  -- NULL = no expira nunca
  valid_until   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Registro de quién canjeó qué código (evita doble canje)
CREATE TABLE IF NOT EXISTS promo_code_redemptions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promo_code_id UUID NOT NULL REFERENCES promo_codes(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  redeemed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- Constraint: un usuario solo puede canjear cada código una vez
  UNIQUE(promo_code_id, user_id)
);

ALTER TABLE promo_code_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own redemptions"
  ON promo_code_redemptions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

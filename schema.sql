-- CAAB WhatsApp Routing — Supabase Schema
-- Run this in Supabase Dashboard → SQL Editor

CREATE TABLE conversation_state (
  user_id TEXT PRIMARY KEY,
  instance TEXT,
  active_flow TEXT,
  step TEXT,
  data JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

CREATE TABLE chat_messages (
  id BIGSERIAL PRIMARY KEY,
  user_id TEXT,
  instance TEXT,
  direction TEXT CHECK (direction IN ('in', 'out')),
  message_id TEXT UNIQUE,
  text TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_user_id ON chat_messages(user_id);
CREATE INDEX idx_chat_messages_message_id ON chat_messages(message_id);
CREATE INDEX idx_conversation_state_expires ON conversation_state(expires_at);

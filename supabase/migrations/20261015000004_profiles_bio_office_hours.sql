-- Migration: Add bio and office_hours to profiles
-- Fixes teacher settings profile fields persistence.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS bio text,
  ADD COLUMN IF NOT EXISTS office_hours text;

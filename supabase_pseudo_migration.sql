-- ==============================================================================
-- Migration Supabase : Ajout de la colonne pseudo pour les agents
-- ==============================================================================
-- À exécuter dans votre console Supabase -> SQL Editor -> Run (si vous souhaitez
-- stocker le pseudo directement dans la table 'agents', en plus des métadonnées utilisateur).

ALTER TABLE public.agents 
ADD COLUMN IF NOT EXISTS pseudo TEXT;

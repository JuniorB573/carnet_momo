-- ==============================================================================
-- Migration Supabase : Table de feedback + Ajout de la colonne role sur agents
-- ==============================================================================
-- À exécuter dans la console Supabase -> SQL Editor.

-- 1. S'assurer que la colonne 'role' existe sur la table agents (nécessaire pour le rôle admin)
ALTER TABLE public.agents 
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'agent';

-- 2. Création de la table feedback
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- 3. Activer la sécurité au niveau des lignes (Row Level Security)
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- 4. Nettoyer les politiques existantes si elles ont déjà été créées
DROP POLICY IF EXISTS "Les agents peuvent inserer leur feedback" ON public.feedback;
DROP POLICY IF EXISTS "Les agents peuvent voir leurs feedbacks" ON public.feedback;
DROP POLICY IF EXISTS "Les administrateurs peuvent voir tous les feedbacks" ON public.feedback;

-- 5. Politique d'insertion : Tout agent connecté peut envoyer son avis
CREATE POLICY "Les agents peuvent inserer leur feedback"
ON public.feedback
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = agent_id);

-- 6. Politique de lecture : Les agents peuvent lire leurs propres avis
CREATE POLICY "Les agents peuvent voir leurs feedbacks"
ON public.feedback
FOR SELECT
TO authenticated
USING (auth.uid() = agent_id);

-- 7. Politique de lecture : Les administrateurs peuvent lire tous les avis
CREATE POLICY "Les administrateurs peuvent voir tous les feedbacks"
ON public.feedback
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.agents
    WHERE public.agents.id = auth.uid()
      AND public.agents.role = 'admin'
  )
);

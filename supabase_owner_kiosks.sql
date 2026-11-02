-- ==============================================================================
-- Migration Supabase : Table owner_kiosks, code patron et accès patrons
-- ==============================================================================
-- À exécuter dans votre console Supabase -> SQL Editor -> Run

-- 1. S'assurer que la colonne owner_code existe sur la table agents
ALTER TABLE public.agents 
ADD COLUMN IF NOT EXISTS owner_code TEXT;

-- 2. Création de la table owner_kiosks
CREATE TABLE IF NOT EXISTS public.owner_kiosks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    owner_phone TEXT NOT NULL,
    agent_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    agent_phone TEXT NOT NULL,
    custom_name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(owner_id, agent_id)
);

-- 3. Activer la sécurité Row Level Security
ALTER TABLE public.owner_kiosks ENABLE ROW LEVEL SECURITY;

-- 4. Nettoyer les anciennes politiques si existantes
DROP POLICY IF EXISTS "Les patrons peuvent gerer leurs kiosques" ON public.owner_kiosks;
DROP POLICY IF EXISTS "Les administrateurs peuvent voir tous les kiosques" ON public.owner_kiosks;
DROP POLICY IF EXISTS "Lecture agents pour liaison patron" ON public.agents;
DROP POLICY IF EXISTS "Lecture transactions pour patrons" ON public.transactions;

-- 5. Politique pour les patrons : voir, ajouter et supprimer leurs kiosques
CREATE POLICY "Les patrons peuvent gerer leurs kiosques"
ON public.owner_kiosks
FOR ALL
TO authenticated
USING (auth.uid() = owner_id)
WITH CHECK (auth.uid() = owner_id);

-- 6. Politique pour l'administrateur : voir tous les patrons et leurs agents
CREATE POLICY "Les administrateurs peuvent voir tous les kiosques"
ON public.owner_kiosks
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.agents
    WHERE public.agents.id = auth.uid()
      AND public.agents.role = 'admin'
  )
);

-- 7. Politique permettant la recherche d'un agent pour la liaison patron
CREATE POLICY "Lecture agents pour liaison patron"
ON public.agents
FOR SELECT
TO authenticated
USING (true);

-- 8. Politique permettant aux patrons de lire les opérations de leurs kiosques rattachés
CREATE POLICY "Lecture transactions pour patrons"
ON public.transactions
FOR SELECT
TO authenticated
USING (
  agent_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.owner_kiosks
    WHERE public.owner_kiosks.owner_id = auth.uid()
      AND public.owner_kiosks.agent_id = public.transactions.agent_id
  )
  OR EXISTS (
    SELECT 1 FROM public.agents
    WHERE public.agents.id = auth.uid()
      AND public.agents.role = 'admin'
  )
);

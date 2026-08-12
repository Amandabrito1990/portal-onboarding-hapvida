-- ============================================================
-- SCHEMA v1 — Portal de Onboarding Hapvida
-- Rodar no SQL Editor do Supabase (em uma única execução)
-- ============================================================

-- 1. Tabela de perfis de usuário (estende auth.users)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    nome TEXT NOT NULL,
    perfil TEXT NOT NULL CHECK (perfil IN ('admin','gestor','parceiro')),
    ativo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Fases da jornada (biblioteca fixa)
CREATE TABLE public.fases (
    id SERIAL PRIMARY KEY,
    nome TEXT NOT NULL,
    periodo TEXT NOT NULL,
    ordem INTEGER NOT NULL UNIQUE
);

-- 3. Atividades-modelo (biblioteca fixa, lida da planilha)
CREATE TABLE public.atividades_modelo (
    id SERIAL PRIMARY KEY,
    fase_id INTEGER NOT NULL REFERENCES public.fases(id) ON DELETE CASCADE,
    atividade TEXT NOT NULL,
    como_conduzir TEXT,
    evidencia_esperada TEXT,
    ordem INTEGER NOT NULL
);

-- 4. Colaboradores em onboarding
CREATE TABLE public.colaboradores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    area TEXT,
    unidade TEXT,
    gestor_id UUID REFERENCES public.user_profiles(id),
    parceiro_id UUID REFERENCES public.user_profiles(id),
    data_admissao DATE,
    data_fim_integracao DATE,
    status_geral TEXT NOT NULL DEFAULT 'em_andamento' CHECK (status_geral IN ('em_andamento','concluido','cancelado')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. Checklist por colaborador (instância gerada ao cadastrar)
CREATE TABLE public.checklist_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    colaborador_id UUID NOT NULL REFERENCES public.colaboradores(id) ON DELETE CASCADE,
    atividade_modelo_id INTEGER NOT NULL REFERENCES public.atividades_modelo(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'nao_iniciado' CHECK (status IN ('nao_iniciado','concluido','em_andamento','necessita_acompanhamento','nao_aplicavel')),
    observacao TEXT,
    atualizado_por UUID REFERENCES public.user_profiles(id),
    atualizado_em TIMESTAMPTZ,
    UNIQUE(colaborador_id, atividade_modelo_id)
);

-- ============================================================
-- ROW LEVEL SECURITY — políticas para TODAS as operações
-- ============================================================

-- user_profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_profiles_select" ON public.user_profiles FOR SELECT
    USING (true); -- todos logados podem ver a lista de usuários

CREATE POLICY "user_profiles_insert" ON public.user_profiles FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
        OR NOT EXISTS (SELECT 1 FROM public.user_profiles) -- primeiro usuário (bootstrap)
    );

CREATE POLICY "user_profiles_update" ON public.user_profiles FOR UPDATE
    USING (
        id = auth.uid()
        OR EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
    );

CREATE POLICY "user_profiles_delete" ON public.user_profiles FOR DELETE
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
    );

-- fases (leitura para todos, escrita só admin)
ALTER TABLE public.fases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fases_select" ON public.fases FOR SELECT USING (true);
CREATE POLICY "fases_insert" ON public.fases FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));
CREATE POLICY "fases_update" ON public.fases FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));
CREATE POLICY "fases_delete" ON public.fases FOR DELETE
    USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));

-- atividades_modelo (leitura para todos, escrita só admin)
ALTER TABLE public.atividades_modelo ENABLE ROW LEVEL SECURITY;

CREATE POLICY "atividades_modelo_select" ON public.atividades_modelo FOR SELECT USING (true);
CREATE POLICY "atividades_modelo_insert" ON public.atividades_modelo FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));
CREATE POLICY "atividades_modelo_update" ON public.atividades_modelo FOR UPDATE
    USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));
CREATE POLICY "atividades_modelo_delete" ON public.atividades_modelo FOR DELETE
    USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));

-- colaboradores
ALTER TABLE public.colaboradores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "colaboradores_select" ON public.colaboradores FOR SELECT
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
        OR gestor_id = auth.uid()
        OR parceiro_id = auth.uid()
    );

CREATE POLICY "colaboradores_insert" ON public.colaboradores FOR INSERT
    WITH CHECK (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));

CREATE POLICY "colaboradores_update" ON public.colaboradores FOR UPDATE
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
        OR gestor_id = auth.uid()
        OR parceiro_id = auth.uid()
    );

CREATE POLICY "colaboradores_delete" ON public.colaboradores FOR DELETE
    USING (EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin'));

-- checklist_items
ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "checklist_items_select" ON public.checklist_items FOR SELECT
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
        OR EXISTS (
            SELECT 1 FROM public.colaboradores c
            WHERE c.id = checklist_items.colaborador_id
            AND (c.gestor_id = auth.uid() OR c.parceiro_id = auth.uid())
        )
    );

CREATE POLICY "checklist_items_insert" ON public.checklist_items FOR INSERT
    WITH CHECK (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
    );

CREATE POLICY "checklist_items_update" ON public.checklist_items FOR UPDATE
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
        OR EXISTS (
            SELECT 1 FROM public.colaboradores c
            WHERE c.id = checklist_items.colaborador_id
            AND (c.gestor_id = auth.uid() OR c.parceiro_id = auth.uid())
        )
    );

CREATE POLICY "checklist_items_delete" ON public.checklist_items FOR DELETE
    USING (
        EXISTS (SELECT 1 FROM public.user_profiles WHERE id = auth.uid() AND perfil = 'admin')
    );

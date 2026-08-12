const { createClient } = require('@supabase/supabase-js');

module.exports = async (req, res) => {
    // CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') return res.status(200).end();
    if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

    const { nome, email, senha, perfil } = req.body;
    if (!nome || !email || !senha || !perfil) {
        return res.status(400).json({ error: 'Campos obrigatórios: nome, email, senha, perfil' });
    }
    if (!['admin', 'gestor', 'parceiro'].includes(perfil)) {
        return res.status(400).json({ error: 'Perfil inválido. Use: admin, gestor ou parceiro.' });
    }

    const supabaseUrl = process.env.SUPABASE_URL;
    const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!supabaseUrl || !serviceRoleKey) {
        return res.status(500).json({ error: 'Variáveis de ambiente SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY não configuradas.' });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
        auth: { autoRefreshToken: false, persistSession: false }
    });

    try {
        // 1. Create auth user
        const { data: authData, error: authError } = await supabase.auth.admin.createUser({
            email,
            password: senha,
            email_confirm: true
        });
        if (authError) throw authError;

        const userId = authData.user.id;

        // 2. Insert profile
        const { error: profileError } = await supabase.from('user_profiles').insert({
            id: userId,
            email,
            nome,
            perfil,
            ativo: true
        });
        if (profileError) {
            // Rollback: delete auth user
            await supabase.auth.admin.deleteUser(userId);
            throw profileError;
        }

        return res.status(200).json({ success: true, userId });
    } catch (err) {
        return res.status(400).json({ error: err.message || 'Erro ao criar usuário' });
    }
};

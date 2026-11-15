# LOJA DO IPHONE — Etapa 2 (Supabase e login)

Arquivos adicionados:
- `painel.html`: nova tela operacional, com login real, CRUD inicial de leads e gestão de acessos.
- `config.js`: URL e chave PUBLICÁVEL do projeto Supabase, ainda vazias.
- `supabase/schema.sql`: estrutura inicial do banco, com RLS e separação admin/vendedor.

## Antes de ativar

1. Escolher a organização Supabase e criar um projeto exclusivo para a LOJA DO IPHONE, preferencialmente em São Paulo (`sa-east-1`).
2. Confirmar custos/limites do plano antes de criar o projeto.
3. Rodar `supabase/schema.sql` **somente no projeto novo** pelo SQL Editor, ou por ferramenta de migração após revisão.
4. Configurar Authentication > URL Configuration com Site URL `https://danielvitordelgado-spec.github.io/lojadoiphone/painel.html`.
5. Desativar cadastro público de usuários; criar o primeiro admin e vendedores em Authentication > Users (Add user / Create new user). Definir senha temporária por canal seguro: cada pessoa poderá alterá-la dentro do painel. Não compartilhar senhas aqui na conversa.
6. Depois que o primeiro admin existir, ativá-lo com SQL Editor:
   `UPDATE public.profiles SET role='admin', active=true WHERE id=(SELECT id FROM auth.users WHERE email='EMAIL_DO_ADMIN');`
7. Entrar com o admin no `painel.html` e ativar as contas dos vendedores na tela Equipe. Os usuários convidados entram inicialmente como inativos.
8. Em Project Settings > API Keys, copiar apenas a **publishable key** (ou chave `anon` se necessário) para `config.js`. Copiar também a Project URL.
9. Nunca publicar `service_role`, secrets, tokens do WhatsApp ou senha de banco no GitHub, no `config.js` ou no HTML.
10. Testar com duas contas reais: o admin vê todos os leads, e vendedor vê somente os atribuídos a ele. Executar os Security Advisors do Supabase antes de colocar dados reais.

## Atenção

- O `index.html` (demonstração) permanece no ar e não foi alterado nesta etapa.
- O `painel.html` é uma base funcional **a ser conectada** ao novo Supabase. Sem `config.js` preenchido e SQL instalado, não faz login.
- WhatsApp Cloud API ainda não está conectado. Nunca envie mensagens diretamente do navegador com tokens privados.
- O módulo de campanhas do demo não dispara mensagens.
- O GitHub Pages é público: controles de acesso exigem Auth + RLS no Supabase.
- O backend do WhatsApp será criado separadamente com webhook autenticado, filas, templates aprovados e controle de consentimento.

## Link da página operacional

https://danielvitordelgado-spec.github.io/lojadoiphone/painel.html

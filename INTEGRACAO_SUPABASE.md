# LOJA DO IPHONE — Supabase integrado (15/11/2026)

## Situação
- Hospedagem: GitHub Pages, https://danielvitordelgado-spec.github.io/lojadoiphone/
- Painel operacional: https://danielvitordelgado-spec.github.io/lojadoiphone/painel.html
- Supabase: projeto existente da organização Daniel Delgado, ref `wqstuzagsqpbgwydnoek`.
- As tabelas de operações anteriores foram PRESERVADAS. Este CRM usa EXCLUSIVAMENTE tabelas prefixadas `iphone_` e suas próprias políticas RLS.
- `config.js` contém somente URL e chave **publishable**, que pode ser lida pelo navegador. NUNCA adicionar secrets, service_role ou tokens da Meta.
- Migração já aplicada: `supabase/schema.sql`.
- Um membro administrador da LOJA DO IPHONE foi ativado usando conta já existente do Supabase Auth.
- Não foram criadas contas dos cinco vendedores, pois faltam seus respectivos e-mails.

## Atenção: confirmar e-mail do administrador
A conta existente de administrador ainda não tem `email_confirmed_at` preenchido. O painel possui o botão **Reenviar confirmação de e-mail**. Informe o e-mail correspondente, clique e confirme pela caixa de entrada. A disponibilidade do envio depende da configuração de e-mails do Supabase.

## Tabelas
- `public.iphone_team_members`: permite que apenas usuários expressamente autorizados participem deste CRM; papéis admin/seller
- `public.iphone_leads`: dados dos clientes e propriedade de cada lead
- `public.iphone_conversations`, `public.iphone_messages`: base para futura integração oficial do WhatsApp
- `public.iphone_campaigns`: campanhas e templates (ainda SEM disparo real)
- funções auxiliares de segurança no schema privado `iphone_private`

## Como adicionar vendedor
1. Em Supabase > Authentication > Users, cadastre/convidar a pessoa (sem postar senha em GitHub).
2. Faça o e-mail ser verificado.
3. No SQL Editor deste projeto, executar SQL com e-mail literal, substituindo o texto abaixo pela identidade real:
   ```sql
   insert into public.iphone_team_members(user_id,display_name,role,active)
   select id,'Nome do vendedor','seller',true
   from auth.users where lower(email)=lower('VENDEDOR@EXEMPLO.COM')
   on conflict (user_id) do update set
     display_name=excluded.display_name, role='seller', active=true;
   ```
4. O administrador pode ativar/desativar membros já cadastrados pela tela Equipe, mas não cria novas contas Auth por ali.

## Segurança
- Sem acesso anônimo à tabela de leads
- Vendedor vê somente leads atribuídos a ele, administrador vê todos
- Nenhum endpoint de envio real de WhatsApp implementado
- Projeto Supabase é compartilhado com outro CRM, então é necessário não alterar Auth globais, site URL ou tabelas comerciais existentes indiscriminadamente
- Foi verificado que 82 leads de outro sistema permaneceram intocados após a migração
- Security Advisor sinalizou o aviso **Leaked Password Protection Disabled**. Ver documentação do Supabase e disponibilidade por plano.

## Próximas etapas
- Confirmar login real com conta autorizada e e-mail verificado
- Convidar cinco vendedores; validar RLS para dois perfis reais
- Criar Inbox real + webhook Edge Function da Meta Cloud API e gestão segura de modelos de mensagem/consentimento
- Criar testes de autorização e backups apropriados antes de uso com dados reais

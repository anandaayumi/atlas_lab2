# Atlas CRM — laboratório

Aplicação de treinamento em português para acompanhar propostas B2B. O PostgreSQL do Supabase é a base comercial; CSV serve somente à carga inicial. O laboratório não processa cobrança nem envia e-mail.

## Estado desta entrega

- App Router com Next.js 16.4.4, React 19.2.0, TypeScript 5.9.3 e `@supabase/ssr` 0.12.7. Dependências diretas estão fixadas.
- Login por e-mail e senha do Supabase, sessão em cookies e proteção de rotas por `proxy.ts`.
- Dashboard, carteira com busca e filtros, criação/edição, detalhe e histórico.
- Migrações `20261104001344_atlas_crm_core.sql` e `20261104002520_atlas_crm_privilege_hardening.sql` aplicadas ao projeto Supabase `atlas_lab2`. RLS está habilitado; privilégios anônimos foram removidos e o advisor de segurança não apontou problemas.
- A função privada de Ganho exige `app_metadata.crm_role` igual a `gerente` ou `administrador`, atualiza a proposta e registra histórico + outbox pendente na mesma transação. Não há worker ou envio de e-mail nesta etapa.
- Exceções comerciais continuam visíveis na carteira e bloqueiam o Ganho automático.
- O PR rascunho #1 está aberto. Nenhum CSV ou segredo foi enviado ao GitHub.
- O workflow de validação agora usa um pin válido para `setup-node`; lint, build e lockfile serão confirmados quando a execução do GitHub Actions concluir.
- A equipe Vercel está autorizada, mas a conta GitHub ainda precisa de uma Login Connection na Vercel para vincular o repositório. Ainda não há deployment.

## Requisitos

- Node.js 20.9 ou superior.
- npm correspondente ao Node instalado. Gere e versione `package-lock.json` e use `npm ci` para reproduzir a instalação.
- Projeto Supabase de laboratório e usuário individual criado pelo administrador.

## Configuração local

1. Copie `.env.example` para `.env.local` e informe a URL e a chave publishable do projeto Supabase autorizado. Nunca use `service_role` no navegador nem versione `.env.local`.
2. Aplique as migrações em `supabase/migrations/` no projeto correto, depois de conferir as tabelas existentes e a configuração da turma.
3. Crie os usuários no Supabase Auth. O cadastro público não é habilitado pelo aplicativo.
4. Cadastre os dados de referência para o `owner_id` do usuário. Registros de aprovação exigem operação administrativa protegida; não aceite referência digitada como aprovação.
5. Importe a planilha uma única vez, somente depois de configurar a allowlist de e-mail em canal protegido. Não importe CSV bruto nem XLSX em paralelo; não inclua dados de clientes no GitHub.
6. Rode `npm ci`, `npm run dev` e abra `http://localhost:3000`.

## Dados e regras

- As tabelas comerciais carregam `owner_id`; as políticas RLS comparam com `auth.uid()`.
- Valores bruto, líquido, margem e ponderado são recalculados pelo gatilho PostgreSQL. Moeda é BRL e o fuso comercial é `America/Sao_Paulo`.
- Aprovação acima de 5% precisa existir no cadastro protegido e ser compatível. Margem inferior a 25% exige revisão.
- Ganho não pode ser definido no formulário nem por `UPDATE` comum. A função autorizada é o único caminho; o ganho torna a proposta imutável.
- A outbox apenas registra intenção pendente. Nenhum e-mail é enviado.
- Não há persistência comercial em `localStorage`.

## Verificações e testes

O workflow roda:

```sh
npm install --package-lock-only --ignore-scripts
npm ci
npm run lint
npm run build
```

Use `casos_teste.json` como matriz. Registre cada execução como simulada ou real e não marque integração de e-mail, isolamento entre usuários ou persistência real sem evidência do Supabase conectado. Antes de aceitar o laboratório, valide acesso anônimo, isolamento entre dois usuários, recálculo de valores, aprovação e margem, bloqueio de Ganho direto, idempotência/outbox e reconciliação da carga com resultados de referência.

## Publicação

Vincule `anandaayumi/atlas_lab2` à equipe Vercel autorizada, defina as duas variáveis `NEXT_PUBLIC_SUPABASE_*` como publicáveis e valide o preview com login e RLS antes de publicar. A conexão GitHub→Vercel depende de adicionar uma Login Connection na conta Vercel. Publique somente após confirmar o projeto Supabase indicado para a turma.

## Referências

- Contexto e identidade: `../Pacote_Passagem_Atlas/CONTEXTO-PARA-CODEX.txt` e `../Marca/atlas-tokens.json`.
- Contrato e política: `../Pacote_Passagem_Atlas/referencias/CONTRATO-CRM.txt` e `../Pacote_Passagem_Atlas/referencias/politica_comercial.txt`.
- Documentação oficial: [Next.js](https://nextjs.org/docs), [Supabase Auth SSR](https://supabase.com/docs/guides/auth/server-side), [Vercel com Next.js](https://vercel.com/docs/frameworks/nextjs).

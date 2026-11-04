# Atlas CRM — laboratório

Aplicação de treinamento em português para acompanhar propostas B2B. A base do CRM é o PostgreSQL do Supabase; CSV é somente carga inicial. O laboratório não processa cobrança nem envia e-mail.

## Estado desta entrega

- App Router com Next.js 16.4.4, React 19.2.0, TypeScript 5.9.3 e `@supabase/ssr` 0.12.7. Dependências estão fixadas sem intervalos.
- Login por e-mail e senha do Supabase, sessão em cookies e proteção de rotas por `proxy.ts`.
- Painel, carteira com busca e filtros, formulário de criação e edição, detalhe e histórico.
- As migrações de núcleo e de privilégios foram aplicadas ao projeto Supabase `atlas_lab2`. RLS está habilitado nas tabelas; grants anônimos foram removidos e os advisors de segurança retornaram sem achados.
- A função privada de Ganho exige `app_metadata.crm_role` igual a `gerente` ou `administrador`, atualiza a proposta e registra histórico + outbox pendente na mesma transação. Não há worker ou envio de e-mail nesta etapa.
- Exceções comerciais permanecem consultáveis na carteira; desconto/aprovação e margem são validados separadamente.
- A branch `codex/atlas-crm-lab` e o PR rascunho #1 estão no GitHub. Os CSVs foram omitidos do repositório.

Node.js/npm e Git não estão disponíveis neste ambiente. Assim, `package-lock.json`, lint/build e o fluxo autenticado ainda não foram executados. A equipe Vercel conectada ainda precisa conceder acesso a este vínculo MCP. A planilha não foi importada: falta confirmar a configuração segura de e-mail/allowlist prevista no contexto.

## Requisitos

- Node.js 20.9 ou superior (requisito mínimo documentado pelo Next.js atual).
- npm compatível com a versão de Node instalada; `package-lock.json` deverá ser gerado e versionado com `npm install` após a instalação das dependências.
- Projeto Supabase de laboratório e usuário individual criado pelo administrador.

## Configuração local

1. Copie `.env.example` para `.env.local` e informe a URL e a chave publishable do projeto Supabase autorizado. Nunca use `service_role` no navegador nem versione `.env.local`.
2. Aplique `supabase/migrations/202611030001_atlas_crm.sql` no projeto correto depois de conferir as tabelas existentes e obter o projeto indicado na configuração da turma.
3. Crie os usuários no Supabase Auth. O cadastro público não é habilitado pelo aplicativo.
4. Cadastre os dados de referência para o `owner_id` do usuário. Registros de aprovação exigem operação administrativa protegida; não aceite referência digitada como aprovação.
5. Quando a configuração segura do aceite estiver confirmada, importe uma única vez `../Pacote_Passagem_Atlas/dados/vendas_atlas_tratada.csv`. Não importe o CSV bruto nem o XLSX em paralelo. A coluna `email_aceite` desta cópia está vazia; não habilite aceites sem configurar a allowlist em canal protegido.
6. Instale dependências e gere o lockfile com `npm install`; rode `npm run dev` e abra `http://localhost:3000`.

## Dados e regras

- As tabelas comerciais carregam `owner_id`; as políticas RLS comparam com `auth.uid()`.
- Valores bruto, líquido, margem e ponderado são recalculados pelo gatilho PostgreSQL. Moeda é BRL e o fuso comercial é `America/Sao_Paulo`.
- Aprovação acima de 5% precisa existir no cadastro protegido e ser compatível. Margem inferior a 25% exige revisão.
- Ganho não pode ser definido no formulário nem por `UPDATE` comum. A função autorizada é o único caminho; o ganho torna a proposta imutável.
- A outbox apenas registra intenção pendente. Nenhum e-mail é enviado.
- Não há persistência comercial em `localStorage`.

## Verificações e testes

Depois de instalar Node e dependências:

```powershell
npm install
npm run lint
npm run build
npm run dev
```

Use `casos_teste.json` como matriz. Registre cada execução como simulada ou real e não marque integração de e-mail, isolamento entre usuários ou persistência real sem evidência do ambiente Supabase conectado. Antes da publicação, valide acesso anônimo, isolamento entre dois usuários, recálculo de valores, aprovação e margem, bloqueio de Ganho direto, idempotência/outbox e a reconciliação da carga com os resultados de referência do contexto.

## Publicação

Importe o repositório e a branch de revisão na equipe Vercel autorizada, configure as duas variáveis `NEXT_PUBLIC_SUPABASE_*` como publicáveis e rode o build. Use preview protegido para validar login e RLS; só publique após confirmar o projeto Supabase e a equipe no arquivo de configuração da turma.

## Referências

- Contexto e identidade: `../Pacote_Passagem_Atlas/CONTEXTO-PARA-CODEX.txt` e `../Marca/atlas-tokens.json`.
- Contrato e política: `../Pacote_Passagem_Atlas/referencias/CONTRATO-CRM.txt` e `../Pacote_Passagem_Atlas/referencias/politica_comercial.txt`.
- Next.js, Supabase Auth SSR, compatibilidade Vercel e versões consultadas: [Next.js](https://nextjs.org/docs), [Supabase SSR](https://supabase.com/docs/guides/auth/server-side), [Vercel com Next.js](https://vercel.com/docs/frameworks/nextjs).

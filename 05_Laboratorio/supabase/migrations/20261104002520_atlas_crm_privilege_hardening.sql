-- Remove Supabase default broad table grants; RLS does not protect TRUNCATE.
revoke all on table public.clientes, public.vendedores, public.produtos, public.metas,
  public.aprovacoes, public.propostas, public.historico_propostas,
  public.email_processamentos, public.email_outbox, public.atlas_import_batches
from public, anon, authenticated;

grant select, insert, update, delete on table public.clientes, public.vendedores,
  public.produtos, public.metas to authenticated;
grant select, insert, update on table public.propostas to authenticated;
grant select on table public.historico_propostas, public.email_processamentos,
  public.email_outbox, public.atlas_import_batches to authenticated;

drop policy if exists "owner read clientes" on public.clientes;
drop policy if exists "owner read vendedores" on public.vendedores;
drop policy if exists "owner read produtos" on public.produtos;
drop policy if exists "owner read metas" on public.metas;
drop policy if exists "owner read propostas" on public.propostas;
drop policy if exists "owner create propostas" on public.propostas;
drop policy if exists "owner edit propostas" on public.propostas;
drop policy if exists "owner read history" on public.historico_propostas;
drop policy if exists "owner read email processing" on public.email_processamentos;
drop policy if exists "owner read outbox" on public.email_outbox;
drop policy if exists "owner read batches" on public.atlas_import_batches;

drop policy if exists "owner manage clientes" on public.clientes;
create policy "owner manage clientes" on public.clientes for all to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists "owner manage vendedores" on public.vendedores;
create policy "owner manage vendedores" on public.vendedores for all to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists "owner manage produtos" on public.produtos;
create policy "owner manage produtos" on public.produtos for all to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists "owner manage metas" on public.metas;
create policy "owner manage metas" on public.metas for all to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

create policy "owner read propostas" on public.propostas for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "owner create propostas" on public.propostas for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "owner edit propostas" on public.propostas for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "owner read history" on public.historico_propostas for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "owner read email processing" on public.email_processamentos for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "owner read outbox" on public.email_outbox for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "owner read batches" on public.atlas_import_batches for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "approvals deny api roles" on public.aprovacoes for all to anon, authenticated
  using (false) with check (false);

create index if not exists propostas_owner_cliente_idx on public.propostas(owner_id,cliente_id);
create index if not exists propostas_owner_vendedor_idx on public.propostas(owner_id,vendedor_id);
create index if not exists propostas_owner_produto_idx on public.propostas(owner_id,produto_id);
create index if not exists propostas_owner_aprovacao_idx on public.propostas(owner_id,aprovacao_desconto);
create index if not exists historico_owner_proposta_idx on public.historico_propostas(owner_id,proposta_id,versao);
create index if not exists historico_owner_idx on public.historico_propostas(owner_id);
create index if not exists email_process_owner_idx on public.email_processamentos(owner_id);
create index if not exists email_outbox_owner_process_idx on public.email_outbox(owner_id,processamento_id);
create index if not exists email_outbox_process_idx on public.email_outbox(processamento_id);

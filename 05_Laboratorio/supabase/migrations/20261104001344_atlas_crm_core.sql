create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public,anon;
grant usage on schema private to authenticated;

create table if not exists public.clientes (
  owner_id uuid not null references auth.users(id) on delete cascade,
  cliente_id text not null, empresa text not null, contato text, email_aceite text,
  segmento text, regiao text, primary key(owner_id, cliente_id)
);
create table if not exists public.vendedores (
  owner_id uuid not null references auth.users(id) on delete cascade,
  vendedor_id text not null, nome text not null, regiao text,
  primary key(owner_id, vendedor_id)
);
create table if not exists public.produtos (
  owner_id uuid not null references auth.users(id) on delete cascade,
  produto_id text not null, nome text not null, preco_unitario numeric(14,2) not null check(preco_unitario > 0),
  custo_unitario numeric(14,2) not null check(custo_unitario >= 0), escopo text,
  primary key(owner_id, produto_id)
);
create table if not exists public.metas (
  owner_id uuid not null references auth.users(id) on delete cascade,
  mes date not null, meta_vendas_ganhas numeric(14,2) not null check(meta_vendas_ganhas >= 0),
  primary key(owner_id, mes)
);
create table if not exists public.aprovacoes (
  owner_id uuid not null references auth.users(id) on delete cascade,
  aprovacao_id text not null, proposta_id text, lote text, versao integer,
  limite_desconto numeric not null check(limite_desconto between 0 and 1), aprovador text not null, aprovado_em timestamptz not null,
  primary key(owner_id, aprovacao_id), check(proposta_id is not null or lote is not null)
);
create table if not exists public.propostas (
  owner_id uuid not null references auth.users(id) on delete cascade,
  proposta_id text not null check(proposta_id ~ '^ATL-2026-[0-9]{4}$'), versao integer not null check(versao > 0), vigente boolean not null default true,
  cliente_id text not null, vendedor_id text not null, produto_id text not null, regiao text not null, canal text not null,
  data_criacao date not null, data_fechamento date, validade date not null,
  etapa text not null check(etapa in ('Qualificacao','Proposta','Negociacao','Ganho','Perdido')),
  quantidade integer not null check(quantidade > 0), preco_unitario numeric(14,2) not null check(preco_unitario > 0),
  desconto_pct numeric not null default 0 check(desconto_pct between 0 and 1), custo_total numeric(14,2) not null check(custo_total >= 0),
  aprovacao_desconto text, probabilidade numeric not null default 0 check(probabilidade between 0 and 1), condicao_pagamento text not null default '50% no aceite e 50% na entrega',
  motivo_perda text, proxima_acao text, valor_bruto numeric(14,2) not null default 0, valor_liquido numeric(14,2) not null default 0,
  margem_pct numeric not null default 0, valor_ponderado numeric(14,2) not null default 0, row_version integer not null default 1,
  updated_at timestamptz not null default now(), batch_id text,
  primary key(owner_id, proposta_id, versao),
  foreign key(owner_id,cliente_id) references public.clientes(owner_id,cliente_id),
  foreign key(owner_id,vendedor_id) references public.vendedores(owner_id,vendedor_id),
  foreign key(owner_id,produto_id) references public.produtos(owner_id,produto_id),
  foreign key(owner_id,aprovacao_desconto) references public.aprovacoes(owner_id,aprovacao_id),
  check(data_fechamento is null or data_fechamento >= data_criacao),
  check(etapa <> 'Perdido' or motivo_perda in ('Preco','Prazo','Concorrente')),
  check(etapa not in ('Ganho','Perdido') or data_fechamento is not null)
);
create unique index if not exists propostas_uma_vigente on public.propostas(owner_id,proposta_id) where vigente;
create table if not exists public.historico_propostas (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  proposta_id text not null, versao integer not null, "de" text, "para" text not null, ocorrido_em timestamptz not null default now(),
  origem text not null, provider_message_id text, ator uuid,
  foreign key(owner_id,proposta_id,versao) references public.propostas(owner_id,proposta_id,versao)
);
create table if not exists public.email_processamentos (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  mailbox_id text not null, provider_message_id text not null, provider_thread_id text, recebido_em timestamptz,
  codigo_extraido text, versao_extraida integer, decisao text not null, motivo text, estado text not null, correlation_id uuid not null default gen_random_uuid(),
  unique(mailbox_id,provider_message_id), unique(owner_id,id)
);
create table if not exists public.email_outbox (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  proposta_id text not null, versao integer not null, processamento_id uuid not null references public.email_processamentos(id), tipo_confirmacao text not null default 'aceite',
  destinatario_validado text not null, assunto text not null, corpo text not null, estado text not null default 'pendente',
  provider_sent_message_id text, tentativas integer not null default 0, erro text, updated_at timestamptz not null default now(),
  unique(owner_id,proposta_id,versao,tipo_confirmacao),
  foreign key(owner_id,proposta_id,versao) references public.propostas(owner_id,proposta_id,versao),
  foreign key(owner_id,processamento_id) references public.email_processamentos(owner_id,id)
);

create or replace function private.atlas_recalcular_proposta() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_prob numeric; v_valor numeric(14,2); v_aprovacao public.aprovacoes%rowtype;
begin
  if tg_op = 'UPDATE' then
    if old.etapa = 'Ganho' and (new.etapa <> old.etapa or new.preco_unitario <> old.preco_unitario or new.desconto_pct <> old.desconto_pct or new.custo_total <> old.custo_total or new.quantidade <> old.quantidade or new.data_fechamento <> old.data_fechamento) then
      raise exception 'Propostas ganhas são imutáveis neste laboratório';
    end if;
    if new.etapa = 'Ganho' and old.etapa <> 'Ganho' and coalesce(current_setting('atlas.registrar_ganho',true),'off') <> 'on' then raise exception 'Ganho só pode ser registrado pela função autorizada'; end if;
    if new.owner_id <> auth.uid() then raise exception 'Proprietário inválido'; end if;
    if new.aprovacao_desconto is distinct from old.aprovacao_desconto and coalesce(auth.jwt()->'app_metadata'->>'crm_role','') not in ('gerente','administrador') then raise exception 'Somente alçada autorizada altera aprovações'; end if;
  end if;
  if new.desconto_pct > 0.05 then
    select * into v_aprovacao from public.aprovacoes a where a.owner_id=new.owner_id and a.aprovacao_id=new.aprovacao_desconto
      and a.limite_desconto >= new.desconto_pct and (a.proposta_id is null or a.proposta_id=new.proposta_id)
      and (a.versao is null or a.versao=new.versao) and (a.lote is null or a.lote=new.batch_id);
    if not found then raise exception 'Aprovação comercial compatível obrigatória'; end if;
  end if;
  v_valor := round(new.quantidade * new.preco_unitario * (1-new.desconto_pct),2);
  if v_valor = 0 then raise exception 'Valor líquido zero exige revisão'; end if;
  if (v_valor-new.custo_total)/v_valor < 0.25 then raise exception 'Margem abaixo de 25%% exige revisão'; end if;
  new.valor_bruto := round(new.quantidade*new.preco_unitario,2); new.valor_liquido := v_valor;
  new.margem_pct := (v_valor-new.custo_total)/v_valor;
  v_prob := case new.etapa when 'Qualificacao' then .20 when 'Proposta' then .50 when 'Negociacao' then .75 when 'Ganho' then 1 else 0 end;
  new.probabilidade := v_prob; new.valor_ponderado := case when new.etapa in ('Ganho','Perdido') then 0 else round(v_valor*v_prob,2) end;
  new.updated_at := now();
  if tg_op='UPDATE' then new.row_version := old.row_version+1; else new.row_version := 1; end if;
  return new;
end $$;
drop trigger if exists propostas_recalcular on public.propostas;
create trigger propostas_recalcular before insert or update on public.propostas for each row execute function private.atlas_recalcular_proposta();
revoke all on function private.atlas_recalcular_proposta() from public,anon,authenticated;

create or replace function private.atlas_registrar_historico() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op='INSERT' then
    insert into public.historico_propostas(owner_id,proposta_id,versao,"para",origem,ator)
    values(new.owner_id,new.proposta_id,new.versao,'Criada','cadastro',auth.uid());
  elsif row(old.etapa,old.validade,old.preco_unitario,old.desconto_pct,old.quantidade,old.custo_total,old.proxima_acao)
     is distinct from row(new.etapa,new.validade,new.preco_unitario,new.desconto_pct,new.quantidade,new.custo_total,new.proxima_acao) then
    insert into public.historico_propostas(owner_id,proposta_id,versao,"de","para",origem,provider_message_id,ator)
    values(new.owner_id,new.proposta_id,new.versao,old.etapa,new.etapa,
      coalesce(nullif(current_setting('atlas.origem',true),''),'edicao'),nullif(current_setting('atlas.provider_message_id',true),''),auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists propostas_historico on public.propostas;
create trigger propostas_historico after insert or update on public.propostas for each row execute function private.atlas_registrar_historico();
revoke all on function private.atlas_registrar_historico() from public,anon,authenticated;

create or replace function private.atlas_registrar_ganho(p_proposta_id text,p_versao integer,p_provider_message_id text,p_destinatario text,p_assunto text,p_corpo text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_owner uuid := auth.uid(); v_role text; p public.propostas%rowtype; v_process uuid;
begin
  select coalesce(auth.jwt()->'app_metadata'->>'crm_role','') into v_role;
  if v_owner is null or v_role not in ('gerente','administrador') then raise exception 'Somente alçada comercial autorizada pode registrar Ganho'; end if;
  select * into p from public.propostas where owner_id=v_owner and proposta_id=p_proposta_id and versao=p_versao and vigente for update;
  if not found then raise exception 'Proposta vigente não encontrada'; end if;
  if p.etapa='Ganho' then return jsonb_build_object('resultado','no_op','proposta_id',p_proposta_id); end if;
  if p.etapa not in ('Proposta','Negociacao') then raise exception 'Etapa não elegível'; end if;
  if p.validade < (now() at time zone 'America/Sao_Paulo')::date then raise exception 'Proposta vencida'; end if;
  if p.desconto_pct > 0.15 then raise exception 'Desconto acima de 15%% exige revisão; Ganho automático bloqueado'; end if;
  perform pg_catalog.set_config('atlas.registrar_ganho','on',true);
  perform pg_catalog.set_config('atlas.origem','aceite_validado',true);
  perform pg_catalog.set_config('atlas.provider_message_id',p_provider_message_id,true);
  update public.propostas set etapa='Ganho',data_fechamento=(now() at time zone 'America/Sao_Paulo')::date where owner_id=v_owner and proposta_id=p_proposta_id and versao=p_versao;
  insert into public.email_processamentos(owner_id,mailbox_id,provider_message_id,codigo_extraido,versao_extraida,decisao,estado)
  values(v_owner,'disabled','manual:'||p_provider_message_id,p_proposta_id,p_versao,'aceite','registrado') returning id into v_process;
  insert into public.email_outbox(owner_id,proposta_id,versao,processamento_id,destinatario_validado,assunto,corpo,estado)
  values(v_owner,p_proposta_id,p_versao,v_process,p_destinatario,p_assunto,p_corpo,'pendente') on conflict(owner_id,proposta_id,versao,tipo_confirmacao) do nothing;
  return jsonb_build_object('resultado','registrado','proposta_id',p_proposta_id);
end $$;

alter table public.clientes enable row level security;
alter table public.vendedores enable row level security;
alter table public.produtos enable row level security;
alter table public.metas enable row level security;
alter table public.aprovacoes enable row level security;
alter table public.propostas enable row level security;
alter table public.historico_propostas enable row level security;
alter table public.email_processamentos enable row level security;
alter table public.email_outbox enable row level security;
create policy "owner read clientes" on public.clientes for select to authenticated using(owner_id=auth.uid());
create policy "owner manage clientes" on public.clientes for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner read vendedores" on public.vendedores for select to authenticated using(owner_id=auth.uid());
create policy "owner manage vendedores" on public.vendedores for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner read produtos" on public.produtos for select to authenticated using(owner_id=auth.uid());
create policy "owner manage produtos" on public.produtos for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner read metas" on public.metas for select to authenticated using(owner_id=auth.uid());
create policy "owner manage metas" on public.metas for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner read propostas" on public.propostas for select to authenticated using(owner_id=auth.uid());
create policy "owner create propostas" on public.propostas for insert to authenticated with check(owner_id=auth.uid());
create policy "owner edit propostas" on public.propostas for update to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy "owner read history" on public.historico_propostas for select to authenticated using(owner_id=auth.uid());
create policy "owner read email processing" on public.email_processamentos for select to authenticated using(owner_id=auth.uid());
create policy "owner read outbox" on public.email_outbox for select to authenticated using(owner_id=auth.uid());
revoke all on public.aprovacoes,public.historico_propostas,public.email_processamentos,public.email_outbox from anon,authenticated;
grant select on public.historico_propostas,public.email_processamentos,public.email_outbox to authenticated;
revoke all on function private.atlas_registrar_ganho(text,integer,text,text,text,text) from public,anon;
grant execute on function private.atlas_registrar_ganho(text,integer,text,text,text,text) to authenticated;

create table if not exists public.atlas_import_batches(owner_id uuid primary key references auth.users(id) on delete cascade,batch_id text not null,source_sha256 text not null,imported_at timestamptz not null default now(),row_count integer not null);
alter table public.atlas_import_batches enable row level security;
create policy "owner read batches" on public.atlas_import_batches for select to authenticated using(owner_id=auth.uid());

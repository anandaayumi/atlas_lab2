-- Consultas de leitura para o modelo definido em CONTRATO-CRM.txt.
-- Execute com a sessão autenticada do aluno e RLS ativo.
-- O valor :owner_id é um parâmetro do cliente SQL; use o UUID autorizado.
-- NÃO são migrações. Dependem das tabelas criadas por P07.

-- Contagem por etapa, apenas versões vigentes.
select etapa, count(*) as quantidade, sum(valor_liquido) as valor_liquido
from public.propostas
where owner_id = :owner_id and vigente
group by etapa order by etapa;

-- Vendas históricas, independente de novos ganhos em novembro.
select sum(valor_liquido) as vendas_ganhas_maio_outubro
from public.propostas
where owner_id = :owner_id and vigente and etapa = 'Ganho'
  and data_fechamento >= date '2026-05-01'
  and data_fechamento < date '2026-11-01';

-- Histórico do teste e estado separado de envio.
select proposta_id, versao, de, para, ocorrido_em, provider_message_id
from public.historico_propostas
where owner_id = :owner_id and proposta_id = 'ATL-2026-0118'
order by ocorrido_em;

select proposta_id, versao, estado, provider_sent_message_id, tentativas
from public.email_outbox
where owner_id = :owner_id and proposta_id = 'ATL-2026-0118';

-- Não devem existir dois registros vigentes de um mesmo código.
select proposta_id, count(*)
from public.propostas
where owner_id = :owner_id and vigente
group by proposta_id having count(*) > 1;

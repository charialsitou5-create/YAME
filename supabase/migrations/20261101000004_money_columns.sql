-- Ajustements découverts en lisant la logique financière de yame-admin (lib/services/*) :
-- le portefeuille a DEUX soldes (balance = recharge non retirable, earningsBalance = gains retirables),
-- et les retraits/transactions portent des champs de suivi supplémentaires.

alter table public.driver_wallets
  add column earnings_balance bigint not null default 0,
  add column last_recharge_at timestamptz;

-- Retrait : statut « paid » + champs de suivi
alter table public.withdrawal_requests drop constraint withdrawal_requests_status_check;
alter table public.withdrawal_requests
  add constraint withdrawal_requests_status_check
    check (status in ('requested', 'approved', 'paid', 'rejected', 'failed')),
  add column paid_by text,
  add column paid_at timestamptz,
  add column payment_reference text,
  add column failure_reason text,
  add column failed_by text,
  add column failed_at timestamptz,
  add column approved_by text,
  add column approved_at timestamptz;

-- Transactions : champs lus par les pages Finance / Transactions
alter table public.transactions
  add column provider text,
  add column phone_number text,
  add column balance_after bigint,
  add column commission_amount bigint,
  add column driver_net_amount bigint,
  add column commission_credit bigint,
  add column payment_reference text,
  add column paid_at timestamptz,
  add column reversed_at timestamptz,
  add column reason text,
  add column note text,
  add column raw_payload jsonb;

-- Remboursements : champs écrits par refundRide()
alter table public.refunds
  add column paid_amount bigint,
  add column reason text,
  add column earnings_debit bigint,
  add column commission_credit bigint,
  add column driver_earnings_negative boolean not null default false;

-- Course : date de remboursement
alter table public.ride_requests add column refunded_at timestamptz;

-- Les soldes ne sont jamais écrits par un client : RLS déjà sans policy d'écriture sur driver_wallets
-- (hors création à 0). Verrou supplémentaire : la création client ne peut pas poser earnings_balance.
drop policy driver_wallets_insert on public.driver_wallets;
create policy driver_wallets_insert on public.driver_wallets for insert to authenticated
  with check (driver_uid = public.uid() and balance = 0 and earnings_balance = 0);

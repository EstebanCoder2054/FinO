-- Fake demo data only. Do not use real financial information.

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  created_at,
  updated_at
) values (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated',
  'authenticated',
  'demo@finoai.local',
  crypt('demo-password', gen_salt('bf')),
  now(),
  now(),
  now()
) on conflict (id) do nothing;

insert into public.expenses (
  user_id,
  amount,
  currency,
  category,
  description,
  merchant,
  source,
  raw_input,
  confidence
) values
(
  '00000000-0000-0000-0000-000000000001',
  1000000.00,
  'COP',
  'groceries',
  'mercado',
  null,
  'seed',
  'Me gasté un millón de pesos en el mercado.',
  0.970
),
(
  '00000000-0000-0000-0000-000000000001',
  45000.00,
  'COP',
  'transportation',
  'Uber',
  'Uber',
  'seed',
  'Gasté 45 mil en Uber.',
  0.960
),
(
  '00000000-0000-0000-0000-000000000001',
  180000.00,
  'COP',
  'shopping',
  'camisa',
  null,
  'seed',
  'Compré una camisa por 180 mil.',
  0.940
);

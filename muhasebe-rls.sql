-- İstiklal Muhasebe + Kolaysoft Köprüsü için izinler
-- Not: ayar tablosunda GRANT'lar (anon, service_role) todo kurulumunda zaten verildi.
-- Burada SADECE anon rolünün 'muh_' ile başlayan anahtarları okuyup yazmasına izin veriyoruz.
-- Diğer veriler (puan müşterileri, hasta vb.) anon'a KAPALI kalır. Mevcut hiçbir şey silinmez/değişmez.

do $$
begin
  if not exists (select 1 from pg_policies where tablename='ayar' and policyname='muh_anon_select') then
    create policy muh_anon_select on public.ayar for select to anon using (anahtar like 'muh\_%');
  end if;
  if not exists (select 1 from pg_policies where tablename='ayar' and policyname='muh_anon_insert') then
    create policy muh_anon_insert on public.ayar for insert to anon with check (anahtar like 'muh\_%');
  end if;
  if not exists (select 1 from pg_policies where tablename='ayar' and policyname='muh_anon_update') then
    create policy muh_anon_update on public.ayar for update to anon using (anahtar like 'muh\_%') with check (anahtar like 'muh\_%');
  end if;
end $$;

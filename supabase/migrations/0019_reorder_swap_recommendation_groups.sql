-- ---------------------------------------------------------------------------
-- Herindeling van de swap-aanbevelingsgroepen op verzoek: 4 groepen, in deze
-- volgorde -- Minder kcal, Meer eiwitten, Minder suiker, Overall betere
-- suggestie (algehele ranking, nu als laatste i.p.v. eerste). "Minder
-- bewerkt" en "Zelfde smaak, kleinere portie" blijven in de tabel staan
-- (geen rijen verwijderd) maar worden gedeactiveerd i.p.v. getoond.
-- ---------------------------------------------------------------------------
update public.swap_recommendation_groups set sort_order = 10 where slug = 'minder_kcal';
update public.swap_recommendation_groups set sort_order = 20 where slug = 'meer_eiwit';
update public.swap_recommendation_groups set sort_order = 30 where slug = 'minder_suiker';
update public.swap_recommendation_groups set sort_order = 40, label = 'Overall betere suggestie'
  where slug = 'beste_keuze_vandaag';
update public.swap_recommendation_groups set is_active = false
  where slug in ('minder_bewerkt', 'zelfde_smaak_kleinere_portie');

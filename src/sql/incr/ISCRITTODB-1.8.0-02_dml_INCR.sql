
----------------------------------------------------------------------
-- 2019-10-14 - IS-409
----------------------------------------------------------------------
update iscritto_d_tipo_all set
  cod_tipo_allegato = 'SER',
  descrizione = 'Certificazione di disagio sociale'
where cod_tipo_allegato = 'ALT';

update iscritto_d_condizione_pun set
  id_tipo_allegato = 4,
  id_tipo_istruttoria = 2
where id_condizione_punteggio = 5;

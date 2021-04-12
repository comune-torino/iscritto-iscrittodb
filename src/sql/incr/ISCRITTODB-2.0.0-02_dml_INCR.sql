
----------------------------------------------------------------------
-- 2019-10-30 - ISBO-329
-- L'attivita' ed il profilo con id 4 sono già presenti
----------------------------------------------------------------------
UPDATE iscritto_t_attivita SET
  link='/graduatorie/anagrafica',
  cod_attivita='GRA_ANAG'
WHERE id_attivita = 4;

UPDATE iscritto_t_privilegio SET
  cod_privilegio='P_GRA_ANAG'
WHERE id_privilegio = 4;

----------------------------------------------------------------------
-- 2019-11-18 - IS-375
----------------------------------------------------------------------
INSERT INTO iscritto_d_stato_scu (id_stato_scu, cod_stato_scu, descrizione)
VALUES (12, 'ANN', 'Annullata dal richiedente');

----------------------------------------------------------------------
-- 2019-11-19 - IS-375
----------------------------------------------------------------------
INSERT INTO iscritto_d_stato_dom (id_stato_dom, cod_stato_dom, descrizione)
VALUES (9, 'CAN', 'Annullata dal richiedente');

----------------------------------------------------------------------
-- 2019-11-21 - IS-375
----------------------------------------------------------------------

INSERT INTO iscritto_d_condizione_pun
( cod_condizione,
  descrizione,
  id_condizione_punteggio,
  fl_istruttoria,
  id_tipo_istruttoria,
  id_tipo_allegato
)
VALUES
('PA_5_ANNI','Punteggio aggiuntivo per bimbo di 5 anni',27,'P',1,null);

INSERT INTO iscritto_d_condizione_pun
(
  cod_condizione,
  descrizione,
  id_condizione_punteggio,
  fl_istruttoria,
  id_tipo_istruttoria,
  id_tipo_allegato
)
VALUES
('LA_PER_MAT','Ogni permanenza in lista d attesa al termine dei precedenti anni educativi',28,'P',1,null);

INSERT INTO iscritto_d_condizione_pun
(
  cod_condizione,
  descrizione,
  id_condizione_punteggio,
  fl_istruttoria,
  id_tipo_istruttoria,
  id_tipo_allegato
)
VALUES
('PA_FR_CONT','Fratello frequentante un nido comunale contiguo',29,'P',1,null);

----------------------------------------------------------------------
-- 2019-11-15 - #### ISBO-287
----------------------------------------------------------------------

INSERT INTO iscritto.iscritto_d_condizione_pun (cod_condizione,descrizione,id_condizione_punteggio,fl_istruttoria,id_tipo_istruttoria,id_tipo_allegato)
VALUES ('PA_PRB_SAL_MIN','Gravi problemi di salute del bambino',24,'P',3,2);
INSERT INTO iscritto.iscritto_d_condizione_pun (cod_condizione,descrizione,id_condizione_punteggio,fl_istruttoria,id_tipo_istruttoria,id_tipo_allegato)
VALUES ('PA_PRB_SAL_ALT','Gravi problemi di persona presente nel nucleo familiare',25,'P',3,2);

INSERT INTO iscritto.iscritto_t_punteggio (id_punteggio,punti,dt_inizio_validita,id_condizione_punteggio)
VALUES (24,150,'2019-01-01 00:00:00.000',24);
INSERT INTO iscritto.iscritto_t_punteggio (id_punteggio,punti,dt_inizio_validita,id_condizione_punteggio)
VALUES (25,150,'2019-01-01 00:00:00.000',25);

----------------------------------------------------------------------
-- 2019-11-15 - ## ISBO - 288
----------------------------------------------------------------------

INSERT INTO iscritto.iscritto_d_condizione_pun (cod_condizione,descrizione,id_condizione_punteggio,fl_istruttoria,id_tipo_istruttoria)
VALUES ('RES_TO_FUT_NOTE','Famiglie prossimamente residenti a Torino',26,'P',1);

INSERT INTO iscritto.iscritto_t_punteggio (id_punteggio,punti,dt_inizio_validita,id_condizione_punteggio)
VALUES (26,20000,'2019-01-01 00:00:00.000',26);

----------------------------------------------------------------------
-- 2019-12-02 - R31
----------------------------------------------------------------------
INSERT INTO iscritto_t_attivita
(id_attivita, cod_attivita, descrizione, link, id_funzione, ordinamento)
VALUES(16, 'DOM_MOD', 'Modifica stato scuola di preferenza', '/domande/preferenze/ricerca', 1, NULL);

INSERT INTO iscritto_t_privilegio
(id_privilegio, cod_privilegio, descrizione, id_attivita)
VALUES(22, 'P_DOM_MOD', 'Modifica stato scuola di preferenza', 16);

-- superuser
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(1, 22, '');

-- uffici centrali
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(2, 22, '');
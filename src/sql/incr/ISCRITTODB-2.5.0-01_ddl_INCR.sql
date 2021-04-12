-------------------------------------------------------------------------------------------------------
-- DDL
-------------------------------------------------------------------------------------------------------
-- Lascio come traccia -- sospesa,da verificare
-- ALTER TABLE iscritto_t_utente DROP CONSTRAINT iscritto_t_utente_id_profilo_fkey;
-- ALTER TABLE iscritto_t_utente DROP id_profilo;

CREATE SEQUENCE iscritto_t_log_ff_id_log_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807;

CREATE TABLE ISCRITTO_D_CIRCOSCRIZIONE (
	ID_CIRCOSCRIZIONE	integer CONSTRAINT iscritto_d_circoscrizione_pkey PRIMARY KEY,
    COD_CIRCOSCRIZIONE	varchar(10) NOT NULL,
	DESCRIZIONE		varchar(256) NOT NULL
);

CREATE TABLE ISCRITTO_D_QUARTIERE (
	id_quartiere int4 NOT NULL,
	descrizione varchar(100) NOT NULL,
	id_circoscrizione int4 NULL,
	CONSTRAINT iscritto_d_quartiere_pkey PRIMARY KEY (id_quartiere)
);

ALTER TABLE iscritto_d_quartiere
ADD CONSTRAINT iscritto_d_quartiere_id_circ_fkey
FOREIGN KEY (id_circoscrizione)
REFERENCES iscritto_d_circoscrizione(id_circoscrizione);

CREATE TABLE iscritto_d_tipo_graduatoria (
	id_tipo_grad int4 NOT NULL,
	cod_tipo_grad bpchar(5) NULL,
	desc_tipo_grad varchar(512) NULL,
	CONSTRAINT iscritto_d_tipo_graduatoria_pkey PRIMARY KEY (id_tipo_grad)
);

CREATE TABLE iscritto_t_log_ff (
	id_log numeric NOT NULL DEFAULT nextval('iscritto_t_log_ff_id_log_seq'::regclass),
	d_inizio_elab timestamp NULL DEFAULT clock_timestamp(),
	d_fine_elab timestamp NULL,
	proc_log varchar(100) NULL,
	nota_log varchar(1000) NULL,
	CONSTRAINT pk_iscritto_t_log_ff PRIMARY KEY (id_log)
);

CREATE TABLE ISCRITTO_T_AZZONAMENTO (
	ID_CIVICO		integer not NULL,
	ID_QUARTIERE	integer not NULL
);

ALTER TABLE iscritto_t_azzonamento
ADD CONSTRAINT iscritto_t_azzonamento_pkey
PRIMARY KEY (ID_CIVICO,ID_QUARTIERE);

ALTER TABLE iscritto_t_azzonamento
ADD CONSTRAINT iscritto_t_azzonamento_id_quart_fkey
FOREIGN KEY (id_quartiere)
REFERENCES iscritto_d_quartiere(id_quartiere);

ALTER TABLE iscritto_r_scuola_pre ADD COLUMN id_tipo_grad integer default 0;

ALTER TABLE iscritto_t_cambio_res ADD COLUMN indirizzo varchar(100);

ALTER TABLE iscritto_t_domanda_isc ADD COLUMN fl_irc varchar(1);

ALTER TABLE iscritto_t_indirizzo_res ADD COLUMN id_civico integer;

ALTER TABLE iscritto_t_scuola ADD COLUMN quartiere integer;

ALTER TABLE iscritto_t_scuola ADD COLUMN tipo_rest char(2);

COMMENT ON COLUMN iscritto_t_domanda_isc.fl_irc IS 'Indica la scelta di insegnamento della religione cattolica per scuole comunali/statali';

COMMENT ON COLUMN ISCRITTO_T_SCUOLA.TIPO_REST IS 'S = restituzione standard; SU = scuola europea; SE = scuola ebraica';

ALTER TABLE ISCRITTO_T_FREQ_NIDO_SISE ALTER COLUMN cod_fascia type varchar(10);

ALTER TABLE iscritto_r_profilo_scuole
  ADD CONSTRAINT iscritto_r_profilo_scuole_id_scuola_fkey
  FOREIGN KEY (id_scuola)
  REFERENCES iscritto_t_scuola (id_scuola);

ALTER TABLE iscritto_r_scuola_pre
  ADD CONSTRAINT iscritto_r_scuola_pre_id_tipo_grad_fkey
  FOREIGN KEY (id_tipo_grad)
  REFERENCES iscritto_d_tipo_graduatoria (id_tipo_grad);
 
ALTER TABLE iscritto_r_utente_profilo
  ADD CONSTRAINT iscritto_r_utente_profilo_id_profilo_fkey
  FOREIGN KEY (id_profilo)
  REFERENCES iscritto_d_profilo (id_profilo);
 
ALTER TABLE ISCRITTO_T_STEP_GRA_CON
  ADD CONSTRAINT iscritto_t_step_gra_con_id_stato_gra_fkey 
  FOREIGN KEY (id_stato_gra) 
  REFERENCES ISCRITTO_D_STATO_GRA(id_stato_gra);

 -------
 
INSERT INTO iscritto_d_profilo (id_profilo, codice_profilo, descrizione) VALUES(11, 'P11', 'ECONOMA MATERNA COMUNALE');
INSERT INTO iscritto_d_profilo (id_profilo, codice_profilo, descrizione) VALUES(12, 'P12', 'ECONOMA MATERNA STATALE o CONVENZIONATA');

INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('PA_5_ANNI', 'Punteggio aggiuntivo per bimbo di 5 anni', 27, 'P', 1, NULL);
INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('LA_PER_MAT', 'Ogni permanenza in lista d attesa al termine dei precedenti anni educativi', 28, 'P', 1, NULL);
INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('PP_FR_CONT', 'Fratello frequentante un nido comunale contiguo', 29, 'P', 1, NULL);
INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('TR_TRA_MAT', 'Trasferimento da scuola d''infanzia della citta''', 30, 'P', 1, NULL);
INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('CF_FRA_FRE_MAT', 'Presenza di fratelli/sorelle frequentanti la scuola d''infanizia di prima scelta', 31, 'P', 1, NULL);
INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('CF_FRA_ISC_MAT', 'Presenza di fratelli/sorelle iscrivendi la stessa scuola d''infanizia', 32, 'P', NULL, NULL);
INSERT INTO iscritto_d_condizione_pun (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('XT_PT_AGG', 'Punteggio aggiuntivo 1^ scelta convenzionate/statali', 33, 'N', NULL, NULL);
INSERT INTO ISCRITTO_D_CONDIZIONE_PUN (cod_condizione, descrizione, id_condizione_punteggio, fl_istruttoria, id_tipo_istruttoria, id_tipo_allegato) VALUES('RES_TO_EXTRA','Punteggio aggiuntivo per vicinanza scuola a residenza',34,'P',1,NULL);

INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES(12, 4);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES(12, 31);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES(12, 34);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES(2, 28);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES(12, 32);

delete from iscritto_r_profilo_pri where id_profilo = 10;
delete from iscritto_d_profilo where id_profilo = 10;

INSERT INTO iscritto_t_privilegio (id_privilegio, cod_privilegio, descrizione, id_attivita) VALUES(25, 'P_RIC_DOM_ECO_COM', 'Ricerca Domande: Visualizzazione domanda economa materna comunale', 1);
INSERT INTO iscritto_t_privilegio (id_privilegio, cod_privilegio, descrizione, id_attivita) VALUES(26, 'P_RIC_DOM_ECO_STA', 'Ricerca Domande: Visualizzazione domanda economa materna statale e convenzionata', 1);
INSERT INTO iscritto_t_privilegio (id_privilegio, cod_privilegio, descrizione, id_attivita) VALUES(27, 'P_ISTR_PRE_STA', 'Istruttoria: Verifiche preventive econome statali e convenzionate', 1);

INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(11, 1, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(11, 5, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(11, 12, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(11, 23, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(11, 25, '1');

INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(12, 1, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(12, 5, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(12, 12, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(12, 23, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(12, 26, '1');
INSERT INTO iscritto_r_profilo_pri (id_profilo, id_privilegio, fl_rw) VALUES(12, 27, '1');

INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(27, 20000, '2019-01-01 00:00:00.000', NULL, 1, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(28, 10000, '2019-01-01 00:00:00.000', NULL, 2, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(29, 0, '2019-01-01 00:00:00.000', NULL, 3, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(30, 600, '2019-01-01 00:00:00.000', NULL, 4, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(31, 300, '2019-01-01 00:00:00.000', NULL, 5, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(33, 59, '2019-01-01 00:00:00.000', NULL, 7, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(34, 36, '2019-01-01 00:00:00.000', NULL, 8, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(35, 22, '2019-01-01 00:00:00.000', NULL, 9, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(36, 12, '2019-01-01 00:00:00.000', NULL, 10, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(38, 22, '2019-01-01 00:00:00.000', NULL, 12, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(39, 11, '2019-01-01 00:00:00.000', NULL, 13, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(40, 6, '2019-01-01 00:00:00.000', NULL, 14, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(41, 27, '2019-01-01 00:00:00.000', NULL, 15, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(42, 27, '2019-01-01 00:00:00.000', NULL, 16, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(43, 19, '2019-01-01 00:00:00.000', NULL, 17, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(44, 13, '2019-01-01 00:00:00.000', NULL, 18, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(48, 20000, '2019-01-01 00:00:00.000', NULL, 22, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(50, 150, '2019-01-01 00:00:00.000', NULL, 24, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(51, 150, '2019-01-01 00:00:00.000', NULL, 25, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(52, 20000, '2019-01-01 00:00:00.000', NULL, 26, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(53, 90, '2019-01-01 00:00:00.000', NULL, 27, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(45, 18, '2019-01-01 00:00:00.000', NULL, 28, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(55, 0, '2019-01-01 00:00:00.000', NULL, 29, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(54, 24, '2019-01-01 00:00:00.000', NULL, 30, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(56, 20, '2019-01-01 00:00:00.000', NULL, 31, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(57, 20, '2020-01-01 00:00:00.000', NULL, 32, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(58, 0, '2020-01-01 00:00:00.000', NULL, 33, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(59, 0, '2020-01-01 00:00:00.000', NULL, 34, 2);
INSERT INTO iscritto_t_punteggio (id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola) 
VALUES(60,7,'2020-01-01 00:00:00.000',NULL,34,2);
--
INSERT INTO iscritto_d_condizione_pun (cod_condizione,descrizione,id_condizione_punteggio,fl_istruttoria,id_tipo_istruttoria,id_tipo_allegato) VALUES 
('CF_FRA_FRE_MAT_EXTRA','Punteggio aggiuntivo per fratelli frequentanti stesso istituto e la domanda avrà comunque il punteggio di quelle dei residenti',35,'N',NULL,NULL)
;

INSERT INTO iscritto_t_punteggio
(id_punteggio, punti, dt_inizio_validita, dt_fine_validita, id_condizione_punteggio, id_ordine_scuola)
VALUES(61, 80, '2020-01-01 00:00:00.000', NULL, 35, 2);


INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (0, '0,0', 'graduatoria standard');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (1, '1,1', 'bambini e bambine non residenti, che hanno passaporto di un paese di lingua inglese, francese o tedesca o che hanno almeno un genitore con passaporto di un paese di lingua inglese, francese o tedesca, non facente parte dell''Unione Europea');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (2, '1,2' , 'bambini e bambine non residenti con un genitore che lavora a Torino, che hanno passaporto di un paese di lingua inglese, francese o tedesca o che hanno almeno un genitore con passaporto di un paese di lingua inglese, francese o tedesca facente parte dell''Unione Europea');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (3, '1,3' , 'bambini e bambine non residenti, che hanno passaporto di un paese di lingua inglese, francese o tedesca o che hanno almeno un genitore con passaporto di un paese di lingua inglese, francese o tedesca, facente parte dell''Unione Europea');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (4, '2,1' , 'bambini e bambine non residenti con un genitore che lavora a Torino, che hanno soggiornato in un paese di lingua inglese, francese o tedesca non facente parte dell''Unione Europea, per almeno un anno a partire dai 2 anni di eta'', e sono appena rientrati in Italia');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (5, '2,2' , 'bambini e bambine non residenti, che hanno soggiornato in un paese di lingua inglese, francese o tedesca non facente parte dell''Unione Europea, per almeno un anno a partire dai 2 anni di eta'', e sono appena rientrati in Italia');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (6, '2,3' , 'bambini e bambine non residenti con un genitore che lavora a Torino, che hanno soggiornato in un paese di lingua inglese, francese o tedesca dell''Unione Europea, per almeno un anno a partire dai 2 anni di eta'', e sono appena rientrati in Italia');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (7, '3,1' , 'bambini e bambine non residenti, che hanno soggiornato in un paese di lingua inglese, francese o tedesca dell''Unione Europea, per almeno un anno a partire dai 2 anni di eta'', e sono appena rientrati in Italia');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (8, '3,2' , 'bambini e bambine residenti, che hanno soggiornato in un paese di lingua inglese, francese o tedesca non facente parte dell''Unione Europea, per almeno un anno a partire dai 2 anni di eta'', e sono appena rientrati in Italia');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (9, '3,3' , 'bambini e bambine residenti, che hanno passaporto di un paese di lingua inglese, francese o tedesca o che hanno almeno un genitore con passaporto di un paese di lingua inglese, francese o tedesca, facente parte dell''Unione Europea');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (10, '4,1' , 'bambini e bambine residenti, che hanno passaporto di un paese di lingua inglese, francese o tedesca o che hanno almeno un genitore con passaporto di un paese di lingua inglese, francese o tedesca, non facente parte dell''Unione Europea');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (11, '4,2' , 'bambini e bambine residenti, che hanno soggiornato in un paese di lingua inglese, francese o tedesca dell''Unione Europea, per almeno un anno a partire dai 2 anni di eta'', e sono appena rientrati in Italia');
INSERT INTO iscritto_d_tipo_graduatoria (id_tipo_grad, cod_tipo_grad, desc_tipo_grad) VALUES (12, '4,3' , 'bambini e bambine non residenti con un genitore che lavora a Torino, che hanno passaporto di un paese di lingua inglese, francese o tedesca o che hanno almeno un genitore con passaporto di un paese di lingua inglese, francese');

delete from ISCRITTO_D_QUARTIERE;
delete from ISCRITTO_D_CIRCOSCRIZIONE where id_circoscrizione in (9,10);

INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(1, 'Centro', 1);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(2, 'San Salvario', 8);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(3, 'Crocetta - San Secondo', 1);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(4, 'San Paolo', 3);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(5, 'Cenisia - Cit Turin', 3);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(6, 'San Donato - Campidoglio', 4);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(7, 'Aurora - Valdocco . Rossini', 7);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(8, 'Vanchiglia - Vanchiglietta', 7);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(9, 'Nizza Millefonti', 8);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(10, 'Lingotto - Mercati generali', 8);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(11, 'Santa Rita', 2);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(12, 'Mirafiori Nord', 2);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(13, 'Pozzo Strada', 3);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(14, 'Parella', 4);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(15, 'Lucento - Vallette', 5);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(16, 'Madonna di Campagna - Lanzo', 5);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(17, 'Borgo Vittoria', 5);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(18, 'Barriera di Milano', 6);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(19, 'Rebaudengo - Falchera - Villaretto', 6);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(20, 'Regio Parco - Barca - Bertolla', 6);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(21, 'Sassi - Madonna del Pilone', 7);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(22, 'Borgo Po - Cavoretto', 8);
INSERT INTO ISCRITTO_D_QUARTIERE (id_quartiere, descrizione, id_circoscrizione ) VALUES(23, 'Mirafiori Sud', 2);

UPDATE iscritto_d_circoscrizione SET descrizione='Centro - Crocetta' WHERE id_circoscrizione=1;
UPDATE iscritto_d_circoscrizione SET descrizione='Santa Rita - Mirafiori Nord - Mirafiori Sud' WHERE id_circoscrizione=2;
UPDATE iscritto_d_circoscrizione SET descrizione='San Paolo - Cenisia - Pozzo Strada - Cit Turin - Borgata Lesna' WHERE id_circoscrizione=3;
UPDATE iscritto_d_circoscrizione SET descrizione='San Donato - Campidoglio - Parella' WHERE id_circoscrizione=4;
UPDATE iscritto_d_circoscrizione SET descrizione='Borgo Vittoria - Madonna di Campagna - Lucento - Vallette' WHERE id_circoscrizione=5;
UPDATE iscritto_d_circoscrizione SET descrizione='Barriera di Milano - Regio Parco - Barca - Bertolla - Falchera - Rebaudengo - Villaretto' WHERE id_circoscrizione=6;
UPDATE iscritto_d_circoscrizione SET descrizione='Aurora - Vanchiglia - Sassi - Madonna del Pilone' WHERE id_circoscrizione=7;
UPDATE iscritto_d_circoscrizione SET descrizione='San Salvario - Cavoretto - Borgo Po - Nizza Millefonti - Lingotto - Filadelfia' WHERE id_circoscrizione=8;

INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(84,4279,'MUN. BORGO CROCETTA','Duca degli Abruzzi 50 (corso)','N',1,2,1,'011 596070','smmducadegliabruzzi@comune.torino.it',null,3,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(85,4604,'MUN. MILLE COLORI','Gioberti33 (via)','N',1,2,1,'011 539840','smmgioberti@comune.torino.it',5,3,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(86,4634,'MUN. ALDA MERINI','Giulio 30 (via)','N',1,2,1,'011 01125373','smmgiulio@comune.torino.it',1,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(87,300158,'P.C. S.TERESA DI GESU'' BAMBINO','da Verazzano 58 (via)','N',2,2,1,'011 595287','scuolainfanziateresina@virgilio.it',null,3,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(88,5768,'P.C. SAN MASSIMO','dei Mille 19 (via)','N',2,2,1,'011 812 2116','scuolasanmassimo@fondazioneacmf.org',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(89,5826,'P.C. SANT''ANNA - CONSOLATA 20','della Consolata 20 (via)','N',2,2,1,'011 2342279','maternasantanna@tiscali.it',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(90,5907,'P.C. SS. ANNUNZIATA','Ferrari 16 (via)','N',2,2,1,'011 887933','smssannunziata@tiscali.it',7,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(91,920989,'P.C. SAN SECONDO','Gioberti 9 (via)','N',2,2,1,'011 5618813','scuolamaterna.sansecondo@virgilio.it',null,3,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(92,5367,'P.C. CLOTILDE - MAGENTA','Magenta 29 (via)','N',2,2,1,'011 533244 ','segreteria.infanzia@mauxtorino.com',null,3,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(93,300136,'P.C. SANT''ANNA - MASSENA 36','Massena 36 (via)','N',2,2,1,'011 5166511','segreteria@istituto-santanna.it',null,3,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(94,6102,'P.C. UMBERTO I','Matteotti 48 (corso)','N',2,2,1,'011 544532','info@scuolamaternaumbertoprimo.it',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(95,6246,'P.C. VITTORIO EMANUELE II','Regina Margherita 107','N',2,2,1,'011 4360325 ','scuolamatemanuele2@libero.it',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(96,3601,'ST. MATTEOTTI EX ARCIV','Matteotti 6 BIS (corso)','N',3,2,1,'011 530212','pacchiotti@tin.it',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(97,5273,'ST. PLANA','Plana 2 (via)','N',3,2,1,'011 8122190','toic815005@istruzione.it',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(98,16159,'ST. SANTA CHIARA','Santa Chiara 12 (via)','N',3,2,1,'011 19527030','TOIC8B500Q@istruzione.it',null,1,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(99,5607,'MUN. ASTRID LINDGREN','Barletta 109/20 (via)','N',1,2,2,'011 01133463','smmbarletta@comune.torino.it',16,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(100,4219,'MUN. IL MAGO DI OZ','Collino 12 (via)','N',1,2,2,'011 3096867','smmcollino@comune.torino.it',14,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(101,4553,'MUN. C.B. FREINET','Forno Canavese 5 (via)','N',1,2,2,'011 01120571','smmfornocanavese@comune.torino.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(102,5513,'MUN. IL CILIEGIO','Guido Reni 53 (via)','N',1,2,2,'011 3272062','smmreni@comune.torino.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(103,'5198N','MUN. PAJETTA ELVIRA','Isler 15 (via)','N',1,2,2,'011 01127989','smmisler@comune.torino.it',12,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(104,'4964N','MUN. MIRAFIORI NORD','Luciano Jona 6 (piazzetta)','N',1,2,2,'011 3913181','smmjona@comune.torino.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(105,5155,'MUN. COLLODI','Orbassano 122 (corso)','N',1,2,2,'011 3241078','smmorbassano@comune.torino.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(106,'5269N','MUN. CENTO FIORI','Pisacane 71 (via)','N',1,2,2,'011 6060610','smmpisacane@comune.torino.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(107,5324,'MUN. IL MONDO','Poma 14 (via)','N',1,2,2,'011 3094367','smmpoma@comune.torino.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(108,5543,'MUN. BRUNELLA E10','Romita 19 (via)','N',1,2,2,'011 01120931','smmromita@comune.torino.it',13,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(109,'4981N','MUN. MIRAFIORI SUD','Roveda 35/1 (via)','N',1,2,2,'011 3913209','smmnegarville@comune.torino.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(110,4152,'MUN. CENTRO EUROPA C','Rubino 82 (via)','N',1,2,2,'011 3092176','smmrubino@comune.torino.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(111,5341,'P.C. PRINCIPE TOMMASO','Caprera 46 (via)','N',2,2,2,'011 3290210','istitutogesubambino@ismc.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(112,'301045N','P.C. MARGHERITA DI MIRAFIORI','Castello di Mirafiori 46  (strada)','N',2,2,2,'011 342067','margheritamirafiori@virgilio.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(113,3559,'P.C. VIRGINIA AGNELLI','Sarpi 123 (via)','N',2,2,2,'011 610905','toagnellisegr@fma-ipi.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(114,5354,'P.C. PRINCIPE VITT. EMANUELE','Unione Sovietica 170','N',2,2,2,'011 3187247','ist.pve@libero.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(115,5873,'P.C. S. RITA','Vernazza 41 (via)','N',2,2,2,'011 396201','scuolamaterna@srita.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(116,'3614N','ST. ARTOM E06','Artom 109/3 (via)','N',3,2,2,'011 6066586','toic866002@istruzione.it',11,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(117,3732,'ST. IL MELO FIORITO','Baltimora 64 (via)','N',3,2,2,'011 3272007','TOIC8B000L@istruzione.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(118,3745,'ST. BALTIMORA 76','Baltimora 76 (via)','N',3,2,2,'011 396447','toic8b000l@istruzione.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(119,3889,'ST. VIOLETA PARRA ','Boston 33 (via)','N',3,2,2,'011 01166670 ','TOIC8BZ003@istruzione.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(120,'4081N','ST. CASTELLO MIRAFIORI','Castello di Mirafiori 43 (strada)','N',3,2,2,'011 01120950 ','toic82000l@istruzione.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(121,4347,'ST. D''ARBOREA','d''Arborea 9/A (via)','N',3,2,2,'011 3096817','toic8bx00b@istruzione.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(122,4148,'ST. CENTRO EUROPA B','Guidobono 2 (via)','N',3,2,2,'011 3096817','toic8bx00b@istruzione.it',null,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(123,'6057N','ST. LA GIOSTRA ','Monastir 17/9 (via)','N',3,2,2,'011 6066586','toic866002@istruzione.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(124,5011,'ST. LEVI MONTALCINI ','Monte Novegno 31 (via)','N',3,2,2,'011 3096817','toic8bx00b@istruzione.it',10,12,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(125,5168,'ST. NICHOLAS GREEN ','Orbassano 224/26 (corso)','N',3,2,2,'011 396447','toic8b000l@istruzione.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(126,'5286N','ST. MARIELE VENTRE ','Plava 177/2 (via)','N',3,2,2,'011 01120950 ','toic82000l@istruzione.it',null,23,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(127,5172,'ST. BRUNO MUNARI','Rovereto 21 (via)','N',3,2,2,'011 367407','TOIC8BY007@istruzione.it',null,11,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(128,3901,'MUN. MALTA','Braccini 75 (via)','N',1,2,3,'011 3822803','smmbraccini@comune.torino.it',null,4,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(129,3914,'MUN. L''AQUILONE','Brissogne 39 (via)','N',1,2,3,'011 701699','smmbrissogne@comune.torino.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(130,16103,'MUN. E. LUZZATI','Bruino 14 (via)','N',1,2,3,'011 4471131','smmbruino@comune.torino.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(131,5239,'MUN. PICCOLO TORINO','Collegno 65 (via)','N',1,2,3,'011 4476577','smmcollegno@comune.torino.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(132,6175,'MUN. A.C. MODIGLIANI','Germonio Anastasio 35 (via)','N',1,2,3,'011 19524284','smmgermonio@comune.torino.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(133,4994,'MUN. FRIDA KAHLO','Monte Cristallo 9 (via)','N',1,2,3,'011 334641','smmmontecristallo@comune.torino.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(134,5037,'MUN. BRUNO CIARI','Moretta 57 (via)','N',1,2,3,'011 4332313','smmmoretta@comune.torino.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(135,4849,'P.C. MADRE MAZZARELLO','Cumiana 2 (via)','N',2,2,3,'011 3797810','infanzia@mazzarello.it',null,4,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(136,4418,'P.C. DUCHESSA ELENA D''AOSTA','Francia 139 (corso)','N',2,2,3,'011 740281','scuola_elena@tiscali.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(137,3876,'P.C. BORGO S. PAOLO','San Paolo 50 (via)','N',2,2,3,'011 3852304','segreteria@asilosanpaolo.it',null,4,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(138,5671,'P.C. SACRO CUORE LESNA','Santa Maria Mazzarello 102 (via)','N',2,2,3,'011 702911','toscuoreinfanzia@fma-ipi.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(139,5112,'P.C. N.S.SACRO CUORE','Val Lagarina 23 (via)','N',2,2,3,'011 4032800','materna.nsscdg@libero.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(140,5539,'ST. QUARANTA','Bardonecchia 36/A (via)','N',3,2,3,'011 7496274','toic88400g@istruzione.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(141,3792,'ST. BERTA','Berta 15 (via)','N',3,2,3,'011 375915','toee065008@istruzione.it',null,4,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(142,3893,'ST. SANTAROSA ','Braccini 63 (via)','N',3,2,3,'011 19710282 ','toic8az00c@istruzione.it',null,4,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(143,4064,'ST. CASA DEI BAMBINI','Casalis 54 (via)','N',3,2,3,'011 4476070','toic88300q@istruzione.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(144,4206,'ST. CAVALLI','Collegno 73 (via)','N',3,2,3,'011 4476070','toic88300q@istruzione.it',null,5,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(145,5599,'ST. JJ ROUSSEAU ','Delleani 25 (via)','N',3,2,3,'011 01166200 ','toee06400c@istruzione.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(146,4478,'ST. FATTORI','Fattori 113 (via)','N',3,2,3,'011 7790915 ','toee00500L@istruzione.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(147,4664,'ST. JJ ROUSSEAU - ORTIGARA','Monte Ortigara 50 (via)','N',3,2,3,'011 01166200 ','toee06400c@istruzione.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(148,3546,'ST. AGAZZI CAROLINA','Postumia 28 (via)','N',3,2,3,'011 7070652','toic816001@istruzione.it ',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(149,12739,'ST. GIAN BURRASCA','Pozzo Strada 12/3 (via)','N',3,2,3,'011 7790915 ','toee00500L@istruzione.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(150,3589,'ST. ANDERSEN','Stelvio 45 (via)','N',3,2,3,'011 7790915',null,null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(151,6031,'ST. ROSA AGAZZI','Thures 11 (via)','N',3,2,3,'011 4032123','toic816001@istruzione.it',null,13,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(152,6087,'ST. TOLMINO','Tolmino 30 (via)','N',3,2,3,'011 01167860','toic8az00c@istruzione.it ',null,4,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(153,3661,'MUN. TESORIERA','Asinari di Bernezzo 23 (via)','N',1,2,4,'011 743894','smmasinaridibernezzo@comune.torino.it',29,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(154,4094,'MUN. CAVAGLIA''','Carrera 23 (via)','N',1,2,4,'011 7413109','smmcarrera@comune.torino.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(155,4394,'MUN. DE MURO GIUSEPPIN','Lessona 70 (via)','N',1,2,4,'011 7493941','smmrubino@comune.torino.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(156,3593,'MUN. APORTI GASTALDI','Livorno 14 (via)','N',1,2,4,'011 4378104','smmlivorno@comune.torino.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(157,4947,'MUN. ALBERTO MANZI','Medici  12 (via)','N',1,2,4,'011 01133420','smmmedici@comune.torino.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(158,4304,'MUN. J. S. BRUNER','Servais 62 (via)','N',1,2,4,'011 726161','smmservais@comune.torino.it',27,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(159,14247,'MUN. FIORI DEL MELOGRANO','Spoleto 5 (via)','N',1,2,4,'011 7495622','smmspoleto@comune.torino.it',26,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(160,6128,'MUN. CASA DEL SOLE','Valgioie 10 (via)','N',1,2,4,'011 7496592','smmvalgioie@comune.torino.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(161,5924,'P.C. SS. STIMM. S.FRAN','Ascoli 38 (via)','N',2,2,4,'011 485368 ','amministrazionescuola@parrocchiastimmate.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(162,4047,'P.C. CASA DEI BAMBINI','Medici 61 (via)','N',2,2,4,'011 7493267','info@asilocasadeibimbi.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(163,4917,'P.C. MARIA IMMACOLATA','Monte Grappa 116','N',2,2,4,'011 852092',null,null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(164,6203,'P.C. VERNA','Musine'' 8 (via)','N',2,2,4,'011 7493564','info@asiloverna.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(165,5911,'P.C. SANTISSIMO NATALE','Piedicavallo 5 (via)','N',2,2,4,'011 771 0358','info@ssnatale.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(166,5667,'P. SACRA FAMIGLIA','San Donato 17 (via)','N',2,2,4,'011 487603','sacrafamigliatorino.info@gmail.com',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(167,4452,'P. FAA'' DI BRUNO','San Donato 31 (via)','N',2,2,4,'011 489147','scuole@faadibruno.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(168,5869,'P.C. S. MARIA GORETTI','Servais 135 (via)','N',2,2,4,'011 722454','scuola.goretti@gmail.com',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(169,3728,'ST. MANZONI','Balme 46 (via)','N',3,2,4,'011 480333','toic81700r@istruzione.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(170,3788,'ST. BELLARDI','Bellardi 56 (via)','N',3,2,4,'011 375915','toee065008@istruzione.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(171,5256,'ST. FRECCIA AZZURRA','Fossano 8 (via)','N',3,2,4,'011 480333','toic81700r@istruzione.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(172,5455,'ST. MARCO POLO','Passoni 9 (via)','N',3,2,4,'011 725637 ','TOIC8BW00G@istruzione.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(173,4266,'ST. MARIE CURIE','Pietro Cossa 115/21 (via)','N',3,2,4,'011 725637 ','TOIC8BW00G@istruzione.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(174,5954,'ST. BOVETTI ','Savigliano 7 (via)','N',3,2,4,'011 745105','toic8a0002@istruzione.it',null,6,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(175,6132,'ST. ARCHIMEDE','Valgioie 72 (via)','N',3,2,4,'011 724696 ','TOIC8BV00Q@istruzione.it',null,14,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(176,4506,'MUN. DE PANIS','Ala di Stura 23 (via)','N',1,2,5,'011 01167000','smmaladistura@comune.torino.it',34,17,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(177,3627,'MUN. ARMANDO MELIS','Assisi 45 (via)','N',1,2,5,'011 01120840','smmassisi@comune.torino.it',32,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(178,6216,'MUN. VIBERTI CANDIDO','Cambiano 10 (via)','N',1,2,5,'011 01120870','smmcambiano@comune.torino.it',null,17,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(179,4321,'MUN. C. CORALINA','Cincinnato 200 (corso)','N',1,2,5,'011 7399848','smmcincinnato@comune.torino.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(180,4296,'MUN. CASTELDELFINO','Coppino 147 (via)','N',1,2,5,'011 01137555','smmcoppino@comune.torino.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(181,6158,'MUN. LE PRIMULE','delle Primule 36/C (via)','N',1,2,5,'011 735379','smmprimule@comune.torino.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(182,4879,'MUN. ARCOBALENO','Manno 22 (piazza)','N',1,2,5,'011 01120539','smmmanno@comune.torino.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(183,5637,'MUN. DANILO DOLCI','Reiss Romoli 49 (via)','N',1,2,5,'011 01166930','smmreissromoli@comune.torino.it',31,17,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(184,5813,'MUN. ANNA FRANK','Sansovino 111 (via)','N',1,2,5,'011 732318','smmsansovino@comune.torino.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(185,6259,'MUN. VITTORIO VENETO','Sospello 64 (via)','N',1,2,5,'011 01137511','smmsospello@comune.torino.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(186,5742,'P.C. S. GIUS. CAFASSO','Bettazzi 6 (via)','N',2,2,5,'011 2200995','segreteria@scuolacafasso.it ',null,17,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(187,5097,'P.C. N.S. DELLA SALUTE','Fontanella 9/11 (via)','N',2,2,5,'011 0869216','segreteria@scuolafontanella.org  ',null,17,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(188,5498,'P.C. REGINA PACIS','Messedaglia 7 (via)','N',2,2,5,'011 250171',null,null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(189,5697,'P.C. SACRO CUORE LUCENTO','Pianezza 110 (via)','N',2,2,5,'011 4365676','tolucento@fma-ipi.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(190,4422,'P.C. DURIO FRANCESCA','Zubiena 4 (via)','N',2,2,5,'011 250188','asilodurio@libero.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(191,4317,'ST. E 15','Cincinnato 121 (corso)','N',3,2,5,'011 7390649','TOIC873005@istruzione.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(192,5054,'ST. MAGNOLIE','delle Magnolie 15 (via)','N',3,2,5,'011 7399425','toic810002@istruzione.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(193,6145,'ST. VALLETTE A','delle Verbene 4 (via)','N',3,2,5,'011 731658 ','smmverbene@comune.torino.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(194,5384,'ST. PRINCIPESSA ISABELLA','Gorresio 13 (via)','N',3,2,5,'011 2168786 ','TOIC8B2008@istruzione.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(195,4765,'ST. LANZO','Lanzo 146 (via)','N',3,2,5,'011 01166888 ','toic8br003@istruzione.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(196,4752,'ST. MELANIE KLEIN','Lanzo 28 (via)','N',3,2,5,'011 01166888 ','toic8br003@istruzione.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(197,100796,'ST. MORANTE','Orvieto 1 (via)','N',3,2,5,'011 290041','toee00400r@istruzione.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(198,6014,'ST. BECHIS ANNA','Terraneo 1 (via)','N',3,2,5,'011 731758','toic873005@istruzione.it',null,15,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(199,6192,'ST. VENARIA','Venaria 100 (via)','N',3,2,5,'011 01166888 ','toic8br003@istruzione.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(200,15008,'ST. GUIDO CAPPONI','Venaria 79/15 (via)','N',3,2,5,'011 01166888 ','toic8br003@istruzione.it',null,16,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(201,3576,'MUN. IQBAL MASIH','Ancina 29 (via)','N',1,2,6,'011 200156','smmancina@comune.torino.it',41,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(202,4951,'MUN. FANCIULLI','Mercadante 129 (via)','N',1,2,6,'011 2464529 ','smmmercadante@comune.torino.it',null,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(203,5371,'MUN. PRINC.SSA PIEMONTE','Paisiello 1 (via)','N',1,2,6,'011 852964','smmpaisiello@comune.torino',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(204,6115,'MUN. UMBERTO I - REGIO P','Paroletti 15 (via)','N',1,2,6,'011 202888','smmparoletti@comune.torino.it',null,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(205,21083,'MUN. JOAN MIRO''','Scotellaro 19 (via)','N',1,2,6,'011 266747','smmscotellaro@comune.torino.it',43,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(206,6276,'MUN. JOAN MIRO''','Scotellaro 9 (via)','N',1,2,6,'011 266747','smmscotellaro@comune.torino.it',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(207,6074,'MUN. G. PEREMPRUNER','Tronzano 20 (via)','N',1,2,6,'011 200902','smmtronzano@comune.torino.it',40,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(208,6263,'MUN. BARCA','Vittime di Bologna 10 (via)','N',1,2,6,'011 2731206 ','smmvittimedibologna@comune.torino.it',42,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(209,5755,'P.C. S. GIUSEPPE LAVORATORE','Botticelli 11/15 (via)','N',2,2,6,null,'maternareba@tiscali.it',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(210,4651,'P.C. GRASSI LUIGI','Comunale di Bertolla 74 (strada)','N',2,2,6,'011 2730009','sc.mat.grassi@tiscali.it',null,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(211,5798,'P.C. SAN PIO X','dei Pioppi 15 (via)','N',2,2,6,'011 262 0274','scuolamaternasanpioxfalchera@gmail.com',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(212,5108,'P.C. N.S. DELLA SPERANZA','Desana 18 (via)','N',2,2,6,'011 2053566 ','speranzadesana18@libero.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(213,6027,'P.C. THAON DI REVEL','Lombardore 27 (via)','N',2,2,6,'011 851035','segreteria@maternathaondirevel-torino.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(214,5526,'P.C. RESI MARINOTTI','Marinuzzi 10 (via)','N',2,2,6,'011 2620878','tostura@fma-ipi.it',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(215,4866,'P.C. MAMMA MARGHERITA','Paisiello 42 (via)','N',2,2,6,'011 2304171','coordinatrice.infanzia@michelerua.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(216,6001,'P.C. F. TEDESCHI E C. ASSANDRI','Tollegno 21 (via)','N',2,2,6,'011 854444','sctedeschi@davide.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(217,4694,'P.C. IMMACOLATA','Vestigne 7 (via)','N',2,2,6,'011 852092','segretorino@gmail.com',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(218,5509,'ST. ABBA G.C.','Abba 9 (piazza)','N',3,2,6,'011 01166766','TOIC8CF006@istruzione.IT',null,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(219,14179,'ST. ANGLESIO E16','Anglesio 17 (via)','N',3,2,6,'011 2730154','toic80500e@istruzione.it',null,20,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(220,200284,'ST. EX-INCET','Banfo 17/19 (via)','N',3,2,6,'011/01167333','toic8b8007@istruzione.it ',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(221,3816,'ST. PERRAULT','Boccherini 43 (via)','N',3,2,6,'011 2624966 ','toee02700d@istruzione.it',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(222,3987,'ST. WALT DISNEY ','Cavagnolo 35 (via)','N',3,2,6,'011 2624966 ','toee02700d@istruzione.it',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(223,6044,'ST. TOMMASO DI SAVOIA','Cervino 6 (via)','N',3,2,6,'011 851031','toee029005@istruzione.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(224,5569,'ST. ROSA LUXEMBURG','degli Abeti15 (via)','N',3,2,6,'011 2621298','toic808002@istruzione.it',null,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(225,4806,'ST. ANGELITA DI ANZIO','Leoncavallo 61/2 (via)','N',3,2,6,'011 851031','toee029005@istruzione.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(226,5556,'ST. LUZZATI','Vercelli 141 (corso)','N',3,2,6,'011 2053274 ','toee05600d@istruzione.it',null,18,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(227,5941,'MUN. ROSA L.PARKS','Ancona 2/A (via)','N',1,2,7,'011 2487524','smmancona@comune.torino.it',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(228,4448,'MUN. MARC CHAGALL','Cecchi 2 (via)','N',1,2,7,'011 2472124','smmcecchi@comune.torino.',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(229,5937,'MUN. SASSI','Comunale di Mongreno (strada)','N',1,2,7,'011 8996226','smmmongreno@comune.torino.it',null,21,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(230,4377,'MUN. G. DELEDDA','Deledda 9 (via)','N',1,2,7,'011 8980123','smmdeledda@comune.torino.it',49,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(231,3974,'MUN. BEATRIX POTTER','Varallo 33 (via)','N',1,2,7,'011 835056','smmvarallo@comune.torino.it',null,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(232,300718,'P.C. ARSENALE DELLA PACE','Andreis 18/25 (via)','N',2,2,7,'011 4368566','nidodeldialogo@coopliberitutti.it',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(233,4836,'P. MADRE CABRINI','Artisti 4 (via)','N',2,2,7,'011 835858','CABRINI.TO@TIN.IT',null,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(234,5408,'P.C. CLOTILDE - AUSILIATRICE','Ausiliatrice 27 (piazza)','N',2,2,7,'011 4365676','materna@liceoausiliatrice.it',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(235,6091,'P.C. SUOR TARCISIA PONCHIA','Montemagno 59 (via)','N',2,2,7,'011 8193250','info@scuolasuortarcisia.it',null,21,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(236,4482,'P. FERRERO CANONICO','Pallavicino 20 (via)','N',2,2,7,'011 8171340','infanziaferrero@carmelitane.com',null,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(237,5654,'P.C. S. GIULIO D''ORTA','Verbano 6 (via)','N',2,2,7,'011 899 6264','info@parinido.org',null,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(238,3775,'ST. PARINI','Beinasco 34 (via)','N',3,2,7,'011 852430','toic8be00q@istruzione.it',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(239,5442,'ST. PEREMPRUNER ','Bersezio11 (via)','N',3,2,7,'011 2481916 ','toic8BD00X@istruzione.it',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(240,4523,'ST. FIORINA','Chieri 136 (corso)','N',3,2,7,'011 852964','toic81800l@istruzione.it',null,21,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(241,4182,'ST.  MARY POPPINS','Cirie'' 3/A (corso)','N',3,2,7,'011 852341','segreteria@icregioparco.gov.it',51,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(242,4921,'ST. MARIA TERESA','Mameli 16 (via)','N',3,2,7,'011 852341','toic87700c@istruzione.it',null,7,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(243,3674,'ST. VANCHIGLIETTA','Manin 22 (via)','N',3,2,7,'011 01132006','TOAA87602E@istruzione.it',null,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(244,5641,'ST. RODARI','Regina Margherita 43 (corso)','N',3,2,7,'011 01132032','toic87600l@istruzione.it',50,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(245,3944,'ST. BONCOMPAGNI','Sa. Giuseppe Cafasso 73 (via)','N',3,2,7,'011 01138780','toic81800l@istruzione.it',null,21,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(246,'3974S','ST. FIORINA','Varallo 33 (via)','N',3,2,7,'011 8980284','toic81800l@istruzione.it',null,8,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(247,'4249N','MUN. SOLE','Benedetto Croce 21 (corso)','N',1,2,8,'011 614251','smmcroce@comune.torino.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(248,'3991N','MUN. MILLEFONTI','Caduti sul Lavoro 5 (corso)','N',1,2,8,'011 6633896','smmcadutisullavoro@comune.torino.it',null,9,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(249,4105,'MUN. CAVORETTO','Dai Ronchi ai Cunioli Alti 27 (strada)','N',1,2,8,'011 01166970','smmronchi@comune.torino.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(250,'4677N','MUN. SILVANA ALLASIA','Guala (Piazza) 140','N',1,2,8,'011 616087','smmguala@comune.torino.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(251,3758,'MUN. BARRIERA DI NIZZA','Leonardo da Vinci 8 (via)','N',1,2,8,'011 0119390','smmvarallo@comune.torino.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(252,4364,'MUN. EUROPEA','Lodovica 2 (via)','N',1,2,8,'011 01167250','smmlodovica@comune.torino.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(253,'100539F','SCUOLA MATERNA EUROPEA ML - FRANCESE','Lodovica 2 (via)','N',1,2,8,'011 01167250','smmlodovica@comune.torino.it',null,22,'U');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(254,'100539I','SCUOLA MATERNA EUROPEA ML - INGLESE','Lodovica 2 (via)','N',1,2,8,'011 01167250','smmlodovica@comune.torino.it',null,22,'U');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(255,'100539T','SCUOLA MATERNA EUROPEA ML - TEDESCA','Lodovica 2 (via)','N',1,2,8,'011 01167250','smmlodovica@comune.torino.it',null,22,'U');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(256,4819,'MUN. E. LUGARO','Lugaro 6 (via)','N',1,2,8,'011 01139960','smmlugaro@comune.torino.it',57,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(257,4118,'MUN. CELLINI','Madama Cristina 134 (via)','N',1,2,8,'011 01128940','smmmadamacristina@comune.torino.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(258,5624,'MUN. RUBATTO LAETITIA','Moncalieri 48 (corso)','N',1,2,8,'011 6601830','smmmoncalieri48@comune.torino.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(259,'4165N','MUN. ALICE','Paoli 75 (via)','N',1,2,8,'011 3171515','anpaoli@comune.torino.it',53,19,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(260,16146,'MUN. PRINCIPE TOMMASO','Principe Tommaso 25 (via)','N',1,2,8,'011 01132120','smmprincipetommaso@comune.torino.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(261,5024,'P.C. ONORATO MORELLI','all''Asilo 3 (via)','N',2,2,8,'011 661 2588','asilomorelli@gmail.com',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(262,916673,'P.C. PROTETTE DI S. GIUSEPPE','Bidone 33 (via)','N',2,2,8,'011 8190096 ','info@scuolaprotettesangiuseppe.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(263,3644,'P.C. ADORAZIONE S.C. CADORNA','Curreno, 21 (viale)','N',2,2,8,'011 6602979','segreteria@adorazione.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(264,3859,'P.C. BORGNANA PICCO','Moncalieri 218 (corso)','N',2,2,8,'011 6613070','info@borgnanapicco.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(265,5084,'P.C. NOSTRA SIGNORA - MONCALVO','Moncalvo 1 (via)','N',2,2,8,'011 8194606','nsignoraE-mailtiscali.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(266,3829,'P.C. BONACOSSA','Nizza 22F (via)','N',2,2,8,'011 4224124 ','amministrazione@scuolabonacossa.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(267,5586,'P.C. ANTONIO ROSMINI','Saluzzo 27 (via)','N',2,2,8,'011 6505567 ','antonio.rosmini@libero.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(268,5843,'P.C. SANTA MARIA','San Pio V 11 (via)','N',2,2,8,'011 6694710','infanziasmaria@gmail.com',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(269,4223,'P.C. COLONNA E FINZI','Sant''Anselmo 7 (via)','N',2,2,8,'011 658587','segreteriascuola@torinoebraica.it',null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(270,'4223C','P.C. COLONNA E FINZI - COMUNITA'' EBRAICA','Sant''Anselmo 7 (via)','N',2,2,8,'011 658587','segreteriascuola@torinoebraica.it',null,2,'E');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(271,'5738N','P.C. SAN GIORGIO','Steffenone 25/29 (via)','N',2,2,8,'011 3196572','pgssg@yahoo.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(272,'4823N','P.C. MADONNA DELLE ROSE','Unione Sovietica 223 (corso)','N',2,2,8,'011 3172472','materna.madrose@tin.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(273,'3961N','P.C. ASSUNZIONE M.V. LINGOTTO','Vinovo 11 (via)','N',2,2,8,'011 6647219','scuolamat@libero.it',null,9,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(274,3657,'ST. ALASSIO','Alassio 22 (via)','N',3,2,8,'011 01166100','toic8a100t@istruzione.it',null,9,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(275,4596,'ST. MARIO LODI','Garessio 24/5 (via)','N',3,2,8,'011 01166100 ','toic8a100t@istruzione.it',null,9,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(276,4351,'ST. GIACOSA','Giacosa 23 (via)','N',3,2,8,'011 6966660',null,null,2,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(277,4536,'ST. FANCIULLI','Invernizio 21 (via)','N',3,2,8,'011 3171096','toic88200x@istruzione.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(278,4722,'ST. LA PIMPA','la Loggia 53 (largo)','N',3,2,8,'011 01120550 ','toic881004@istruzione.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(279,4519,'ST. FIOCCARDO','Moncalieri 400 (corso)','N',3,2,8,'011 01166800 ','toee05100a@istruzione.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(280,5997,'ST. WASILIJ KANDINSKIJ ','Monte Corno 21 (via)','N',3,2,8,'011 3171096 ','toic88200x@istruzione.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(281,5299,'ST. HELEN KELLER','Podgora 28 (via)','N',3,2,8,'011 612085','toic88200x@istruzione.gov.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(282,5307,'ST. LINUS','Poirino 9 (via)','N',3,2,8,'011 01120550 ','toic881004@istruzione.it',null,10,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(283,5839,'ST. S. MARGHERITA','San Vincenzo 144 (strada)','N',3,2,8,'011 8192681 ','segreteria.dd.dazeglio@gmail.com',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(284,6233,'ST. VILLA GENERO','Santa Margherita 77','N',3,2,8,'011 8193236','TOAA01803L@istruzione.it',null,22,'S');
INSERT INTO iscritto_t_scuola (id_scuola, cod_scuola, descrizione, indirizzo, fl_eliminata, id_categoria_scu, id_ordine_scuola, id_circoscrizione, telefono, email, id_nido_contiguo, quartiere, tipo_rest) values(285,5967,'ST. BORGARELLO','Sicilia 24 (corso)','N',3,2,8,'011 4099611','toic8b9003@istruzione.it',null,22,'S');

ALTER TABLE iscritto_t_scuola
  ADD CONSTRAINT iscritto_t_scuola_id_quartiere_fkey
  FOREIGN KEY (quartiere)
  REFERENCES iscritto_d_quartiere (id_quartiere);
  
ALTER TABLE iscritto_r_profilo_scuole
  ADD CONSTRAINT iscritto_r_profilo_scuole_id_scuola_fkey
  FOREIGN KEY (id_scuola)
  REFERENCES iscritto_t_scuola (id_scuola);
 
commit;
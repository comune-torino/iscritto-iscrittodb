--============================================================================================================================
-- DDL --
-- ---------------------------------------------------------------------------------------------------------------------------
CREATE TABLE iscritto_t_invio_sise (
	id_domanda_iscrizione int4 NOT NULL,
	dt_accettazione date NULL,
	dt_invio date NULL,
	telefono varchar(20) NULL,
	id_scuola int4 NULL,
	id_tipo_frequenza int4 NULL,
	CONSTRAINT iscritto_t_invio_sise_pkey PRIMARY KEY (id_domanda_iscrizione)
);
--
CREATE TABLE iscritto_tmp_flusso_materne (
	id_tmp_flusso int4 NULL,
	record varchar(1000) NULL);
--
ALTER TABLE iscritto_t_parametro ALTER COLUMN testo_mail_eco TYPE varchar(4096);
ALTER TABLE iscritto_t_parametro ADD id_ordine_scuola integer;
ALTER TABLE iscritto_t_parametro ADD CONSTRAINT iscritto_t_parametro_id_ordine_scuola_fkey FOREIGN KEY (id_ordine_scuola)
  REFERENCES iscritto_d_ordine_scuola(id_ordine_scuola);
COMMENT ON COLUMN iscritto_t_parametro.testo_mail_eco IS 'Testo parametrico delle mail di accettazione per le econome';
--
CREATE UNIQUE INDEX iscritto_t_utente_codice_fiscale_key ON iscritto_t_utente (codice_fiscale ASC);
--
ALTER TABLE iscritto_t_invio_sise ADD CONSTRAINT iscritto_t_invio_sise_id_domanda_iscrizione_fkey FOREIGN KEY (id_domanda_iscrizione) REFERENCES iscritto_t_domanda_isc(id_domanda_iscrizione);
ALTER TABLE iscritto_t_invio_sise ADD CONSTRAINT iscritto_t_invio_sise_id_scuola_fkey FOREIGN KEY (id_scuola) REFERENCES iscritto_t_scuola(id_scuola) ON DELETE SET NULL;
ALTER TABLE iscritto_t_invio_sise ADD CONSTRAINT iscritto_t_invio_sise_id_tipo_frequenza_fkey FOREIGN KEY (id_tipo_frequenza) REFERENCES iscritto_d_tipo_fre(id_tipo_frequenza) ON DELETE SET NULL;
--
ALTER TABLE ISCRITTO_T_STEP_GRA ADD dt_pub_step timestamp without time zone;
--
-- INDICI
--
CREATE INDEX iscritto_t_anagrafica_sog_idx ON iscritto_t_anagrafica_sog 
(
    id_domanda_iscrizione
);
--
--
commit;

--============================================================================================================================
-- DML --
--
-- INSERT
--
INSERT INTO iscritto_d_tipo_ist
(id_tipo_istruttoria, cod_tipo_istruttoria, descrizione)
VALUES(4, 'COM_A', 'Commissione medica altri');
commit;
--
INSERT INTO iscritto_d_condizione_pun (cod_condizione,descrizione,id_condizione_punteggio,fl_istruttoria,id_tipo_istruttoria,id_tipo_allegato) VALUES 
('XT_PT_AGG','Punteggio aggiuntivo 1^ scelta convenzionate/statali',33,'N',NULL,NULL);
commit;
--
INSERT INTO iscritto_t_punteggio (id_punteggio,punti,dt_inizio_validita,dt_fine_validita,id_condizione_punteggio,id_ordine_scuola) VALUES 
(58,7,'2020-01-01 00:00:00.000',NULL,33,2);
commit;
--
-- UPDATE 
--
UPDATE iscritto_d_condizione_pun
SET  id_tipo_istruttoria=4
WHERE id_condizione_punteggio=5;
commit;
--
UPDATE iscritto_d_condizione_pun
SET  id_tipo_istruttoria=4
WHERE id_condizione_punteggio=25;
commit;
--



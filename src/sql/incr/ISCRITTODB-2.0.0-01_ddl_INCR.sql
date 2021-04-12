
----------------------------------------------------------------------
-- 2019-10-28 - ISBO-334
----------------------------------------------------------------------
--CREATE SEQUENCE iscritto_t_domanda_isc_protocollo_mat;

----------------------------------------------------------------------
-- 2019-10-28 - ISBO-329
----------------------------------------------------------------------
CREATE SEQUENCE iscritto_t_anagrafica_gra_id_anagrafica_gra_seq;
ALTER SEQUENCE iscritto_t_anagrafica_gra_id_anagrafica_gra_seq RESTART WITH 10;

----------------------------------------------------------------------
-- 2019-11-18 - ISBO-329
----------------------------------------------------------------------
CREATE SEQUENCE iscritto_t_step_gra_id_step_gra_seq;
ALTER SEQUENCE iscritto_t_step_gra_id_step_gra_seq RESTART WITH 10;

----------------------------------------------------------------------
-- 2019-11-21 -
----------------------------------------------------------------------
ALTER TABLE iscritto_d_fascia_eta ADD COLUMN id_ordine_scuola INTEGER;
ALTER TABLE iscritto_d_fascia_eta ADD CONSTRAINT iscritto_d_fascia_eta_id_ordine_scuola_fkey FOREIGN KEY (id_ordine_scuola) REFERENCES iscritto_d_ordine_scuola (id_ordine_scuola);
--
ALTER TABLE iscritto_t_scuola ADD COLUMN id_nido_contiguo INTEGER;
ALTER TABLE iscritto_t_scuola ADD CONSTRAINT iscritto_t_scuola_id_nido_contiguo_fkey FOREIGN KEY (id_nido_contiguo) REFERENCES iscritto_t_scuola (id_scuola);
--
ALTER TABLE iscritto_t_domanda_isc ADD COLUMN fl_consenso_td_conv CHARACTER VARYING(1);
ALTER TABLE iscritto_t_domanda_isc ADD COLUMN fl_cinque_anni CHARACTER VARYING(1);
ALTER TABLE iscritto_t_domanda_isc ADD COLUMN fl_lista_attesa CHARACTER VARYING(1);
ALTER TABLE iscritto_t_domanda_isc ADD COLUMN fl_fratello_contiguo CHARACTER VARYING(1);
--
CREATE TABLE iscritto_r_lista_attesa
(id_domanda_isc INTEGER NOT NULL, id_anno_scolastico INTEGER NOT NULL, scuola_lista CHARACTER VARYING(500) NOT NULL,
CONSTRAINT iscritto_r_lista_attesa_id_domanda_isc_fkey FOREIGN KEY (id_domanda_isc) REFERENCES "iscritto_t_domanda_isc" ("id_domanda_iscrizione"),
CONSTRAINT iscritto_r_lista_attesa_id_anno_scolastico_fkey FOREIGN KEY (id_anno_scolastico) REFERENCES "iscritto_t_anno_sco" ("id_anno_scolastico"));
--
CREATE TABLE iscritto_r_nido_contiguo
(id_domanda_isc INTEGER NOT NULL, id_anagrafica_soggetto INTEGER NOT NULL, id_nido_contiguo INTEGER NOT NULL,
CONSTRAINT iscritto_r_lista_attesa_id_domanda_isc_fkey FOREIGN KEY (id_domanda_isc) REFERENCES "iscritto_t_domanda_isc" ("id_domanda_iscrizione"),
CONSTRAINT iscritto_r_lista_attesa_id_anagrafica_soggetto_fkey FOREIGN KEY (id_anagrafica_soggetto) REFERENCES "iscritto_t_anagrafica_sog" ("id_anagrafica_soggetto"),
CONSTRAINT iscritto_r_lista_attesa_id_scuola_fkey FOREIGN KEY (id_nido_contiguo) REFERENCES iscritto_t_scuola (id_scuola));
--
COMMENT ON TABLE iscritto_r_lista_attesa IS 'Permanenza in lista di attesa della domanda';
COMMENT ON TABLE iscritto_r_nido_contiguo IS 'Dice chi è il fratello e quale nido contiguo frequenta';
COMMENT ON TABLE iscritto_t_anagrafica_gra IS 'Graduatoria per la domanda di uno specifico anno scolastico e tipo scuola';
COMMENT ON TABLE iscritto_t_step_gra IS 'Step di acquisizione programmata delle domande in graduatoria';
COMMENT ON TABLE iscritto_t_step_gra_con IS 'Step di elaborazione della graduatoria per l’assegnazione dei posti';
--
COMMENT ON COLUMN iscritto_t_anagrafica_gra.dt_inizio_iscr IS 'Data di apertura dello sportello per le domande';
COMMENT ON COLUMN iscritto_t_anagrafica_gra.dt_scadenza_iscr IS 'Data di chiusura dello sportello per le domande nei termini';
COMMENT ON COLUMN iscritto_t_anagrafica_gra.dt_fine_iscr IS 'Data di chiusura definitiva dello sportello per le domande fuori termine';
COMMENT ON COLUMN iscritto_t_anagrafica_gra.dt_scadenza_grad IS 'Data di fine validità della graduatoria per il relativo anno scolastico';
COMMENT ON COLUMN iscritto_r_nido_contiguo.id_anagrafica_soggetto IS 'Indica il fratello/sorella che frequenta il nido comunale contiguo alla materna del minore iscrivendo';
COMMENT ON COLUMN iscritto_r_nido_contiguo.id_nido_contiguo IS 'Indica il nido comunale contiguo alla materna prima scelta della domanda';
COMMENT ON COLUMN iscritto_t_domanda_isc.fl_consenso_td_conv IS 'Consenso al trattamento dati per l’eventuale selezione di una scuola convenzionata';
COMMENT ON COLUMN iscritto_t_domanda_isc.fl_cinque_anni IS 'Presenza condizione di punteggio aggiuntivo del bimbo di 5 anni';
COMMENT ON COLUMN iscritto_t_domanda_isc.fl_lista_attesa IS 'Lista d’attesa specifica per le materne';
COMMENT ON COLUMN  iscritto_t_domanda_isc.fl_fratello_contiguo IS 'Presenza condizione per fratello frequentante un nido contiguo';

----------------------------------------------------------------------
-- 2019-11-22 - ISBO-329
----------------------------------------------------------------------
CREATE SEQUENCE iscritto_t_eta_id_eta_seq;

----------------------------------------------------------------------
-- 2019-11-26 - ISBO-353
----------------------------------------------------------------------
ALTER TABLE iscritto_t_parametro ADD COLUMN dt_ult_verifica_nao timestamp NULL;

----------------------------------------------------------------------
-- 2019-12-03 - Lorita aggiunte grant sequence create
----------------------------------------------------------------------
GRANT ALL ON SEQUENCE iscritto_t_anagrafica_gra_id_anagrafica_gra_seq TO iscritto;
GRANT SELECT, UPDATE ON SEQUENCE iscritto_t_anagrafica_gra_id_anagrafica_gra_seq TO iscritto_rw;

GRANT ALL ON SEQUENCE iscritto_t_eta_id_eta_seq TO iscritto;
GRANT SELECT, UPDATE ON SEQUENCE iscritto_t_eta_id_eta_seq TO iscritto_rw;

GRANT ALL ON SEQUENCE iscritto_t_log_notifica_id_invio_massivo_seq TO iscritto;
GRANT SELECT, UPDATE ON SEQUENCE iscritto_t_log_notifica_id_invio_massivo_seq TO iscritto_rw;

GRANT ALL ON SEQUENCE iscritto_t_step_gra_id_step_gra_seq TO iscritto;
GRANT SELECT, UPDATE ON SEQUENCE iscritto_t_step_gra_id_step_gra_seq TO iscritto_rw;

----------------------------------------------------------------------
-- 2019-12-03 - Lorita aggiunta sequence mancante
----------------------------------------------------------------------
CREATE SEQUENCE iscritto_t_domanda_isc_protocollo_mat
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE iscritto_t_domanda_isc_protocollo_mat
  OWNER TO iscritto;
GRANT ALL ON SEQUENCE iscritto_t_domanda_isc_protocollo_mat TO iscritto;
GRANT SELECT, UPDATE ON SEQUENCE iscritto_t_domanda_isc_protocollo_mat TO iscritto_rw;


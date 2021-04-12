-------------------------------------------------------------------------------------------------------
-- DDL
-------------------------------------------------------------------------------------------------------
-- Lascio come traccia -- sospesa,da verificare
-- ALTER TABLE iscritto_t_utente DROP CONSTRAINT iscritto_t_utente_id_profilo_fkey;
-- ALTER TABLE iscritto_t_utente DROP id_profilo;

CREATE INDEX iscritto_r_punteggio_dom_idx ON iscritto_r_punteggio_dom (id_domanda_iscrizione ASC, dt_inizio_validita ASC);
CREATE INDEX iscritto_r_scuola_pre_idx ON iscritto_r_scuola_pre (id_domanda_iscrizione ASC);
CREATE INDEX iscritto_t_graduatoria_idx ON iscritto_t_graduatoria (id_domanda_iscrizione ASC, id_scuola ASC, id_step_gra_con ASC);

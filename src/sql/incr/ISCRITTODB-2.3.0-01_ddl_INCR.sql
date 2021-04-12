-- TABELLA: iscritto_r_utente_profilo --
CREATE TABLE iscritto_r_utente_profilo (
	id_prof_ute int4 NOT NULL,
	id_utente int4 NOT NULL,
	id_profilo int4 NOT NULL,
	dt_inizio timestamp NULL,
	dt_fine timestamp NULL,
	CONSTRAINT iscritto_r_utente_profilo_pkey PRIMARY KEY (id_prof_ute)
);
CREATE UNIQUE INDEX iscritto_r_utente_profilo_id_utente_id_profilo_dt_inizio_idx ON iscritto_r_utente_profilo (id_utente,id_profilo,dt_inizio);

ALTER TABLE iscritto_r_utente_profilo ADD CONSTRAINT iscritto_r_utente_profilo_id_utente_fkey FOREIGN KEY (id_utente) REFERENCES iscritto_t_utente(id_utente);

-- TABELLA: iscritto_r_profilo_scuole --
CREATE TABLE iscritto_r_profilo_scuole (
	id_prof_ute int4 NOT NULL,
	id_scuola int4 NOT NULL,
	CONSTRAINT iscritto_r_profilo_scuole_pkey PRIMARY KEY (id_prof_ute, id_scuola)
);

ALTER TABLE iscritto_r_profilo_scuole ADD CONSTRAINT iscritto_r_profili_trasversali_id_profilo_fkey FOREIGN KEY (id_prof_ute) REFERENCES iscritto_r_utente_profilo(id_prof_ute);

-- TABELLA: iscritto_t_debug --
CREATE TABLE iscritto_t_debug (
	"data" varchar(30) NULL,
	istruzione varchar(1000) NULL
);
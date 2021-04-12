----------------------------------------------------------------------
-- 2020-01-15 - P.S. --> Creazione Tabelle riportato da vers. 2.0
----------------------------------------------------------------------
CREATE TABLE iscritto_t_freq_nido_sise (
codice_fiscale varchar(16) NOT NULL,
id_anno_scolastico int4 NOT NULL,
id_scuola int4 NOT NULL,
cod_fascia varchar(1) NOT NULL,
dt_variazione timestamp NOT NULL DEFAULT now(),
fl_attivo_sospeso int4 NULL,
CONSTRAINT iscritto_t_freq_nido_sise_pkey PRIMARY KEY (codice_fiscale, id_anno_scolastico, id_scuola),
CONSTRAINT iscritto_t_freq_nido_sise_id_anno_scolastico_fkey FOREIGN KEY (id_anno_scolastico) REFERENCES iscritto_t_anno_sco(id_anno_scolastico),
CONSTRAINT iscritto_t_freq_nido_sise_id_scuola_fkey FOREIGN KEY (id_scuola) REFERENCES iscritto_t_scuola(id_scuola)
);

CREATE TABLE iscritto_tmp_freq_sise (
codice_fiscale text NULL,
codice_anno_scolastico text NULL,
cod_scuola text NULL,
classe text NULL,
id_stato_freq int4 NULL
);

----------------------------------------------------------------------
-- 2020-01-15 - P.S. --> Modifica Tabelle
----------------------------------------------------------------------
ALTER TABLE iscritto_t_dipendente ALTER COLUMN azienda TYPE varchar(200);

----------------------------------------------------------------------
-- 2020-01-30 - P.S. --> Cittadinanza
----------------------------------------------------------------------
ALTER TABLE iscritto_t_stato add codice_istat character varying(6);
ALTER TABLE iscritto_t_stato add cittadinanza character varying(80);

ALTER TABLE iscritto_t_anagrafica_sog add id_stato_citt integer;

ALTER TABLE iscritto_t_anagrafica_sog add CONSTRAINT iscritto_t_anagrafica_sog_id_stato_citt_fkey FOREIGN KEY (id_stato_citt)
      REFERENCES iscritto_t_stato (id_stato);

----------------------------------------------------------------------
-- 2020-02-21 - P.S. --> Modifica dimensione campi
--                       Constraints UNIQUE
----------------------------------------------------------------------
ALTER TABLE ISCRITTO_T_STUDENTE ALTER COLUMN DENOMINAZIONE_SCUOLA TYPE varchar(200);
ALTER TABLE ISCRITTO_T_DISOCCUPATO_EX ALTER COLUMN INDIRIZZO TYPE varchar(100);

alter table ISCRITTO_T_ANAGRAFICA_GRA add constraint COD_ANAGRAFICA_GRA_UNIQUE unique(COD_ANAGRAFICA_GRA);
alter table ISCRITTO_T_SCUOLA add constraint COD_SCUOLA_UNIQUE unique(COD_SCUOLA);

----------------------------------------------------------------------
-- 2020-02-17 - P.S. --> Upd tab iscritto_t_fratello_fre
----------------------------------------------------------------------
ALTER TABLE iscritto_t_fratello_fre add id_stato_citt integer;

ALTER TABLE iscritto_t_fratello_fre add CONSTRAINT iscritto_t_fratello_fre_id_stato_citt_fkey FOREIGN KEY (id_stato_citt)
      REFERENCES iscritto_t_stato (id_stato);

----------------------------------------------------------------------
-- 2020-03-03 - P.S. --> iscritto_t_anagrafica_gra
----------------------------------------------------------------------
alter table iscritto_t_anagrafica_gra add dt_inizio_grad timestamp;

----------------------------------------------------------------------
-- 2020-01-30 - P.S. --> Ordine scuola
----------------------------------------------------------------------

ALTER TABLE iscritto_t_punteggio ADD COLUMN id_ordine_scuola integer;

ALTER TABLE iscritto_t_punteggio
  ADD CONSTRAINT iscritto_t_punteggio_id_ordine_scuola_fkey
  FOREIGN KEY (id_ordine_scuola)
  REFERENCES iscritto_d_ordine_scuola (id_ordine_scuola);

-- 

DROP TABLE iscritto_t_freq_nido_sise;

CREATE TABLE iscritto_t_freq_nido_sise (
	codice_fiscale varchar(16) NOT NULL,
	id_anno_scolastico int4 NOT NULL,
	id_scuola int4 NOT NULL,
	cod_fascia varchar(1) NOT NULL,
	dt_variazione timestamp NOT NULL DEFAULT now(),
	fl_attivo_sospeso int4 NOT NULL,
	CONSTRAINT iscritto_t_freq_nido_sise_pkey PRIMARY KEY (codice_fiscale, id_anno_scolastico, id_scuola, cod_fascia, fl_attivo_sospeso),
	CONSTRAINT iscritto_t_freq_nido_sise_id_anno_scolastico_fkey FOREIGN KEY (id_anno_scolastico) REFERENCES iscritto_t_anno_sco(id_anno_scolastico),
	CONSTRAINT iscritto_t_freq_nido_sise_id_scuola_fkey FOREIGN KEY (id_scuola) REFERENCES iscritto_t_scuola(id_scuola)
);


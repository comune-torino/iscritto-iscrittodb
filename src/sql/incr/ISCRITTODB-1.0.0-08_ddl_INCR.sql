CREATE TABLE ISCRITTO_R_SOGGETTO_REL
(
    id_anagrafica_soggetto INTEGER NOT NULL ,
    id_tipo_soggetto     INTEGER NOT NULL
);

ALTER TABLE ISCRITTO_R_SOGGETTO_REL
    ADD  PRIMARY KEY (id_anagrafica_soggetto,id_tipo_soggetto);



ALTER TABLE ISCRITTO_R_SOGGETTO_REL
    ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_R_SOGGETTO_REL
    ADD FOREIGN KEY (id_tipo_soggetto) REFERENCES ISCRITTO_D_TIPO_SOG (id_tipo_soggetto);

----------------------------------------------------------------------
-- 2018-10-17
----------------------------------------------------------------------

DROP TABLE IF EXISTS ISCRITTO_R_PROFILO_ATT CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ATTIVITA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_FUNZIONE CASCADE;

CREATE TABLE ISCRITTO_R_PROFILO_ATT
(
	id_profilo           INTEGER NOT NULL ,
	id_attivita          INTEGER NOT NULL ,
	fl_RW                VARCHAR(1) NOT NULL
);

ALTER TABLE ISCRITTO_R_PROFILO_ATT
	ADD  PRIMARY KEY (id_profilo,id_attivita);

CREATE TABLE ISCRITTO_T_ATTIVITA
(
	id_attivita          INTEGER NOT NULL ,
	cod_attivita         VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(200) NOT NULL ,
	id_funzione          INTEGER NOT NULL
);

ALTER TABLE ISCRITTO_T_ATTIVITA
	ADD  PRIMARY KEY (id_attivita);

CREATE TABLE ISCRITTO_T_FUNZIONE
(
	id_funzione          INTEGER NOT NULL ,
	cod_funzione         VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(200) NULL
);

ALTER TABLE ISCRITTO_T_FUNZIONE
	ADD  PRIMARY KEY (id_funzione);

ALTER TABLE ISCRITTO_R_PROFILO_ATT
	ADD FOREIGN KEY (id_profilo) REFERENCES ISCRITTO_D_PROFILO (id_profilo);

ALTER TABLE ISCRITTO_R_PROFILO_ATT
	ADD FOREIGN KEY (id_attivita) REFERENCES ISCRITTO_T_ATTIVITA (id_attivita);

ALTER TABLE ISCRITTO_T_ATTIVITA
	ADD FOREIGN KEY (id_funzione) REFERENCES ISCRITTO_T_FUNZIONE (id_funzione);

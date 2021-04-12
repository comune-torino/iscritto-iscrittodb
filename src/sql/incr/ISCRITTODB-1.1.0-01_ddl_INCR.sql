/*
Incremento numero 15 (upgrade per istruttoria e graduatoria)

PRIMO BLOCCO
*/
ALTER TABLE ISCRITTO_R_SCUOLA_PRE ADD COLUMN id_stato_scu INTEGER NULL;

ALTER TABLE ISCRITTO_R_SCUOLA_PRE ADD COLUMN dt_stato TIMESTAMP NULL;

ALTER TABLE ISCRITTO_R_SCUOLA_PRE ADD FOREIGN KEY (id_stato_scu) REFERENCES ISCRITTO_D_STATO_SCU (id_stato_scu) ON DELETE SET NULL;

alter table ISCRITTO_T_PARAMETRO ADD COLUMN step_in_corso INTEGER NULL;

ALTER TABLE ISCRITTO_D_CONDIZIONE_PUN  ADD COLUMN id_tipo_allegato INTEGER NULL;

ALTER TABLE ISCRITTO_D_CONDIZIONE_PUN ADD FOREIGN KEY (id_tipo_allegato) REFERENCES ISCRITTO_D_TIPO_ALL (id_tipo_allegato) ON DELETE SET NULL;

ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM  ADD COLUMN fl_integrazione VARCHAR(1) NULL;

/*
15.2 (SECONDO BLOCCO)
*/
ALTER TABLE ISCRITTO_T_PARAMETRO ADD COLUMN testo_SMS_amm VARCHAR(180) NULL;

ALTER TABLE ISCRITTO_T_INVIO_SISE  DROP COLUMN id_tipo_pasto;

ALTER TABLE ISCRITTO_T_INVIO_SISE RENAME data_accettazione to dt_accettazione;

ALTER TABLE ISCRITTO_T_INVIO_SISE RENAME data_invio to dt_invio;

ALTER TABLE ISCRITTO_T_INVIO_SISE ADD COLUMN id_scuola INTEGER NULL;
ALTER TABLE ISCRITTO_T_INVIO_SISE ADD COLUMN id_tipo_frequenza INTEGER NULL;

ALTER TABLE ISCRITTO_T_INVIO_SISE ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola) ON DELETE SET NULL;

ALTER TABLE ISCRITTO_T_INVIO_SISE ADD FOREIGN KEY (id_tipo_frequenza) REFERENCES ISCRITTO_D_TIPO_FRE (id_tipo_frequenza) ON DELETE SET NULL;

CREATE TABLE ISCRITTO_T_ALLEGATO_RED
(
	id_allegato          INTEGER NOT NULL ,
	id_tipo_allegato     INTEGER NOT NULL ,
	data_inizio_validita timestamp NOT NULL ,
	data_fine_validita   timestamp NULL
);

ALTER TABLE ISCRITTO_T_ALLEGATO_RED ADD PRIMARY KEY (id_allegato, data_inizio_validita);
ALTER TABLE ISCRITTO_T_ALLEGATO_RED ADD FOREIGN KEY (id_allegato) REFERENCES ISCRITTO_T_ALLEGATO (id_allegato);
ALTER TABLE ISCRITTO_T_ALLEGATO_RED ADD FOREIGN KEY (id_tipo_allegato) REFERENCES ISCRITTO_D_TIPO_ALL (id_tipo_allegato);

INSERT INTO iscritto_d_condizione_pun (cod_condizione,descrizione,id_condizione_punteggio,fl_istruttoria,id_tipo_istruttoria,id_tipo_allegato) VALUES ('CF_FRA_ISC','Presenza di fratelli/sorelle iscrivendi gli stessi nidi',23,'N',null,null);
INSERT INTO iscritto_t_punteggio (id_punteggio,punti,dt_inizio_validita,dt_fine_validita,id_condizione_punteggio) VALUES (23,20,to_date('2019-04-04','yyy-MM-dd'),null,23);

/* ISTRUTTORIA - mappatura delle condizioni di punteggio sui profili applicativi */
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 1);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 2);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 3);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 7);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 8);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 9);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 10);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 4);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 6);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 5);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 11);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 12);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 13);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 14);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 15);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 16);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 17);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 18);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 19);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 20);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 21);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 22);
INSERT INTO iscritto_r_profilo_cp (id_profilo, id_condizione_punteggio) VALUES (1, 23);


/*
 * 2019-04-30
 */
INSERT INTO iscritto_t_attivita (id_attivita,cod_attivita,descrizione,link,id_funzione,ordinamento) VALUES
(13,'ISTR_VAP','Verifica ammissibiltà preferenze','/istruttoria/verifiche/ammissibilita',2,NULL)
;

INSERT INTO iscritto_t_privilegio (id_privilegio,cod_privilegio,descrizione,id_attivita) VALUES
(18,'P_ISTR_VAP','Verifica Ammissibilità Preferenze',13)
;


CREATE TABLE  iscritto_tmp_domanda
              ( id_domanda_iscrizione INTEGER NOT NULL
              );

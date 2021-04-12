/*
*/
ALTER TABLE ISCRITTO_T_GRADUATORIA ADD COLUMN id_stato_scu INTEGER NOT NULL;

ALTER TABLE ISCRITTO_T_GRADUATORIA DROP COLUMN 	id_stato_gra;

ALTER TABLE ISCRITTO_T_GRADUATORIA ADD FOREIGN KEY (id_stato_scu) REFERENCES ISCRITTO_D_STATO_SCU (id_stato_scu) ON DELETE SET NULL;

ALTER TABLE ISCRITTO_T_GRADUATORIA DROP COLUMN 	id_step_gra;

ALTER TABLE ISCRITTO_T_GRADUATORIA ADD COLUMN id_step_gra_con INTEGER NULL;

alter table iscritto_t_graduatoria alter column punteggio drop not null;

CREATE SEQUENCE iscritto_t_graduatoria_id_graduatoria_seq;


ALTER TABLE ISCRITTO_T_STEP_GRA ADD COLUMN 	dt_allegati TIMESTAMP NULL ;

ALTER TABLE ISCRITTO_T_STEP_GRA DROP COLUMN ID_STATO_GRA;

ALTER TABLE iscritto_t_step_gra RENAME COLUMN dt_step_grad TO dt_step_gra;

CREATE TABLE ISCRITTO_T_STEP_GRA_CON
(
	id_step_gra_con      INTEGER NOT NULL ,
	id_step_gra          INTEGER NULL ,
	id_stato_gra         INTEGER NULL ,
	fl_ammissioni        VARCHAR(1) NULL, 
	fl_calcolo_in_corso  VARCHAR(1) NULL, 
	dt_step_con          TIMESTAMP NULL 
);



ALTER TABLE ISCRITTO_T_STEP_GRA_CON ADD  PRIMARY KEY (id_step_gra_con);



ALTER TABLE ISCRITTO_T_STEP_GRA_CON ADD FOREIGN KEY (id_step_gra) REFERENCES ISCRITTO_T_STEP_GRA (id_step_gra) ON DELETE SET NULL;

ALTER TABLE ISCRITTO_T_GRADUATORIA ADD FOREIGN KEY (id_step_gra_con) REFERENCES ISCRITTO_T_STEP_GRA_CON (id_step_gra_con) ON DELETE SET NULL;

CREATE SEQUENCE iscritto_t_step_gra_con_id_step_gra_con_seq;



delete from iscritto_d_stato_gra;

INSERT INTO iscritto_d_stato_gra (id_stato_gra,cod_stato_gra,descrizione) VALUES 
(1,'CAL','Da calcolare')
,(2,'PRO','Provvisoria')
,(4,'DEF','Definitiva')
,(3,'PRO_CON','Provvisoria congelata')
,(5,'DEF_CON','Definitiva congelata')
,(6,'PUB','Pubblicata')
;



INSERT INTO iscritto_d_stato_scu (id_stato_scu,cod_stato_scu,descrizione) VALUES (9,'CAN_R_1SC','Cancellazione per rinuncia prima scelta');
INSERT INTO iscritto_d_stato_scu (id_stato_scu,cod_stato_scu,descrizione) VALUES (10,'CAN_RIN','Cancellazione per rinuncia');
INSERT INTO iscritto_d_stato_scu (id_stato_scu,cod_stato_scu,descrizione) VALUES (11,'NON_AMM','Non ammissibile');

CREATE SEQUENCE iscritto_t_invio_sms_id_invio_sms_seq;


drop table iscritto_t_invio_sise;

CREATE TABLE ISCRITTO_T_ACC_RIN
(
	id_accettazione_rin  INTEGER NOT NULL ,
	id_utente            INTEGER NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_scuola            INTEGER NOT NULL ,
	dt_operazione        TIMESTAMP NOT NULL ,
	fl_A_R             VARCHAR(1) NOT NULL ,
	fl_auto            VARCHAR(1) NOT NULL ,
	id_tipo_frequenza    INTEGER NOT NULL 
);



ALTER TABLE ISCRITTO_T_ACC_RIN ADD  PRIMARY KEY (id_accettazione_rin);



ALTER TABLE ISCRITTO_T_ACC_RIN ADD FOREIGN KEY (id_utente) REFERENCES ISCRITTO_T_UTENTE (id_utente);



ALTER TABLE ISCRITTO_T_ACC_RIN ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ACC_RIN ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ACC_RIN ADD FOREIGN KEY (id_tipo_frequenza) REFERENCES ISCRITTO_D_TIPO_FRE (id_tipo_frequenza) ON DELETE SET NULL;


CREATE TABLE ISCRITTO_T_INVIO_ACC
(
	id_accettazione_rin  INTEGER NOT NULL ,
	telefono             VARCHAR(20) NOT NULL ,
	dt_invio_sise        TIMESTAMP NULL ,
	dt_invio_scuola      TIMESTAMP NULL 
);

ALTER TABLE ISCRITTO_T_INVIO_ACC ADD  PRIMARY KEY (id_accettazione_rin);

ALTER TABLE ISCRITTO_T_INVIO_ACC ADD FOREIGN KEY (id_accettazione_rin) REFERENCES ISCRITTO_T_ACC_RIN(id_accettazione_rin) ON DELETE CASCADE;


CREATE SEQUENCE iscritto_t_acc_rin_id_accettazione_rin;

alter table iscritto_t_invio_sms alter column telefono type varchar(15);

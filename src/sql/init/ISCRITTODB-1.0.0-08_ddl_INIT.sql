DROP TABLE IF EXISTS ISCRITTO_D_TIPO_PRE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_TIPO_SEZ CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_CIRCOSCRIZIONE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_DIPENDENTE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_INDIRIZZO_RES CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ISEE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_R_PUNTEGGIO_DOM CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_SERVIZI_SOC CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_TRASFERIMENTO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_GENITORE_SOLO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_AUTONOMO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_DISOCCUPATO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_DISOCCUPATO_EX CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_STUDENTE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_CONDIZIONE_OCC CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_TIP_COND_OCC CASCADE;
DROP TABLE IF EXISTS ISCRITTO_R_SCUOLA_PRE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_FRATELLO_FRE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_PUNTEGGIO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_CONDIZIONE_PUN CASCADE;
DROP TABLE IF EXISTS ISCRITTO_L_AUDIT_LOG CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ALLEGATO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_TIPO_ALL CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_CONDIZIONE_SAN CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ANAGRAFICA_SOG CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_TIPO_SOG CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_STATO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_COMUNE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_RELAZIONE_PAR CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_CLASSE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_GRADUATORIA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_TIPO_FRE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_DOMANDA_ISC CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_STATO_DOM CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_UTENTE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_GENITORE_SOL CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_COABITAZIONE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_SCUOLA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_VERSIONE_GRA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ETA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_FASCIA_ETA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ETA_FRATELLO_FREQ CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_CATEGORIA_SCU CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ANAGRAFICA_GRA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_ORDINE_SCUOLA CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_ANNO_SCO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_R_PROFILO_SEZ CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_SEZIONE CASCADE;
DROP TABLE IF EXISTS ISCRITTO_D_PROFILO CASCADE;
DROP TABLE IF EXISTS ISCRITTO_T_PARAMETRO CASCADE;


CREATE TABLE ISCRITTO_D_TIPO_SEZ
(
	id_tipo_sezione      INTEGER NOT NULL ,
	cod_tipo_sezione     VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(200) NULL
);


ALTER TABLE ISCRITTO_D_TIPO_SEZ
	ADD  PRIMARY KEY (id_tipo_sezione);


CREATE TABLE ISCRITTO_D_TIPO_PRE
(
	id_tipo_presentazione INTEGER NOT NULL ,
	cod_tipo_presentazione VARCHAR(5) NOT NULL ,
	descrizione          VARCHAR(200) NOT NULL
);

ALTER TABLE ISCRITTO_D_TIPO_PRE
	ADD  PRIMARY KEY (id_tipo_presentazione);


CREATE TABLE ISCRITTO_D_CIRCOSCRIZIONE
(
	id_circoscrizione    INTEGER NOT NULL ,
	cod_circoscrizione   VARCHAR(10) NOT NULL ,
	descrizione          VARCHAR(100) NOT NULL
);


ALTER TABLE ISCRITTO_D_CIRCOSCRIZIONE
	ADD  PRIMARY KEY (id_circoscrizione);



CREATE TABLE ISCRITTO_D_FASCIA_ETA
(
	id_fascia_eta        INTEGER NOT NULL ,
	cod_fascia_eta       VARCHAR(10) NOT NULL ,
	descrizione          VARCHAR(100) NOT NULL
);



ALTER TABLE ISCRITTO_D_FASCIA_ETA
	ADD  PRIMARY KEY (id_fascia_eta);



CREATE TABLE ISCRITTO_D_CATEGORIA_SCU
(
	id_categoria_scu     INTEGER NOT NULL ,
	codice_categoria_scu VARCHAR(10) NOT NULL ,
	descrizione          VARCHAR(300) NOT NULL
);



ALTER TABLE ISCRITTO_D_CATEGORIA_SCU
	ADD  PRIMARY KEY (id_categoria_scu);



CREATE TABLE ISCRITTO_D_COABITAZIONE
(
	id_coabitazione      INTEGER NOT NULL ,
	cod_coabitazione     VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_COABITAZIONE
	ADD  PRIMARY KEY (id_coabitazione);



CREATE TABLE ISCRITTO_D_TIP_CON_OCC
(
	id_tip_cond_occupazionale INTEGER NOT NULL ,
	cod_tip_cond_occupazionale VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_TIP_CON_OCC
	ADD  PRIMARY KEY (id_tip_cond_occupazionale);



CREATE TABLE ISCRITTO_D_CONDIZIONE_PUN
(
	cod_condizione       VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL ,
	id_condizione_punteggio INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_D_CONDIZIONE_PUN
	ADD  PRIMARY KEY (id_condizione_punteggio);



CREATE TABLE ISCRITTO_D_GENITORE_SOL
(
	id_tipo_genitore_solo INTEGER NOT NULL ,
	cod_tipo_genitore_solo VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_GENITORE_SOL
	ADD  PRIMARY KEY (id_tipo_genitore_solo);



CREATE TABLE ISCRITTO_D_ORDINE_SCUOLA
(
	id_ordine_scuola     INTEGER NOT NULL ,
	descrizione          VARCHAR(50) NOT NULL ,
	cod_ordine_scuola    VARCHAR(20) NOT NULL
);



ALTER TABLE ISCRITTO_D_ORDINE_SCUOLA
	ADD  PRIMARY KEY (id_ordine_scuola);



CREATE TABLE ISCRITTO_D_PROFILO
(
	id_profilo           INTEGER NOT NULL ,
	codice_profilo       VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_PROFILO
	ADD  PRIMARY KEY (id_profilo);



CREATE TABLE ISCRITTO_D_RELAZIONE_PAR
(
	id_rel_parentela     INTEGER NOT NULL ,
	cod_parentela        VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_RELAZIONE_PAR
	ADD  PRIMARY KEY (id_rel_parentela);



CREATE TABLE ISCRITTO_D_STATO_DOM
(
	id_stato_domanda     INTEGER NOT NULL ,
	cod_stato_domanda    VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_STATO_DOM
	ADD  PRIMARY KEY (id_stato_domanda);



CREATE TABLE ISCRITTO_D_TIPO_SOG
(
	id_tipo_soggetto     INTEGER NOT NULL ,
	cod_tipo_soggetto    VARCHAR(20) NULL ,
	descrizione          VARCHAR(200) NULL
);



ALTER TABLE ISCRITTO_D_TIPO_SOG
	ADD  PRIMARY KEY (id_tipo_soggetto);



CREATE TABLE ISCRITTO_D_TIPO_ALL
(
	id_tipo_allegato INTEGER NOT NULL ,
	cod_tipo_allegato VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL
);



ALTER TABLE ISCRITTO_D_TIPO_ALL
	ADD  PRIMARY KEY (id_tipo_allegato);



CREATE TABLE ISCRITTO_D_TIPO_FRE
(
	cod_tipo_frequenza VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL ,
	id_tipo_frequenza INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_D_TIPO_FRE
	ADD  PRIMARY KEY (id_tipo_frequenza);



CREATE TABLE ISCRITTO_L_AUDIT_LOG
(
	data_ora             TIMESTAMP NULL ,
	id_app               VARCHAR(100) NULL ,
	ip_address           VARCHAR(40) NULL ,
	utente               VARCHAR(100) NULL ,
	operazione           VARCHAR(50) NULL ,
	ogg_oper             VARCHAR(500) NULL ,
	key_oper             VARCHAR(500) NULL
);



CREATE TABLE ISCRITTO_R_PROFILO_SEZ
(
	id_profilo           INTEGER NOT NULL ,
	id_sezione           INTEGER NOT NULL ,
	fl_rw                VARCHAR(1) NOT NULL
);



ALTER TABLE ISCRITTO_R_PROFILO_SEZ
	ADD  PRIMARY KEY (id_profilo,id_sezione);



CREATE TABLE ISCRITTO_R_PUNTEGGIO_DOM
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_condizione_punteggio INTEGER NOT NULL ,
	id_utente            INTEGER NULL ,
	dt_modifica          TIMESTAMP NULL ,
	fl_valido            VARCHAR(1) NOT NULL ,
	note                 VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD  PRIMARY KEY (id_domanda_iscrizione,id_condizione_punteggio);



CREATE TABLE ISCRITTO_R_SCUOLA_PRE
(
	posizione            INTEGER NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_scuola            INTEGER NOT NULL ,
	fl_fuori_termine     VARCHAR(1) NOT NULL ,
	id_tipo_frequenza INTEGER NOT NULL ,
	punteggio            INTEGER NOT NULL ,
	fl_rinuncia          VARCHAR(1) NOT NULL
);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD  PRIMARY KEY (id_domanda_iscrizione,id_scuola,id_tipo_frequenza);



CREATE TABLE ISCRITTO_T_ALLEGATO
(
	documento            BYTEA NOT NULL ,
	protocollo           VARCHAR(50) NOT NULL ,
	id_allegato          INTEGER NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_tipo_allegato INTEGER NOT NULL ,
	data_inserimento     TIMESTAMP NOT NULL ,
	nome_file            VARCHAR(200) NOT NULL ,
	mime_type            VARCHAR(100) NOT NULL
);



ALTER TABLE ISCRITTO_T_ALLEGATO
	ADD  PRIMARY KEY (id_allegato);



CREATE TABLE ISCRITTO_T_ANAGRAFICA_GRA
(
	id_anagrafica_gra    INTEGER NOT NULL ,
	cod_anagrafica_gra   VARCHAR(10) NOT NULL ,
	dt_scadenza_iscr     TIMESTAMP NOT NULL ,
	dt_scadenza_grad     TIMESTAMP NOT NULL ,
	dt_scadenza_ricorsi  TIMESTAMP NOT NULL ,
	id_anno_scolastico   INTEGER NOT NULL ,
	id_ordine_scuola     INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_GRA
	ADD  PRIMARY KEY (id_anagrafica_gra);



CREATE TABLE ISCRITTO_T_ANAGRAFICA_SOG
(
	cognome              VARCHAR(50) NOT NULL ,
	nome                 VARCHAR(50) NOT NULL ,
	data_nascita         TIMESTAMP NULL ,
	codice_fiscale       VARCHAR(16) NULL ,
	email                VARCHAR(50) NULL ,
	recapito_no_residenza VARCHAR(100) NULL ,
	recapito_futuro      VARCHAR(100) NULL ,
	sesso                VARCHAR(1) NULL ,
	fl_residenza_con_minore VARCHAR(1) NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_rel_parentela     INTEGER NOT NULL ,
	cittadinanza         VARCHAR(50) NULL ,
	fl_appartenenza_nucleo VARCHAR(1) NOT NULL ,
	id_comune_nascita    INTEGER NULL ,
	id_stato_nascita     INTEGER NULL ,
	ora_nascita          VARCHAR(5) NULL ,
	id_tipo_soggetto     INTEGER NOT NULL ,
	fl_richiedente       VARCHAR(1) NOT NULL
);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD  PRIMARY KEY (id_anagrafica_soggetto);



CREATE TABLE ISCRITTO_T_ANNO_SCO
(
	id_anno_scolastico   INTEGER NOT NULL ,
	cod_anno_scolastico  VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(100) NULL ,
	data_da              TIMESTAMP NOT NULL ,
	data_a               TIMESTAMP NOT NULL
);



ALTER TABLE ISCRITTO_T_ANNO_SCO
	ADD  PRIMARY KEY (id_anno_scolastico);



CREATE TABLE ISCRITTO_T_AUTONOMO
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	partitaIVA_CF        VARCHAR(20) NOT NULL ,
	comune_lavoro        VARCHAR(100) NOT NULL ,
	indirizzo_lavoro     VARCHAR(100) NOT NULL ,
	fl_esterno_area_integrata_GTT VARCHAR(1) NOT NULL,
	provincia_lavoro     VARCHAR(50) NULL
);



ALTER TABLE ISCRITTO_T_AUTONOMO
	ADD  PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_CLASSE
(
	id_classe            INTEGER NOT NULL ,
	id_scuola            INTEGER NOT NULL ,
	posti_liberi         INTEGER NOT NULL ,
	posti_ammessi        INTEGER NOT NULL ,
	denominazione        VARCHAR(50) NOT NULL ,
	id_anno_scolastico   INTEGER NOT NULL ,
	id_tipo_frequenza INTEGER NOT NULL ,
	data_da              DATE NOT NULL ,
	data_a               DATE NOT NULL ,
	posti_liberi_iniziali INTEGER NULL
);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD  PRIMARY KEY (id_classe);



CREATE TABLE ISCRITTO_T_COMUNE
(
	id_comune            INTEGER NOT NULL ,
	desc_comune          VARCHAR(62) NOT NULL ,
	desc_regione         VARCHAR(100) NOT NULL ,
	sigla_prov           VARCHAR(4) NOT NULL ,
	cod_catasto          VARCHAR(4) NOT NULL ,
	id_comune_sorg       INTEGER NOT NULL ,
	dt_start             TIMESTAMP NOT NULL ,
	dt_stop              TIMESTAMP NOT NULL ,
	rel_status           VARCHAR(1) NOT NULL ,
	istat_comune         VARCHAR(6) NOT NULL ,
	cap                  VARCHAR(5) NOT NULL ,
	istat_provincia      VARCHAR(3) NOT NULL ,
	desc_provincia       VARCHAR(100) NOT NULL ,
	istat_regione        VARCHAR(2) NOT NULL
);



ALTER TABLE ISCRITTO_T_COMUNE
	ADD  PRIMARY KEY (id_comune);



CREATE TABLE ISCRITTO_T_CONDIZIONE_OCC
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_tip_cond_occupazionale INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_CONDIZIONE_OCC
	ADD  PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_CONDIZIONE_SAN
(
	fl_disabilita        VARCHAR(1) NOT NULL ,
	fl_problemi_salute   VARCHAR(1) NOT NULL ,
	fl_stato_gravidanza  VARCHAR(1) NOT NULL ,
	fl_documenti_disabilita VARCHAR(1) NOT NULL ,
	fl_documenti_problemi_salute VARCHAR(1) NOT NULL ,
	fl_documenti_stato_gravidanza VARCHAR(1) NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_CONDIZIONE_SAN
	ADD  PRIMARY KEY (id_anagrafica_soggetto);



CREATE TABLE ISCRITTO_T_DIPENDENTE
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	azienda              VARCHAR(50) NULL ,
	comune_lavoro        VARCHAR(100) NULL ,
	indirizzo_lavoro     VARCHAR(100) NULL ,
	fl_esterno_area_integrata_GTT VARCHAR(1) NULL ,
	turni                VARCHAR(20) NULL,
	provincia_lavoro     VARCHAR(50) NULL
);



ALTER TABLE ISCRITTO_T_DIPENDENTE
	ADD  PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_DISOCCUPATO
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	dt_dichiarazione_disponibili TIMESTAMP NOT NULL ,
	comune_cpi            VARCHAR(100) NULL,
	id_tipo_presentazione INTEGER NOT NULL,
	provincia_cpi        VARCHAR(50) NULL
);



ALTER TABLE ISCRITTO_T_DISOCCUPATO
	ADD  PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_DISOCCUPATO_EX
(
	azienda_pIVA_CF      VARCHAR(20) NOT NULL ,
	comune_lavoro        VARCHAR(50) NOT NULL ,
	indirizzo            VARCHAR(50) NULL ,
	lavoro_dal           TIMESTAMP NOT NULL ,
	lavoro_al            TIMESTAMP NOT NULL ,
	id_disoccupato_ex_lav INTEGER NOT NULL ,
	id_condizione_occupazionale INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_DISOCCUPATO_EX
	ADD  PRIMARY KEY (id_disoccupato_ex_lav);



CREATE TABLE ISCRITTO_T_DOMANDA_ISC
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	punteggio            INTEGER NULL ,
	data_consegna        TIMESTAMP NOT NULL ,
	id_coabitazione      INTEGER NOT NULL ,
	protocollo           VARCHAR(30) NULL ,
	num_lista_attesa     INTEGER NULL ,
	id_tipo_genitore_solo INTEGER NULL ,
	note                 TEXT NULL ,
	id_utente            INTEGER NULL ,
	fl_fuori_termine     VARCHAR(1) NOT NULL ,
	fl_contestazione     VARCHAR(1) NOT NULL ,
	id_anno_scolastico   INTEGER NOT NULL ,
	id_ordine_scuola     INTEGER NOT NULL ,
	id_stato_domanda     INTEGER NOT NULL ,
	dt_modifica          TIMESTAMP NULL ,
	dt_cancellazione     TIMESTAMP NULL ,
	fl_istruita          VARCHAR(1) NULL ,
	fl_responsabilita_gen VARCHAR(1) NOT NULL ,
	fl_info_autocertificazione VARCHAR(1) NOT NULL ,
	fl_info_gdpr         VARCHAR(1) NOT NULL
);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD  PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_ETA
(
	id_eta               INTEGER NOT NULL ,
	data_da              TIMESTAMP NOT NULL ,
	data_a               TIMESTAMP NOT NULL ,
	id_anagrafica_gra    INTEGER NOT NULL ,
	id_fascia_eta        INTEGER NULL
);



ALTER TABLE ISCRITTO_T_ETA
	ADD  PRIMARY KEY (id_eta);



CREATE TABLE ISCRITTO_T_ETA_FRATELLO_FREQ
(
	id_anagrafica_gra    INTEGER NOT NULL ,
	id_categoria_scu     INTEGER NOT NULL ,
	id_ordine_scuola     INTEGER NOT NULL ,
	data_da              TIMESTAMP NOT NULL ,
	data_a               TIMESTAMP NOT NULL
);



ALTER TABLE ISCRITTO_T_ETA_FRATELLO_FREQ
	ADD  PRIMARY KEY (id_anagrafica_gra,id_categoria_scu,id_ordine_scuola);



CREATE TABLE ISCRITTO_T_FRATELLO_FRE
(
	id_fratello_frequentante INTEGER NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	cognome_fratello     VARCHAR(50) NOT NULL ,
	nome_fratello        VARCHAR(50) NOT NULL ,
	dt_nascita           TIMESTAMP NOT NULL
);



ALTER TABLE ISCRITTO_T_FRATELLO_FRE
	ADD  PRIMARY KEY (id_fratello_frequentante);



CREATE TABLE ISCRITTO_T_GENITORE_SOLO
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	num_sentenza         VARCHAR(50) NULL ,
	tribunale            VARCHAR(100) NULL ,
	dt_sentenza          TIMESTAMP NULL
);



ALTER TABLE ISCRITTO_T_GENITORE_SOLO
	ADD  PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_GRADUATORIA
(
	id_graduatoria       INTEGER NOT NULL ,
	id_versione_gra      INTEGER NOT NULL ,
	id_scuola            INTEGER NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	punteggio            INTEGER NOT NULL ,
	id_stato_domanda     INTEGER NOT NULL ,
	fl_fuori_termine     VARCHAR(1) NOT NULL ,
	id_tipo_frequenza INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_GRADUATORIA
	ADD  PRIMARY KEY (id_graduatoria);



CREATE TABLE ISCRITTO_T_INDIRIZZO_RES
(
	indirizzo            VARCHAR(100) NOT NULL ,
	cap                  VARCHAR(5) NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_comune            INTEGER NOT NULL,
	id_circoscrizione    INTEGER NOT NULL,
	id_stato_residenza   INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD  PRIMARY KEY (id_anagrafica_soggetto);



CREATE TABLE ISCRITTO_T_ISEE
(
	valore_isee          NUMERIC(10,2) NOT NULL ,
	dt_sottoscrizione    TIMESTAMP NOT NULL ,
	fl_richiedente       VARCHAR(1) NOT NULL ,
	fl_altro_genitore    VARCHAR(1) NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_ISEE
	ADD  PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_PUNTEGGIO
(
	id_punteggio         INTEGER NOT NULL ,
	punti                INTEGER NOT NULL ,
	id_scuola            INTEGER NULL ,
	dt_inizio_validita   TIMESTAMP NOT NULL ,
	dt_fine_validita     TIMESTAMP NULL ,
	id_condizione_punteggio INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_PUNTEGGIO
	ADD  PRIMARY KEY (id_punteggio);



CREATE TABLE ISCRITTO_T_SCUOLA
(
	id_scuola            INTEGER NOT NULL ,
	cod_scuola           VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NOT NULL ,
	indirizzo            VARCHAR(50) NOT NULL ,
	circoscrizione       VARCHAR(50) NOT NULL ,
	fl_eliminata         VARCHAR(1) NOT NULL ,
	id_categoria_scu     INTEGER NOT NULL ,
	id_ordine_scuola     INTEGER NOT NULL,
	id_circoscrizione    INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_SCUOLA
	ADD  PRIMARY KEY (id_scuola);



CREATE TABLE ISCRITTO_T_SERVIZI_SOC
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	nominativo           VARCHAR(100) NULL ,
	servizio             VARCHAR(300) NULL ,
	indirizzo            VARCHAR(50) NULL ,
	telefono             VARCHAR(50) NULL
);



ALTER TABLE ISCRITTO_T_SERVIZI_SOC
	ADD  PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_SEZIONE
(
	id_sezione           INTEGER NOT NULL ,
	cod_sezione          VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(200) NOT NULL,
	id_tipo_sezione      INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_SEZIONE
	ADD  PRIMARY KEY (id_sezione);



CREATE TABLE ISCRITTO_T_STATO
(
	id_stato             INTEGER NOT NULL ,
	id_stato_ministero   INTEGER NOT NULL ,
	continente           VARCHAR(30) NOT NULL ,
	stato                VARCHAR(65) NOT NULL ,
	codice               VARCHAR(4) NOT NULL ,
	dt_start             TIMESTAMP NOT NULL ,
	dt_stop              TIMESTAMP NOT NULL ,
	rel_status           VARCHAR(1) NOT NULL
);



ALTER TABLE ISCRITTO_T_STATO
	ADD  PRIMARY KEY (id_stato);



CREATE TABLE ISCRITTO_T_STUDENTE
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	denominazione_scuola VARCHAR(50) NOT NULL ,
	tipo_corso           VARCHAR(100) NOT NULL
);



ALTER TABLE ISCRITTO_T_STUDENTE
	ADD  PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_TRASFERIMENTO
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	dt_cambio_residenza  TIMESTAMP NOT NULL ,
	indirizzo_residenza_pre VARCHAR(100) NOT NULL ,
	indirizzo_residenza_new VARCHAR(100) NOT NULL ,
	indirizzo_nido_prov  VARCHAR(100) NOT NULL ,
	frequenza_dal        TIMESTAMP NOT NULL ,
	frequenza_al         TIMESTAMP NOT NULL
);



ALTER TABLE ISCRITTO_T_TRASFERIMENTO
	ADD  PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_UTENTE
(
	id_utente            INTEGER NOT NULL ,
	codice_fiscale       VARCHAR(16) NOT NULL ,
	cognome              VARCHAR(50) NOT NULL ,
	nome                 VARCHAR(50) NOT NULL ,
	id_scuola            INTEGER NULL ,
	id_profilo           INTEGER NOT NULL ,
	fl_eliminato         VARCHAR(1) NOT NULL
);



ALTER TABLE ISCRITTO_T_UTENTE
	ADD  PRIMARY KEY (id_utente);



CREATE TABLE ISCRITTO_T_VERSIONE_GRA
(
	versione             INTEGER NOT NULL ,
	dt_graduatoria       TIMESTAMP NOT NULL ,
	id_versione_gra      INTEGER NOT NULL ,
	id_anagrafica_gra    INTEGER NOT NULL ,
	note                 VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_T_VERSIONE_GRA
	ADD  PRIMARY KEY (id_versione_gra);



CREATE TABLE ISCRITTO_T_PARAMETRO
(
	num_nidi_pref          INTEGER NULL
);


ALTER TABLE ISCRITTO_T_SEZIONE
	ADD FOREIGN KEY (id_tipo_sezione) REFERENCES ISCRITTO_D_TIPO_SEZ (id_tipo_sezione);

ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD FOREIGN KEY (id_stato_residenza) REFERENCES ISCRITTO_T_STATO (id_stato);


ALTER TABLE ISCRITTO_T_DISOCCUPATO
	ADD FOREIGN KEY (id_tipo_presentazione) REFERENCES ISCRITTO_D_TIPO_PRE (id_tipo_presentazione);


ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD FOREIGN KEY (id_circoscrizione) REFERENCES ISCRITTO_D_CIRCOSCRIZIONE (id_circoscrizione);



ALTER TABLE ISCRITTO_T_SCUOLA
	ADD FOREIGN KEY (id_circoscrizione) REFERENCES ISCRITTO_D_CIRCOSCRIZIONE (id_circoscrizione);



ALTER TABLE ISCRITTO_R_PROFILO_SEZ
	ADD FOREIGN KEY (id_profilo) REFERENCES ISCRITTO_D_PROFILO (id_profilo);



ALTER TABLE ISCRITTO_R_PROFILO_SEZ
	ADD FOREIGN KEY (id_sezione) REFERENCES ISCRITTO_T_SEZIONE (id_sezione);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD FOREIGN KEY (id_condizione_punteggio) REFERENCES ISCRITTO_D_CONDIZIONE_PUN (id_condizione_punteggio);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD FOREIGN KEY (id_utente) REFERENCES ISCRITTO_T_UTENTE (id_utente) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD FOREIGN KEY (id_tipo_frequenza) REFERENCES ISCRITTO_D_TIPO_FRE (id_tipo_frequenza);



ALTER TABLE ISCRITTO_T_ALLEGATO
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_CONDIZIONE_SAN (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_ALLEGATO
	ADD FOREIGN KEY (id_tipo_allegato) REFERENCES ISCRITTO_D_TIPO_ALL (id_tipo_allegato);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_GRA
	ADD FOREIGN KEY (id_anno_scolastico) REFERENCES ISCRITTO_T_ANNO_SCO (id_anno_scolastico);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_GRA
	ADD FOREIGN KEY (id_ordine_scuola) REFERENCES ISCRITTO_D_ORDINE_SCUOLA (id_ordine_scuola);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_rel_parentela) REFERENCES ISCRITTO_D_RELAZIONE_PAR (id_rel_parentela);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_stato_nascita) REFERENCES ISCRITTO_T_STATO (id_stato) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_comune_nascita) REFERENCES ISCRITTO_T_COMUNE (id_comune) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_tipo_soggetto) REFERENCES ISCRITTO_D_TIPO_SOG (id_tipo_soggetto);



ALTER TABLE ISCRITTO_T_AUTONOMO
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD FOREIGN KEY (id_tipo_frequenza) REFERENCES ISCRITTO_D_TIPO_FRE (id_tipo_frequenza);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD FOREIGN KEY (id_anno_scolastico) REFERENCES ISCRITTO_T_ANNO_SCO (id_anno_scolastico);



ALTER TABLE ISCRITTO_T_CONDIZIONE_OCC
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_CONDIZIONE_OCC
	ADD FOREIGN KEY (id_tip_cond_occupazionale) REFERENCES ISCRITTO_D_TIP_CON_OCC (id_tip_cond_occupazionale);



ALTER TABLE ISCRITTO_T_CONDIZIONE_SAN
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_DIPENDENTE
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_DISOCCUPATO
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_DISOCCUPATO_EX
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_coabitazione) REFERENCES ISCRITTO_D_COABITAZIONE (id_coabitazione);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_tipo_genitore_solo) REFERENCES ISCRITTO_D_GENITORE_SOL (id_tipo_genitore_solo) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_utente) REFERENCES ISCRITTO_T_UTENTE (id_utente) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_anno_scolastico) REFERENCES ISCRITTO_T_ANNO_SCO (id_anno_scolastico);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_ordine_scuola) REFERENCES ISCRITTO_D_ORDINE_SCUOLA (id_ordine_scuola);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_stato_domanda) REFERENCES ISCRITTO_D_STATO_DOM (id_stato_domanda);



ALTER TABLE ISCRITTO_T_ETA
	ADD FOREIGN KEY (id_anagrafica_gra) REFERENCES ISCRITTO_T_ANAGRAFICA_GRA (id_anagrafica_gra);



ALTER TABLE ISCRITTO_T_ETA
	ADD FOREIGN KEY (id_fascia_eta) REFERENCES ISCRITTO_D_FASCIA_ETA (id_fascia_eta) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ETA_FRATELLO_FREQ
	ADD FOREIGN KEY (id_anagrafica_gra) REFERENCES ISCRITTO_T_ANAGRAFICA_GRA (id_anagrafica_gra);



ALTER TABLE ISCRITTO_T_ETA_FRATELLO_FREQ
	ADD FOREIGN KEY (id_categoria_scu) REFERENCES ISCRITTO_D_CATEGORIA_SCU (id_categoria_scu);



ALTER TABLE ISCRITTO_T_ETA_FRATELLO_FREQ
	ADD FOREIGN KEY (id_ordine_scuola) REFERENCES ISCRITTO_D_ORDINE_SCUOLA (id_ordine_scuola);



ALTER TABLE ISCRITTO_T_FRATELLO_FRE
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_GENITORE_SOLO
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_GRADUATORIA
	ADD FOREIGN KEY (id_versione_gra) REFERENCES ISCRITTO_T_VERSIONE_GRA (id_versione_gra);



ALTER TABLE ISCRITTO_T_GRADUATORIA
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola);



ALTER TABLE ISCRITTO_T_GRADUATORIA
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_GRADUATORIA
	ADD FOREIGN KEY (id_stato_domanda) REFERENCES ISCRITTO_D_STATO_DOM (id_stato_domanda);



ALTER TABLE ISCRITTO_T_GRADUATORIA
	ADD FOREIGN KEY (id_tipo_frequenza) REFERENCES ISCRITTO_D_TIPO_FRE (id_tipo_frequenza);



ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD FOREIGN KEY (id_comune) REFERENCES ISCRITTO_T_COMUNE (id_comune);



ALTER TABLE ISCRITTO_T_ISEE
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_PUNTEGGIO
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_PUNTEGGIO
	ADD FOREIGN KEY (id_condizione_punteggio) REFERENCES ISCRITTO_D_CONDIZIONE_PUN (id_condizione_punteggio);



ALTER TABLE ISCRITTO_T_SCUOLA
	ADD FOREIGN KEY (id_ordine_scuola) REFERENCES ISCRITTO_D_ORDINE_SCUOLA (id_ordine_scuola);



ALTER TABLE ISCRITTO_T_SCUOLA
	ADD FOREIGN KEY (id_categoria_scu) REFERENCES ISCRITTO_D_CATEGORIA_SCU (id_categoria_scu) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_SERVIZI_SOC
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_STUDENTE
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_TRASFERIMENTO
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_UTENTE
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_UTENTE
	ADD FOREIGN KEY (id_profilo) REFERENCES ISCRITTO_D_PROFILO (id_profilo);



ALTER TABLE ISCRITTO_T_VERSIONE_GRA
	ADD FOREIGN KEY (id_anagrafica_gra) REFERENCES ISCRITTO_T_ANAGRAFICA_GRA (id_anagrafica_gra);

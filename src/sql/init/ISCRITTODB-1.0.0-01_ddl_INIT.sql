
DROP TABLE ISCRITTO_R_PUNTEGGIO_DOM CASCADE;



DROP TABLE ISCRITTO_T_PUNTEGGIO CASCADE;



DROP TABLE ISCRITTO_D_CONDIZIONE_PUN CASCADE;



DROP TABLE ISCRITTO_T_INDIRIZZO_RES CASCADE;



DROP TABLE ISCRITTO_T_ISEE CASCADE;



DROP TABLE ISCRITTO_T_SERVIZI_SOC CASCADE;



DROP TABLE ISCRITTO_T_TRASFERIMENTO CASCADE;



DROP TABLE ISCRITTO_T_GENITORE_SOLO CASCADE;



DROP TABLE ISCRITTO_T_DIPENDENTE CASCADE;



DROP TABLE ISCRITTO_T_AUTONOMO CASCADE;



DROP TABLE ISCRITTO_T_DISOCCUPATO CASCADE;



DROP TABLE ISCRITTO_T_DISOCCUPATO_EX CASCADE;



DROP TABLE ISCRITTO_T_STUDENTE CASCADE;



DROP TABLE ISCRITTO_T_CONDIZIONE_OCC CASCADE;



DROP TABLE ISCRITTO_D_CONDIZIONE_OCC CASCADE;



DROP TABLE ISCRITTO_R_SCUOLA_PRE CASCADE;



DROP TABLE ISCRITTO_T_FRATELLO_FRE CASCADE;



DROP TABLE ISCRITTO_L_AUDIT_LOG CASCADE;



DROP TABLE ISCRITTO_T_ALLEGATO CASCADE;



DROP TABLE ISCRITTO_D_TIPOLOGIA_ALL CASCADE;



DROP TABLE ISCRITTO_T_CONDIZIONE_SAN CASCADE;



DROP TABLE ISCRITTO_T_ANAGRAFICA_SOG CASCADE;



DROP TABLE ISCRITTO_T_STATO CASCADE;



DROP TABLE ISCRITTO_T_COMUNE CASCADE;



DROP TABLE ISCRITTO_D_RELAZIONE_PAR CASCADE;



DROP TABLE ISCRITTO_T_DOMANDA_ISC CASCADE;



DROP TABLE ISCRITTO_T_UTENTE CASCADE;



DROP TABLE ISCRITTO_D_PROFILO CASCADE;



DROP TABLE ISCRITTO_D_STATO_DOM CASCADE;



DROP TABLE ISCRITTO_D_GENITORE_SOL CASCADE;



DROP TABLE ISCRITTO_D_COABITAZIONE CASCADE;



DROP TABLE ISCRITTO_T_CLASSE CASCADE;



DROP TABLE ISCRITTO_T_ANNO_SCO CASCADE;



DROP TABLE ISCRITTO_T_SCUOLA CASCADE;



DROP TABLE ISCRITTO_D_ORDINE_SCUOLA CASCADE;



DROP TABLE ISCRITTO_D_TIPOLOGIA_FRE CASCADE;



CREATE TABLE ISCRITTO_D_COABITAZIONE
(
	id_coabitazione      INTEGER NOT NULL ,
	cod_coabitazione     VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_COABITAZIONE
	ADD PRIMARY KEY (id_coabitazione);



CREATE TABLE ISCRITTO_D_CONDIZIONE_OCC
(
	id_tip_cond_occupazionale INTEGER NOT NULL ,
	cod_tip_cond_occupazionale VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_CONDIZIONE_OCC
	ADD PRIMARY KEY (id_tip_cond_occupazionale);



CREATE TABLE ISCRITTO_D_CONDIZIONE_PUN
(
	cod_condizione       VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NULL ,
	id_condizione_punteggio INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_D_CONDIZIONE_PUN
	ADD PRIMARY KEY (id_condizione_punteggio);



CREATE TABLE ISCRITTO_D_GENITORE_SOL
(
	id_tipo_genitore_solo INTEGER NOT NULL ,
	cod_tipo_genitore_solo VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_GENITORE_SOL
	ADD PRIMARY KEY (id_tipo_genitore_solo);



CREATE TABLE ISCRITTO_D_ORDINE_SCUOLA
(
	cod_ordine_scuola    VARCHAR(10) NOT NULL ,
	descrizione          VARCHAR(300) NULL
);



ALTER TABLE ISCRITTO_D_ORDINE_SCUOLA
	ADD PRIMARY KEY (cod_ordine_scuola);



CREATE TABLE ISCRITTO_D_PROFILO
(
	id_profilo           INTEGER NOT NULL ,
	codice_profilo       VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_PROFILO
	ADD PRIMARY KEY (id_profilo);



CREATE TABLE ISCRITTO_D_RELAZIONE_PAR
(
	id_rel_parentela     INTEGER NOT NULL ,
	cod_parentela        VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_RELAZIONE_PAR
	ADD PRIMARY KEY (id_rel_parentela);



CREATE TABLE ISCRITTO_D_STATO_DOM
(
	id_stato_domanda     INTEGER NOT NULL ,
	cod_stato_domanda    VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_STATO_DOM
	ADD PRIMARY KEY (id_stato_domanda);



CREATE TABLE ISCRITTO_D_TIPOLOGIA_ALL
(
	id_tipologia_allegato INTEGER NOT NULL ,
	cod_tipologia_allegato VARCHAR(10) NULL ,
	descrizione          VARCHAR(500) NULL
);



ALTER TABLE ISCRITTO_D_TIPOLOGIA_ALL
	ADD PRIMARY KEY (id_tipologia_allegato);



CREATE TABLE ISCRITTO_D_TIPOLOGIA_FRE
(
	cod_tipologia_frequenza VARCHAR(20) NOT NULL ,
	descrizione          VARCHAR(500) NULL ,
	id_tipologia_frequenza INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_D_TIPOLOGIA_FRE
	ADD PRIMARY KEY (id_tipologia_frequenza);



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



CREATE TABLE ISCRITTO_R_PUNTEGGIO_DOM
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_punteggio         INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD PRIMARY KEY (id_domanda_iscrizione,id_punteggio);



CREATE TABLE ISCRITTO_R_SCUOLA_PRE
(
	posizione            INTEGER NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_scuola            INTEGER NOT NULL ,
	fl_fuori_termine     VARCHAR(1) NULL ,
	id_tipologia_frequenza INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD PRIMARY KEY (id_domanda_iscrizione,id_scuola,id_tipologia_frequenza);



CREATE TABLE ISCRITTO_T_ALLEGATO
(
	documento            BYTEA NOT NULL ,
	protocollo           VARCHAR(50) NOT NULL ,
	id_allegato          INTEGER NOT NULL ,
	id_anagrafica_soggetto INTEGER NULL ,
	id_tipologia_allegato INTEGER NULL ,
	data_inserimento     TIMESTAMP NULL
);



ALTER TABLE ISCRITTO_T_ALLEGATO
	ADD PRIMARY KEY (id_allegato);



CREATE TABLE ISCRITTO_T_ANAGRAFICA_SOG
(
	cognome              VARCHAR(50) NULL ,
	nome                 VARCHAR(50) NULL ,
	data_ora_nascita     TIMESTAMP NULL ,
	codice_fiscale       VARCHAR(16) NULL ,
	email                VARCHAR(50) NULL ,
	recapito_no_residenza VARCHAR(100) NULL ,
	recapito_futuro      VARCHAR(100) NULL ,
	sesso                VARCHAR(1) NULL ,
	fl_residenza_con_minore VARCHAR(1) NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_rel_parentela     INTEGER NULL ,
	fl_tipo_soggetto     VARCHAR(1) NOT NULL ,
	cittadinanza         VARCHAR(50) NULL ,
	fl_appartenenza_nucleo VARCHAR(1) NULL ,
	id_comune_nascita    INTEGER NULL ,
	id_stato_nascita     INTEGER NULL
);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD PRIMARY KEY (id_anagrafica_soggetto);



CREATE TABLE ISCRITTO_T_ANNO_SCO
(
	id_anno_scolastico   INTEGER NOT NULL ,
	cod_anno_scolastico  VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL ,
	data_da              DATE NOT NULL ,
	data_a               DATE NOT NULL
);



ALTER TABLE ISCRITTO_T_ANNO_SCO
	ADD PRIMARY KEY (id_anno_scolastico);



CREATE TABLE ISCRITTO_T_AUTONOMO
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	partitaIVA_CF        VARCHAR(20) NULL ,
	comune_lavoro        VARCHAR(50) NULL ,
	indirizzo_lavoro     VARCHAR(50) NULL ,
	fl_esterno_area_integrata_GTT VARCHAR(1) NULL
);



ALTER TABLE ISCRITTO_T_AUTONOMO
	ADD PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_CLASSE
(
	id_classe            INTEGER NOT NULL ,
	fascia_da            DATE NULL ,
	fascia_a             DATE NULL ,
	id_scuola            INTEGER NOT NULL ,
	posti_liberi         INTEGER NULL ,
	posti_ammessi        INTEGER NULL ,
	denominazione        VARCHAR(50) NULL ,
	id_anno_scolastico   INTEGER NOT NULL ,
	id_tipologia_frequenza INTEGER NULL
);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD PRIMARY KEY (id_classe);



CREATE TABLE ISCRITTO_T_COMUNE
(
	id_comune            INTEGER NOT NULL ,
	desc_comune          VARCHAR(62) NULL ,
	desc_regione         VARCHAR(100) NULL ,
	sigla_prov           VARCHAR(4) NULL ,
	cod_catasto          VARCHAR(4) NULL ,
	id_comune_sorg       INTEGER NULL ,
	dt_start             TIMESTAMP NULL ,
	dt_stop              TIMESTAMP NULL ,
	r_status             VARCHAR(1) NULL ,
	istat_comune         VARCHAR(6) NULL ,
	cap                  VARCHAR(5) NULL ,
	istat_provincia      VARCHAR(3) NULL ,
	desc_provincia       VARCHAR(100) NULL ,
	istat_regione        VARCHAR(2) NULL
);



ALTER TABLE ISCRITTO_T_COMUNE
	ADD CONSTRAINT  XPKComune PRIMARY KEY (id_comune);



CREATE TABLE ISCRITTO_T_CONDIZIONE_OCC
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_tip_cond_occupazionale INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_CONDIZIONE_OCC
	ADD PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_CONDIZIONE_SAN
(
	fl_disabilita        VARCHAR(1) NULL ,
	fl_problemi_salute   VARCHAR(1) NULL ,
	fl_stato_gravidanza  VARCHAR(1) NULL ,
	fl_documenti_disabilita VARCHAR(1) NULL ,
	fl_documenti_problemi_salute VARCHAR(1) NULL ,
	fl_documenti_stato_gravidanza VARCHAR(1) NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_CONDIZIONE_SAN
	ADD PRIMARY KEY (id_anagrafica_soggetto);



CREATE TABLE ISCRITTO_T_DIPENDENTE
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	azienda              VARCHAR(50) NULL ,
	comune_lavoro        VARCHAR(50) NULL ,
	indirizzo_lavoro     VARCHAR(50) NULL ,
	fl_esterno_area_integrata_GTT VARCHAR(1) NULL ,
	turni                VARCHAR(20) NULL
);



ALTER TABLE ISCRITTO_T_DIPENDENTE
	ADD PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_DISOCCUPATO
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	data_dichiarazione_disponibili DATE NULL ,
	luogo_presentazione  VARCHAR(100) NULL
);



ALTER TABLE ISCRITTO_T_DISOCCUPATO
	ADD PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_DISOCCUPATO_EX
(
	azienda_pIVA_CF      VARCHAR(20) NULL ,
	comune_lavoro        VARCHAR(50) NULL ,
	indirizzo            VARCHAR(50) NULL ,
	lavoro_dal           DATE NULL ,
	lavoro_al            DATE NULL ,
	id_disoccupato_ex_lav INTEGER NOT NULL ,
	id_condizione_occupazionale INTEGER NULL
);



ALTER TABLE ISCRITTO_T_DISOCCUPATO_EX
	ADD PRIMARY KEY (id_disoccupato_ex_lav);



CREATE TABLE ISCRITTO_T_DOMANDA_ISC
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	punteggio            INTEGER NULL ,
	data_consegna        TIMESTAMP NOT NULL ,
	fl_disagio_sociale   VARCHAR(1) NULL ,
	id_coabitazione      INTEGER NULL ,
	protocollo           VARCHAR(30) NULL ,
	num_lista_attesa     INTEGER NULL ,
	fl_trasferimento     VARCHAR(1) NULL ,
	fl_presa_visione_condizioni VARCHAR(1) NULL ,
	fl_fratello          VARCHAR(1) NULL ,
	fl_valida            VARCHAR(1) NULL ,
	fl_condivisione_responsabilita VARCHAR(1) NULL ,
	fl_isee              VARCHAR(1) NULL ,
	id_tipo_genitore_solo INTEGER NULL ,
	fl_presa_visione_informativa VARCHAR(1) NULL ,
	note                 TEXT NULL ,
	id_stato_domanda     INTEGER NOT NULL ,
	id_utente            INTEGER NULL ,
	fl_fuori_termine     VARCHAR(1) NULL ,
	fl_contestazione     VARCHAR(1) NULL ,
	id_anno_scolastico   INTEGER NULL ,
	cod_ordine_scuola    VARCHAR(10) NULL
);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_FRATELLO_FRE
(
	id_fratello_frequentante INTEGER NOT NULL ,
	id_domanda_iscrizione INTEGER NOT NULL ,
	cognome_fratello     VARCHAR(50) NOT NULL ,
	nome_fratello        VARCHAR(50) NULL ,
	data_nascita         TIMESTAMP NULL
);



ALTER TABLE ISCRITTO_T_FRATELLO_FRE
	ADD PRIMARY KEY (id_fratello_frequentante);



CREATE TABLE ISCRITTO_T_GENITORE_SOLO
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	num_sentenza         VARCHAR(50) NULL ,
	tribunale            VARCHAR(100) NULL ,
	data_sentenza        DATE NULL
);



ALTER TABLE ISCRITTO_T_GENITORE_SOLO
	ADD PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_INDIRIZZO_RES
(
	indirizzo            VARCHAR(100) NULL ,
	CAP                  VARCHAR(5) NULL ,
	id_anagrafica_soggetto INTEGER NOT NULL ,
	id_comune            INTEGER NULL
);



ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD PRIMARY KEY (id_anagrafica_soggetto);



CREATE TABLE ISCRITTO_T_ISEE
(
	valore_isee          NUMERIC(10,2) NOT NULL ,
	data_sottoscrizione  DATE NOT NULL ,
	fl_richiedente       VARCHAR(1) NULL ,
	fl_altro_genitore    VARCHAR(1) NULL ,
	id_domanda_iscrizione INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_ISEE
	ADD PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_PUNTEGGIO
(
	id_punteggio         INTEGER NOT NULL ,
	punti                INTEGER NOT NULL ,
	id_scuola            INTEGER NULL ,
	data_inizio_validita DATE NOT NULL ,
	data_fine_validita   DATE NULL ,
	id_condizione_punteggio INTEGER NOT NULL
);



ALTER TABLE ISCRITTO_T_PUNTEGGIO
	ADD PRIMARY KEY (id_punteggio);



CREATE TABLE ISCRITTO_T_SCUOLA
(
	id_scuola            INTEGER NOT NULL ,
	cod_scuola           VARCHAR(20) NULL ,
	descrizione          VARCHAR(500) NULL ,
	indirizzo            VARCHAR(50) NULL ,
	circoscrizione       VARCHAR(50) NULL ,
	fl_gestione          VARCHAR(1) NULL ,
	cod_ordine_scuola    VARCHAR(10) NULL ,
	fl_eliminata         VARCHAR(1) NULL
);



ALTER TABLE ISCRITTO_T_SCUOLA
	ADD PRIMARY KEY (id_scuola);



CREATE TABLE ISCRITTO_T_SERVIZI_SOC
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	nominativo           VARCHAR(100) NULL ,
	servizio             VARCHAR(300) NULL ,
	indirizzo            VARCHAR(50) NULL ,
	telefono             VARCHAR(50) NULL
);



ALTER TABLE ISCRITTO_T_SERVIZI_SOC
	ADD PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_STUDENTE
(
	id_condizione_occupazionale INTEGER NOT NULL ,
	denominazione_scuola VARCHAR(50) NULL ,
	tipo_corso           VARCHAR(100) NULL
);



ALTER TABLE ISCRITTO_T_STUDENTE
	ADD PRIMARY KEY (id_condizione_occupazionale);



CREATE TABLE ISCRITTO_T_TRASFERIMENTO
(
	id_domanda_iscrizione INTEGER NOT NULL ,
	data_cambio_residenza DATE NULL ,
	indirizzo_residenza_pre VARCHAR(100) NULL ,
	indirizzo_residenza_new VARCHAR(100) NULL ,
	indirizzo_nido_prov  VARCHAR(100) NULL ,
	frequenza_dal        DATE NULL ,
	frequenza_al         DATE NULL
);



ALTER TABLE ISCRITTO_T_TRASFERIMENTO
	ADD PRIMARY KEY (id_domanda_iscrizione);



CREATE TABLE ISCRITTO_T_UTENTE
(
	id_utente            INTEGER NOT NULL ,
	codice_fiscale       VARCHAR(16) NOT NULL ,
	cognome              VARCHAR(50) NULL ,
	nome                 VARCHAR(50) NULL ,
	id_scuola            INTEGER NULL ,
	id_profilo           INTEGER NULL ,
	fl_eliminato         VARCHAR(1) NULL
);



ALTER TABLE ISCRITTO_T_UTENTE
	ADD PRIMARY KEY (id_utente);



CREATE TABLE ISCRITTO_T_STATO
(
	id_stato             INTEGER NOT NULL ,
	id_stato_ministero   INTEGER NULL ,
	continente           VARCHAR(30) NULL ,
	stato                VARCHAR(65) NULL ,
	codice               VARCHAR(4) NULL ,
	dt_start             TIMESTAMP NULL ,
	dt_stop              TIMESTAMP NULL ,
	rel_status           VARCHAR(1) NULL
);



ALTER TABLE ISCRITTO_T_STATO
	ADD PRIMARY KEY (id_stato);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_R_PUNTEGGIO_DOM
	ADD FOREIGN KEY (id_punteggio) REFERENCES ISCRITTO_T_PUNTEGGIO (id_punteggio);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola);



ALTER TABLE ISCRITTO_R_SCUOLA_PRE
	ADD FOREIGN KEY (id_tipologia_frequenza) REFERENCES ISCRITTO_D_TIPOLOGIA_FRE (id_tipologia_frequenza);



ALTER TABLE ISCRITTO_T_ALLEGATO
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_CONDIZIONE_SAN (id_anagrafica_soggetto) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ALLEGATO
	ADD FOREIGN KEY (id_tipologia_allegato) REFERENCES ISCRITTO_D_TIPOLOGIA_ALL (id_tipologia_allegato) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_rel_parentela) REFERENCES ISCRITTO_D_RELAZIONE_PAR (id_rel_parentela) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_stato_nascita) REFERENCES ISCRITTO_T_STATO (id_stato) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ANAGRAFICA_SOG
	ADD FOREIGN KEY (id_comune_nascita) REFERENCES ISCRITTO_T_COMUNE (id_comune) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_AUTONOMO
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD FOREIGN KEY (id_tipologia_frequenza) REFERENCES ISCRITTO_D_TIPOLOGIA_FRE (id_tipologia_frequenza) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_CLASSE
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola);



ALTER TABLE ISCRITTO_T_CLASSE
	ADD FOREIGN KEY (id_anno_scolastico) REFERENCES ISCRITTO_T_ANNO_SCO (id_anno_scolastico);



ALTER TABLE ISCRITTO_T_CONDIZIONE_OCC
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_CONDIZIONE_OCC
	ADD FOREIGN KEY (id_tip_cond_occupazionale) REFERENCES ISCRITTO_D_CONDIZIONE_OCC (id_tip_cond_occupazionale);



ALTER TABLE ISCRITTO_T_CONDIZIONE_SAN
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_DIPENDENTE
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_DISOCCUPATO
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_DISOCCUPATO_EX
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_coabitazione) REFERENCES ISCRITTO_D_COABITAZIONE (id_coabitazione) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_tipo_genitore_solo) REFERENCES ISCRITTO_D_GENITORE_SOL (id_tipo_genitore_solo) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_stato_domanda) REFERENCES ISCRITTO_D_STATO_DOM (id_stato_domanda);



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_utente) REFERENCES ISCRITTO_T_UTENTE (id_utente) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (id_anno_scolastico) REFERENCES ISCRITTO_T_ANNO_SCO (id_anno_scolastico) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_DOMANDA_ISC
	ADD FOREIGN KEY (cod_ordine_scuola) REFERENCES ISCRITTO_D_ORDINE_SCUOLA (cod_ordine_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_FRATELLO_FRE
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_GENITORE_SOLO
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD FOREIGN KEY (id_anagrafica_soggetto) REFERENCES ISCRITTO_T_ANAGRAFICA_SOG (id_anagrafica_soggetto);



ALTER TABLE ISCRITTO_T_INDIRIZZO_RES
	ADD FOREIGN KEY (id_comune) REFERENCES ISCRITTO_T_COMUNE (id_comune) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_ISEE
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_PUNTEGGIO
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_PUNTEGGIO
	ADD FOREIGN KEY (id_condizione_punteggio) REFERENCES ISCRITTO_D_CONDIZIONE_PUN (id_condizione_punteggio);



ALTER TABLE ISCRITTO_T_SCUOLA
	ADD FOREIGN KEY (cod_ordine_scuola) REFERENCES ISCRITTO_D_ORDINE_SCUOLA (cod_ordine_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_SERVIZI_SOC
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_STUDENTE
	ADD FOREIGN KEY (id_condizione_occupazionale) REFERENCES ISCRITTO_T_CONDIZIONE_OCC (id_condizione_occupazionale);



ALTER TABLE ISCRITTO_T_TRASFERIMENTO
	ADD FOREIGN KEY (id_domanda_iscrizione) REFERENCES ISCRITTO_T_DOMANDA_ISC (id_domanda_iscrizione);



ALTER TABLE ISCRITTO_T_UTENTE
	ADD FOREIGN KEY (id_scuola) REFERENCES ISCRITTO_T_SCUOLA (id_scuola) ON DELETE SET NULL;



ALTER TABLE ISCRITTO_T_UTENTE
	ADD FOREIGN KEY (id_profilo) REFERENCES ISCRITTO_D_PROFILO (id_profilo) ON DELETE SET NULL;



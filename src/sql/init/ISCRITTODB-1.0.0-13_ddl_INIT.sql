CREATE OR REPLACE
FUNCTION iscritto.GetIdCondizioneOccupazionale ( IN  pIdDomandaIscrizione        INTEGER
                                      , IN  pCodTipoSoggetto            VARCHAR(20)
                                      , IN  pCodTipCondOccupazionale    VARCHAR(20)
                                      ) RETURNS INTEGER AS
$BODY$
DECLARE
  nIdCondizioneOccupazionale  iscritto.iscritto_t_condizione_occ.id_condizione_occupazionale%TYPE;
  nFound  NUMERIC(1);
BEGIN
  SELECT        condOcc.id_condizione_occupazionale     id_condizione_occupazionale
    INTO STRICT nIdCondizioneOccupazionale
    FROM        iscritto_t_anagrafica_sog   anSog
              , iscritto_r_soggetto_rel     sogRel
              , iscritto_d_tipo_sog         tipSog
              , iscritto_t_condizione_occ   condOcc
              , iscritto_d_tip_con_occ      tipCondOcc
    WHERE     anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND     sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      AND     anSog.id_anagrafica_soggetto = condOcc.id_anagrafica_soggetto
      AND     condOcc.id_tip_cond_occupazionale = tipCondOcc.id_tip_cond_occupazionale
      AND     anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND     tipSog.cod_tipo_soggetto = pCodTipoSoggetto
      AND     tipCondOcc.cod_tip_cond_occupazionale = pCodTipCondOccupazionale;
  RETURN nIdCondizioneOccupazionale;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION iscritto.GetFlagResidenzaNAO  ( IN  pIdDomandaIscrizione  INTEGER
                              , IN  pCodTipoSoggetto      VARCHAR(20)
                              ) RETURNS VARCHAR(1) AS
$BODY$
DECLARE
  sFlagResidenzaNAO iscritto.iscritto_t_anagrafica_sog.fl_residenza_nao%TYPE;
BEGIN
  SELECT  anSog.fl_residenza_nao
    INTO  sFlagResidenzaNAO
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipSog
    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto = pCodTipoSoggetto;
  RETURN sFlagResidenzaNAO;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION iscritto.GetFlagIstruita  ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS VARCHAR(1) AS
$BODY$
DECLARE
  sFlagIstruita   iscritto.iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
BEGIN
  SELECT  fl_istruita
    INTO  sFlagIstruita
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione;
  RETURN sFlagIstruita;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION iscritto.GetDescComuneDipendente  ( pIdCondizioneOccupazionale  INTEGER
                                  ) RETURNS VARCHAR AS
$BODY$
DECLARE
  sComuneLavoro   iscritto.iscritto_t_dipendente.comune_lavoro%TYPE;
BEGIN
  -- Verifico se il minore esiste ed è residente a Torino
  SELECT  UPPER(TRIM(comune_lavoro))
    INTO  sComuneLavoro
    FROM  iscritto_t_dipendente
    WHERE id_condizione_occupazionale = pIdCondizioneOccupazionale;
  RETURN sComuneLavoro;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION iscritto.GetDescComuneAutonomo  ( pIdCondizioneOccupazionale  INTEGER
                                ) RETURNS VARCHAR AS
$BODY$
DECLARE
  sComuneLavoro   iscritto.iscritto_t_autonomo.comune_lavoro%TYPE;
BEGIN
  -- Verifico se il minore esiste ed è residente a Torino
  SELECT  UPPER(TRIM(comune_lavoro))
    INTO  sComuneLavoro
    FROM  iscritto_t_autonomo
    WHERE id_condizione_occupazionale = pIdCondizioneOccupazionale;
  RETURN sComuneLavoro;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
  Legge la data di nascita di un soggetto
*/
CREATE OR REPLACE
FUNCTION iscritto.GetDataNascita ( pIdDomandaIscrizione  INTEGER
                        , pCodTipoSoggetto      VARCHAR(20)
                        ) RETURNS DATE AS
$BODY$
DECLARE
  dDataNascita  iscritto.iscritto_t_anagrafica_sog.data_nascita%TYPE;
BEGIN
  SELECT  anSog.data_nascita
    INTO  dDataNascita
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipSog
    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto = pCodTipoSoggetto;
  RETURN dDataNascita;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
  Legge l'anno scolastico corrente
*/
CREATE OR REPLACE
FUNCTION iscritto.GetAnnoScolastico() RETURNS NUMERIC(4) AS
$BODY$
DECLARE
  nAnno NUMERIC(4);
BEGIN
  SELECT  EXTRACT(YEAR FROM annoSco.data_da)
    INTO  nAnno
    FROM  iscritto_t_anagrafica_gra   anaGra
        , iscritto_t_anno_sco         annoSco
    WHERE anaGra.id_anno_scolastico = annoSco.id_anno_scolastico
      AND CURRENT_DATE BETWEEN anaGra.dt_inizio_iscr AND anaGra.dt_fine_iscr;
  RETURN nAnno;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION iscritto.EsisteSoggettoInTorino ( IN  pIdDomandaIscrizione  INTEGER
                                , IN  pCodTipoSoggetto      VARCHAR(20)
                                ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  bFound  BOOLEAN;
BEGIN
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  bFound
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_t_indirizzo_res    indRes
        , iscritto_d_tipo_sog         tipSog
    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      AND anSog.id_anagrafica_soggetto = indRes.id_anagrafica_soggetto
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto = pCodTipoSoggetto
      AND indRes.id_comune = 8207;    -- Torino
  RETURN bFound;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
  La procedura calcola il punteggio in base alle condizioni di punteggio legate alla domanda e alla singola scuola
  della domanda ed esegue un update sul campo ISCRITTO_R_PUNTEGGIO_SCU.punteggio con il valore calcolato.

  Parametri di in put:  l’id_domanda_isc

    1.	Se il flag ISCRITTO_T_DOMANDA_ISC.fl_istruita = N allora la procedura termina con un errore
    2.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per id_domanda_isc, per d_fine_validita= NULL e per fl_valida <> N
    3.	Eseguire una query sulla tabella ISCRITTO_R_SCUOLA_PRE filtrando per id_domanda_isc per ricavare tutti gli id_scuola legati alla domanda.
    4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio
        e sysdate tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
    5.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_SCU con id_punteggio dalla query precedente
        e per tutti gli id_scuola trovati al punto 3 e sysdate tra dt_inizio_validita e dt_fine_validita .
        Questo per ricavare gli eventuali punteggi specifici per ogni scuola della condizione di punteggio presa in considerazione.
    6.	Moltiplicare per tutte le condizioni di punteggio valide della domanda ( 2 ) il valore contenuto
        nel campo ISCRITTO_R_PUNTEGGIO_DOM.ricorrenza per il punteggio generico ( 4 ) o l’eventuale punteggio specifico ( 5 )
        e sommare i risultati per ogni scuola.
          Unica eccezione riguarda la condizione di punteggio che ha codice ‘CF_FRA_FRE’.
          Se per questa condizione il valore nel campo ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 1 ( FREQ ) allora il punteggio
          di questa condizione deve essere preso in considerazione solo per la scuola di prima scelta ( ISCRITTO_R_SCUOLA_PRE.POSIZIONE=1 ).
    7.	Eseguire l’update del campo ISCRITTO_R_SCUOLA_PRE.punteggio con il valore calcolato al punto precedente per ogni singola scuola della domanda.
*/
CREATE OR REPLACE
FUNCTION iscritto.CalcolaPunteggio ( pIdDomandaIscrizione  INTEGER
                          ) RETURNS SMALLINT AS
$BODY$
DECLARE
  nIdPunteggio    iscritto.iscritto_t_punteggio.id_punteggio%TYPE;
  nPunti          iscritto.iscritto_t_punteggio.punti%TYPE;
  nPuntiScuola    iscritto.iscritto_r_punteggio_scu.punti_scuola%TYPE;
  nPunteggio      iscritto.iscritto_r_scuola_pre.punteggio%TYPE;
  bDaConsiderare  BOOLEAN;
  bFound          BOOLEAN;
  -----
  condiz  RECORD;
  scuola  RECORD;
BEGIN
  IF GetFlagIstruita(pIdDomandaIscrizione) = 'N' THEN
    RAISE 'Istruttoria = N';
  END IF;
  -------
  -- Ciclo per ogni scuola della domanda di iscrizione
  FOR scuola IN ( SELECT  id_scuola
                        , posizione
                    FROM  iscritto_r_scuola_pre
                    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
                    ORDER BY posizione
                )
  LOOP
    nPunteggio = 0;
    -- Ciclo per tutte le condizioni associate alla domanda
    FOR condiz IN SELECT  puntDom.id_condizione_punteggio   id_condizione_punteggio
                        , puntDom.ricorrenza                ricorrenza
                        , punt.id_punteggio                 id_punteggio
                        , punt.punti                        punti
                        , codPun.cod_condizione             cod_condizione
                      FROM  iscritto_r_punteggio_dom    puntDom
                          , iscritto_t_punteggio        punt
                          , iscritto_d_condizione_pun   codPun
                      WHERE puntDom.id_condizione_punteggio = punt.id_condizione_punteggio
                        AND puntDom.id_condizione_punteggio = codPun.id_condizione_punteggio
                        AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
                        AND COALESCE(puntDom.fl_valida,' ') <> 'N'
                        AND puntDom.dt_fine_validita IS NULL
                        AND CURRENT_DATE BETWEEN punt.dt_inizio_validita AND COALESCE(punt.dt_fine_validita,DATE '9999-12-31')
    LOOP
      bDaConsiderare = TRUE;
      IF condiz.cod_condizione = 'CF_FRA_FRE' THEN
        -- Per questa condizione il punteggio non è da considerare se trovo un fratello frequentante
        SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
          INTO  bFound
          FROM  iscritto_t_fratello_fre   fraFre
              , iscritto_d_tipo_fra       tipFra
          WHERE fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
            AND fraFre.id_domanda_iscrizione = pIdDomandaIscrizione
            AND tipFra.cod_tipo_fratello = 'FREQ';
        IF bFound THEN
          IF scuola.posizione <> 1 THEN
            bDaConsiderare = FALSE;
          END IF;
        END IF;
      END IF;
      -------
      IF bDaConsiderare THEN
        BEGIN
          -- Verifico se la scuola ha un punteggio specifico associato alla condizione
          SELECT        punti_scuola
            INTO STRICT nPuntiScuola
            FROM        iscritto_r_punteggio_scu
            WHERE       id_punteggio = condiz.id_punteggio
              AND       id_scuola = scuola.id_scuola
              AND       CURRENT_DATE BETWEEN dt_inizio_validita AND COALESCE(dt_fine_validita,DATE '9999-12-31');
          nPunteggio = nPunteggio + nPuntiScuola*condiz.ricorrenza;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            nPunteggio = nPunteggio + condiz.punti*condiz.ricorrenza;
        END;
      END IF;
    END LOOP;
    ------
    -- Aggiorno il punteggio calcolato
    UPDATE  iscritto_r_scuola_pre
      SET punteggio = nPunteggio
      WHERE id_domanda_iscrizione = pIdDomandaIscrizione
        AND id_scuola = scuola.id_scuola;
  END LOOP;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
  Legge la data di ultima attribuzione delle condizioni di punteggio
*/
CREATE OR REPLACE
FUNCTION GetDataUltimaAttribuzione() RETURNS DATE AS
$BODY$
DECLARE
  dDataUltimaAttribuzione DATE;
BEGIN
  SELECT  dt_ult_attribuzione_con
    INTO  dDataUltimaAttribuzione
    FROM  iscritto_t_parametro;
  RETURN dDataUltimaAttribuzione;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
  Setta la data di ultima attribuzione delle condizioni di punteggio
*/
CREATE OR REPLACE
FUNCTION SetDataUltimaAttribuzione  ( pDataUltimaAttribuzione DATE
                                    ) RETURNS INTEGER AS
$BODY$
DECLARE
BEGIN
  UPDATE  iscritto_t_parametro
    SET dt_ult_attribuzione_con = pDataUltimaAttribuzione;
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
Attività demandata ad un batch notturno giornaliero che prende in considerazione tutte le domande arrivate nel giorno ( stato INVIATA ) oppure un range di date:
ISCRITTO_T_DOMANDA_ISC.data_consegna= sysdate  se il range di date è NULL altrimenti
Data_da <= ISCRITTO_T_DOMANDA_ISC.data_consegna <= data_a
La domanda selezionata non deve avere già dei record inseriti nella tabella ISCRITTO_R_PUNTEGGIO_DOM.
Il batch deve attribuire le condizioni di punteggio cioè inserire uno o più record nella tabella ISCRITTO_R_PUNTEGGIO_DOM con:
id_domanda_iscrizione= id_domanda
dt_inizio_validita = sysdate
dt_fine_validita= NULL
id_utente=NULL
note=NULL
ricorrenza= 1 maggiore di 1 in base al numero di volte che ricorre la condizione di punteggio 
id_condizione_punteggio= uno degli id_condizione_punteggio delle condizioni punteggio elencati successivamente
fl_valida = NULL o ‘S’ in base a:
•	ISCRITTO_D_CONDIZIONE_PUN.fl_istruttoria=’N’  fl_valida =’S’
•	ISCRITTO_D_CONDIZIONE_PUN.fl_istruttoria <>’N’  fl_valida =NULL
*/
CREATE OR REPLACE
FUNCTION iscritto.AttribuisciCondizioni  ( pDataDa DATE
                                , pDataA  DATE
                                ) RETURNS SMALLINT AS
$BODY$
DECLARE
  domanda                 RECORD;
  condPunt                RECORD;
  rec                     RECORD;
  nIdDomandaIscrizione    iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
  nIdCondizionePunteggio  iscritto_d_condizione_pun.id_condizione_punteggio%TYPE;
  sCodCondizione          iscritto_d_condizione_pun.cod_condizione%TYPE;
  dDataDa                 DATE;
  dDataA                  DATE;
  nRetCode                INTEGER;
BEGIN
  dDataDa = pDataDa;
  dDataA = pDataA;
  IF dDataDa IS NULL OR dDataA IS NULL THEN
    dDataDa = GetDataUltimaAttribuzione() + INTERVAL '1 day';
    IF dDataDa IS NULL THEN
      dDataDa = CURRENT_DATE - INTERVAL '1 day';
    END IF;
    dDataA = CURRENT_DATE - INTERVAL '1 day';
  END IF;
  -- Ciclo sulle domande che non hanno ancora nessun record nella tabella ISCRITTO_R_PUNTEGGIO_DOM
  FOR domanda IN  SELECT  id_domanda_iscrizione
                    FROM  iscritto_t_domanda_isc
                    WHERE id_stato_dom = 2  -- Domande in stato "INVIATA"
                      AND DATE_TRUNC('day',data_consegna) BETWEEN dDataDa AND dDataA  -- Per range (se valorizzato) oppure in data di oggi
                      AND id_domanda_iscrizione NOT IN  ( SELECT  id_domanda_iscrizione
                                                            FROM  iscritto_r_punteggio_dom
                                                        )
  LOOP
    nIdDomandaIscrizione = domanda.id_domanda_iscrizione;
    -- Scorro tutte le possibili condizioni di punteggio
    FOR condPunt IN SELECT  id_condizione_punteggio   id_condizione_punteggio
                          , cod_condizione            cod_condizione
                      FROM  iscritto_d_condizione_pun
                      ORDER BY  id_condizione_punteggio
    LOOP
      sCodCondizione = condPunt.cod_condizione;
      SELECT  *
        INTO  rec
        FROM  Punteggio(sCodCondizione, nIdDomandaIscrizione);
      IF rec.pRicorrenza > 0 THEN
        INSERT INTO iscritto_r_punteggio_dom
                    ( id_domanda_iscrizione
                    , id_condizione_punteggio
                    , ricorrenza
                    , fl_valida
                    , dt_inizio_validita
                    )
          VALUES  ( domanda.id_domanda_iscrizione
                  , condPunt.id_condizione_punteggio
                  , rec.pRicorrenza
                  , rec.pFlagValida
                  , CURRENT_DATE
                  );
      END IF;
    END LOOP;
  END LOOP;
  -------
  nRetCode = SetDataUltimaAttribuzione(dDataA);
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 20
17.	Trasferimento da nido della città (TR_TRA_NID).
  Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_trasferimento=’S’
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_TR_TRA_NID ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
      AND fl_trasferimento = 'S';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 1
1.	RESIDENZA ( 3 Possibilità in alternativa )
  Occorre individuare i due valore di id_anagrafica_sog dalla tabella ISCRITTO_R_SOGGETTO_REL accedendo per id_domanda_iscrizione
  e per id_tipo_soggetto=1 (MIN) e 2 (SOG1) e 3 (SOG2) se presente.
    A.	Famiglie residenti a Torino ( RES_TO ). Il minore e il soggetto1 devono essere residenti a Torino.
      •	E’ soddisfatta questa condizione se accedendo alla tabella ISCRITTO_T_INDIRIZZO_RES con i valori di id_anagrafica_sog
        il campo ISCRITTO_T_INDIRIZZO_RES.id_comune= 8207 ( TORINO ) per entrambi per il MIN e almeno uno tra il SOG1 e il SOG2.
        Se per questo soggetti il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ allora il flag fl_valida dovrà essere impostato a ‘S’.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_RES_TO ( IN  pIdDomandaIscrizione  INTEGER
                          , OUT pRicorrenza           INTEGER
                          , OUT pFlagResidenzaNAO     VARCHAR(1)
                          ) AS
$BODY$
DECLARE
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = 'N';
  -- Verifico se il minore esiste ed è residente a Torino
  IF EsisteSoggettoInTorino(pIdDomandaIscrizione, 'MIN') THEN
    pFlagResidenzaNAO = GetFlagResidenzaNAO(pIdDomandaIscrizione, 'MIN');
    -- Verifico se anche il soggetto 1 esiste ed è residente a Torino
    IF EsisteSoggettoInTorino(pIdDomandaIscrizione, 'SOG1') THEN
      IF pFlagResidenzaNAO = 'S' THEN
        pFlagResidenzaNAO = GetFlagResidenzaNAO(pIdDomandaIscrizione, 'SOG1');
      END IF;
      pRicorrenza = 1;
    ELSE
    -- Se non esiste il soggetto 1 provo con il soggetto 1
      IF EsisteSoggettoInTorino(pIdDomandaIscrizione, 'SOG2') THEN
        IF pFlagResidenzaNAO = 'S' THEN
          pFlagResidenzaNAO = GetFlagResidenzaNAO(pIdDomandaIscrizione, 'SOG2');
        END IF;
        pRicorrenza = 1;
      END IF;
    END IF;
  END IF;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 22
B.	Famiglie prossimamente residenti a Torino ( RES_TO_FUT ).
    E’ soddisfatta questa condizione se la condizione A non è verificata ed  esiste un record nella tabella ISCRITTO_T_CAMBIO_RES
    per la domanda presa in considerazione.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_RES_TO_FUT ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
  rec         RECORD;
BEGIN
  -- La condizione RES_TO non deve essere verificata
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    nRicorrenza = 0;
    RETURN nRicorrenza;
  END IF;
  ---------
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_cambio_res
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione;
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 2
1.	RESIDENZA ( 3 Possibilità in alternativa )
  B.	Famiglie non residenti a Torino in cui almeno un genitore presta attività lavorativa in città ( RES_NOTO_LAV). 
    La condizione A e la condizione B non è verificata e il soggetto 1 o il soggetto 2 o entrambi lavorano a Torino.
      •	Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC tramite gli id_anagrafica_sog dei soggetti con id_tipo_soggetto SOG1
        e se esiste con SOG2 per individuare la tipologia di condizione occupazionale.
      •	Se id_tip_condizione_occ corrisponde ‘DIP’ o ‘AUT’ di almeno uno dei due verificare che nel campo comune_lavoro
        della tabella ISCRITTO_T_DIPENDENTE o ISCRITTO_T_AUTONOMO in base alla tipologia di occupazione sia valorizzato a ‘TORINO’ (no case sensitive).
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_RES_NOTO_LAV ( IN  pIdDomandaIscrizione  INTEGER
                                ) RETURNS INTEGER AS
$BODY$
DECLARE
  rec                         RECORD;
  nRicorrenza                 INTEGER;
  sCodTipCondOccupazionale    iscritto.iscritto_d_tip_con_occ.cod_tip_cond_occupazionale%TYPE;
  nIdCondizioneOccupazionale  iscritto.iscritto_t_condizione_occ.id_condizione_occupazionale%TYPE;
  bTentareSoggetto2           BOOLEAN;
BEGIN
  -- La condizione RES_TO non deve essere verificata
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    RETURN 0;
  END IF;
  ---------
  IF Punteggio_RES_TO_FUT(pIdDomandaIscrizione) > 0 THEN
    RETURN 0;
  END IF;
  ---------
  bTentareSoggetto2 = FALSE;
  -- Per Soggetto 1
  sCodTipCondOccupazionale = 'DIP';
  nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG1', sCodTipCondOccupazionale);
  IF nIdCondizioneOccupazionale IS NULL THEN
    sCodTipCondOccupazionale = 'AUT';
    nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG1', sCodTipCondOccupazionale);
    IF nIdCondizioneOccupazionale IS NULL THEN
      bTentareSoggetto2 = TRUE;
    ELSE
      -- Soggetto 1 - Lavoratore autonomo
      IF GetDescComuneAutonomo(nIdCondizioneOccupazionale) = 'TORINO' THEN
        -- Condizione verificata
        nRicorrenza = 1;
        RETURN nRicorrenza;
      ELSE
        bTentareSoggetto2 = TRUE;
      END IF;
    END IF;
  ELSE
    -- Soggetto 1 - Dipendente
    IF GetDescComuneDipendente(nIdCondizioneOccupazionale) = 'TORINO' THEN
      -- Condizione verificata
      nRicorrenza = 1;
      RETURN nRicorrenza;
    ELSE
      bTentareSoggetto2 = TRUE;
    END IF;
  END IF;
  --------
  IF bTentareSoggetto2 THEN
    sCodTipCondOccupazionale = 'DIP';
    nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG2', sCodTipCondOccupazionale);
    IF nIdCondizioneOccupazionale IS NULL THEN
      sCodTipCondOccupazionale = 'AUT';
      nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG2', sCodTipCondOccupazionale);
      IF nIdCondizioneOccupazionale IS NOT NULL THEN
        -- Soggetto 2 - Lavoratore autonomo
        IF GetDescComuneAutonomo(nIdCondizioneOccupazionale) = 'TORINO' THEN
          -- Condizione verificata
          nRicorrenza = 1;
          RETURN nRicorrenza;
        END IF;
      END IF;
    ELSE
      -- Soggetto 2 - Dipendente
      IF GetDescComuneDipendente(nIdCondizioneOccupazionale) = 'TORINO' THEN
        -- Condizione verificata
        nRicorrenza = 1;
        RETURN nRicorrenza;
      END IF;
    END IF;
  END IF;
  -------
  nRicorrenza = 0;
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 3
1.	RESIDENZA ( 3 Possibilità in alternativa )
  C.	Famiglie non residenti a Torino ( RES_NOTO ). 
    E’ soddisfatta questa condizione se la A la B e la C non sono vere.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_RES_NOTO ( IN  pIdDomandaIscrizione  INTEGER
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
  rec RECORD;
BEGIN
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    RETURN 0;
  END IF;
  -------
  IF Punteggio_RES_TO_FUT(pIdDomandaIscrizione) > 0 THEN
    RETURN 0;
  END IF;
  -------
  IF Punteggio_RES_NOTO_LAV(pIdDomandaIscrizione) > 0 THEN
    RETURN 0;
  END IF;
  -------
  RETURN 1;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 21
18.	Condizione di precedenza ( PAR_ISEE )
  Attribuzione della condizione di precedenza se ISCRITTO_T_DOMANDA_ISC.fl_isee=’S’
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_PAR_ISEE ( IN  pIdDomandaIscrizione  INTEGER
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
      AND fl_isee = 'S';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 5
4.	Minore in situazione di disagio sociale ( PA_SOC ).
    Assegnazione se ISCRITTO_T_DOMANDA_ISC.fl_servizi_sociali=’S’ esiste un record nella tabella ISCRITTO_T_SERVIZI_SOC
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_PA_SOC ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  -- Verifico se esiste un minore con fl_servizi_sociali=’S’
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc  dom
        , iscritto_t_servizi_soc  servSoc
    WHERE dom.id_domanda_iscrizione = servSoc.id_domanda_iscrizione
      AND dom.id_domanda_iscrizione = pIdDomandaIscrizione;
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 6
3.	Gravi problemi di salute del minore o uno dei componenti il nucleo ( PA_PRB_SAL ). Assegnazione solo se presente l’allegato. 
  Per ogni id_anagrafica_soggetto della domanda verificare se esiste almeno un record
  con ISCRITTO_T_ALLEGATO.id_tipo_allegato=2 (SAL) a parità di id_anagrafica_sog.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_PA_PRB_SAL ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
  soggetto    RECORD;
  nFound      NUMERIC(1);
BEGIN
  nRicorrenza = 0;
  -- Per ogni soggetto della domanda...
  FOR soggetto IN SELECT  id_anagrafica_soggetto
                    FROM  iscritto_t_anagrafica_sog
                    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
  LOOP
    -- Verifico se esiste almeno un record con allegato di tipo SAL
    SELECT  nRicorrenza + COUNT(1)
      INTO  nRicorrenza
      FROM  iscritto_t_condizione_san   condSan
          , iscritto_t_allegato         alleg
          , iscritto_d_tipo_all         tipAlleg
      WHERE condSan.id_anagrafica_soggetto = soggetto.id_anagrafica_soggetto
        AND condSan.id_anagrafica_soggetto = alleg.id_anagrafica_soggetto
        AND alleg.id_tipo_allegato = tipAlleg.id_tipo_allegato
        AND tipAlleg.cod_tipo_allegato = 'SAL';
  END LOOP;
  -------
  IF nRicorrenza > 1 THEN
    nRicorrenza = 1;
  END IF;
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 4
2.	Minore con disabilità certificata ( PA_DIS ). Assegnazione solo se presente l’allegato.
  Se per il soggetto con ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto=1 (MIN)
  ed esiste un record con ISCRITTO_T_ALLEGATO.id_tipo_allegato=3 (DIS) per lo stesso id_anagrafica_sog.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_PA_DIS ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  -- Verifico se esiste un minore con fl_disabilita=’S’ e con un allegato di tipo DIS
  SELECT  CASE WHEN COUNT(1) = 0 THEN 0 ELSE 1 END
    INTO  nRicorrenza
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipSog
        , iscritto_t_condizione_san   condSan
        , iscritto_t_allegato         alleg
        , iscritto_d_tipo_all         tipAlleg
    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      AND anSog.id_anagrafica_soggetto = condSan.id_anagrafica_soggetto
      AND anSog.id_anagrafica_soggetto = alleg.id_anagrafica_soggetto
      AND alleg.id_tipo_allegato = tipAlleg.id_tipo_allegato
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto = 'MIN'  -- Minore
      AND tipAlleg.cod_tipo_allegato = 'DIS';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 19
16.	Ogni permanenza in lista d’attesa al termine dei precedenti anni educativi (LA_PER).
  Accedere alla tabella ISCRITTO_T_LISTA_ATTESA tramite il codice fiscale del soggetto della domanda che ha ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto=1 (MIN)
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_LA_PER ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipSog
        , iscritto_t_lista_attesa     listAtt
    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      AND anSog.codice_fiscale = listAtt.codice_fiscale
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto = 'MIN';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 7
5.	GENITORE SOLO ( 2 possibilità in alternativa )
  A.	Minore con unico genitore ( GEN_SOLO ).
    Attribuzione se per la domanda esiste un record nella tabella con ISCRITTO_T_GENITORE_SOLO.id_tipo_genitore_solo=’ GEN_DEC’ o ‘NUB_CEL_NO_RIC’ o ‘NO_RES_GEN’
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_GEN_SOLO ( IN  pIdDomandaIscrizione  INTEGER
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_genitore_solo  genSol
        , iscritto_d_genitore_sol   tipGenSol
    WHERE genSol.id_tipo_genitore_solo = tipGenSol.id_tipo_genitore_solo
      AND genSol.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipGenSol.cod_tipo_genitore_solo IN ( 'GEN_DEC', 'NUB_CEL_NO_RIC', 'NO_RES_GEN' );
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 8
5.	GENITORE SOLO ( 2 possibilità in alternativa )
  B.	Minore con genitori separati ( GEN_SEP ). 
  Attribuzione se per la domanda esiste un record nella tabella ISCRITTO_T_GENITORE_SOLO.id_tipo_genitore_solo=’ NUB_CEL_RIC’ o ‘DIV’ o ‘IST_SEP’ o ‘SEP’.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_GEN_SEP  ( IN  pIdDomandaIscrizione  INTEGER
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_genitore_solo  genSol
        , iscritto_d_genitore_sol   tipGenSol
    WHERE genSol.id_tipo_genitore_solo = tipGenSol.id_tipo_genitore_solo
      AND genSol.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipGenSol.cod_tipo_genitore_solo IN ( 'NUB_CEL_RIC', 'DIV', 'IST_SEP', 'SEP' );
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 18
15.	Genitore studente (CL_STU).
  Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda
  e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=5 (STU).
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CL_STU ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_t_condizione_occ   condOcc
        , iscritto_d_tip_con_occ      tipCondOcc
    WHERE anSog.id_anagrafica_soggetto = condOcc.id_anagrafica_soggetto
      AND condOcc.id_tip_cond_occupazionale = tipCondOcc.id_tip_cond_occupazionale
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipCondOcc.cod_tip_cond_occupazionale = 'STU';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 16
13.	Genitore non occupato che alla scadenza iscrizioni ha lavorato almeno 6 mesi nei precedenti 12 (CL_NON_OCC).
  Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda
  e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=4 (DIS_LAV).
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CL_NON_OCC ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_t_condizione_occ   condOcc
        , iscritto_d_tip_con_occ      tipCondOcc
    WHERE anSog.id_anagrafica_soggetto = condOcc.id_anagrafica_soggetto
      AND condOcc.id_tip_cond_occupazionale = tipCondOcc.id_tip_cond_occupazionale
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipCondOcc.cod_tip_cond_occupazionale = 'DIS_LAV';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 15
12.	Genitore lavoratore (CL_LAV)
  Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda
  e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=1 (DIP) o 2 (AUT).
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CL_LAV ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_t_condizione_occ   condOcc
        , iscritto_d_tip_con_occ      tipCondOcc
    WHERE anSog.id_anagrafica_soggetto = condOcc.id_anagrafica_soggetto
      AND condOcc.id_tip_cond_occupazionale = tipCondOcc.id_tip_cond_occupazionale
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipCondOcc.cod_tip_cond_occupazionale IN ( 'DIP', 'AUT' );
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 17
14.	Genitore disoccupato da almeno tre mesi (CL_DIS).
  Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda
  e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=3 (DIS) e per i record trovati verificare
  che la data ISCRITTO_T_DISOCCUPATO.dt_dichiarazione_disponibili sia più vecchia di 3 mesi rispetto alla data ISCRITTO_T_DOMANDA_ISC.data_consegna.
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati che soddisfano anche il controllo della data.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CL_DIS ( IN  pIdDomandaIscrizione    INTEGER
                          , OUT pRicorrenza             INTEGER
                          , OUT pDisoccupatoOltre3mesi  BOOLEAN
                          ) AS
$BODY$
DECLARE
BEGIN
  SELECT  COUNT(1)
        , CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  pRicorrenza
        , pDisoccupatoOltre3mesi
    FROM  iscritto_t_domanda_isc      dom
        , iscritto_t_anagrafica_sog   anSog
        , iscritto_t_condizione_occ   condOcc
        , iscritto_d_tip_con_occ      tipCondOcc
        , iscritto_t_disoccupato      dis
    WHERE dom.id_domanda_iscrizione = anSog.id_domanda_iscrizione
      AND anSog.id_anagrafica_soggetto = condOcc.id_anagrafica_soggetto
      AND condOcc.id_tip_cond_occupazionale = tipCondOcc.id_tip_cond_occupazionale
      AND condOcc.id_condizione_occupazionale = dis.id_condizione_occupazionale
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipCondOcc.cod_tip_cond_occupazionale = 'DIS'
      AND dis.dt_dichiarazione_disponibili <= ( dom.data_consegna - INTERVAL '3 months' );
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 9
9.	Ogni figlio/a di età  tra 11 e 17 anni di cui un genitore coabitante abbia l’affidamento condiviso (CF_TRA_11_17_AFF_CON). 
  In questo caso si intende che il bambino/a deve avere un’età compresa tra gli 11 e i 17 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
  I soggetti a cui occorre effettuare il controllo dell’età sono:
    •	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 6 (AFF) 
    •	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CF_TRA_11_17_AFF_CON ( IN  pIdDomandaIscrizione  INTEGER
                                        ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza     INTEGER;
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  nRicorrenza = 0;
  nAnnoScolastico = GetAnnoScolastico();
  --------
  FOR soggetto IN SELECT  anSog.data_nascita      data_nascita
                        , anSog.fl_residenza_nao  fl_residenza_nao
                    FROM  iscritto_t_anagrafica_sog   anSog
                        , iscritto_r_soggetto_rel     sogRel
                        , iscritto_d_tipo_sog         tipSog
                        , iscritto_d_relazione_par    relPar
                    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                      AND anSog.id_rel_parentela = relPar.id_rel_parentela
                      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
                      AND tipSog.cod_tipo_soggetto = 'AFF'  -- Affido
  LOOP
    SELECT  *
      INTO  nEta
      FROM  EXTRACT(YEAR FROM AGE( GetUltimoGiornoAnno(nAnnoScolastico), soggetto.data_nascita ));
    IF nEta BETWEEN 11 AND 17 THEN
      nRicorrenza = nRicorrenza + 1;
    END IF;
  END LOOP;
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 8
8.	Ogni figlio/a di età  tra 11 e 17 anni (CF_TRA_11_17). 
  In questo caso si intende che il bambino/a deve avere un’età compresa tra gli 11 e i 17 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
  I soggetti a cui occorre effettuare il controllo dell’età sono:
    •	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 4 (CMP_NUC) o 7 (ALT_CMP) che hanno ISCRITTO_T_ANAGRAFICA_SOG.id_rel_parentela in 1 (FGL_RICH)
      o 2 (FGL_GEN) o 3 (FGL_COA) o 4 (MIN_AFF).
    •	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
    •	Se il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ per tutti i soggetti trovati allora il flag fl_valida dovrà essere impostato a ‘S’. 
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CF_TRA_11_17 ( IN  pIdDomandaIscrizione  INTEGER
                                , OUT pRicorrenza           INTEGER
                                , OUT pFlagResidenzaNAO     VARCHAR(1)
                                ) AS
$BODY$
DECLARE
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = NULL;
  nAnnoScolastico = GetAnnoScolastico();
  --------
  FOR soggetto IN SELECT  anSog.data_nascita                    data_nascita
                        , COALESCE(anSog.fl_residenza_nao,'N')  fl_residenza_nao
                    FROM  iscritto_t_anagrafica_sog   anSog
                        , iscritto_r_soggetto_rel     sogRel
                        , iscritto_d_tipo_sog         tipSog
                        , iscritto_d_relazione_par    relPar
                    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                      AND anSog.id_rel_parentela = relPar.id_rel_parentela
                      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
                      AND tipSog.cod_tipo_soggetto IN ( 'CMP_NUC', 'ALT_CMP' )                      -- "ALTRI SOGGETTI DEL NUCLEO" oppure "Altri componenti"
                      AND relPar.cod_parentela IN ( 'FGL_RICH', 'FGL_GEN', 'FGL_COA', 'MIN_AFF' )   -- "Figlio del richiedente" oppure "Figlio dell altro genitore" oppure "Figlio del coabitante non genitore" oppure "Minore in affidamento"
  LOOP
    SELECT  *
      INTO  nEta
      FROM  EXTRACT(YEAR FROM AGE( GetUltimoGiornoAnno(nAnnoScolastico), soggetto.data_nascita ));
    IF nEta BETWEEN 11 AND 17 THEN
      pRicorrenza = pRicorrenza + 1;
      IF pFlagResidenzaNAO IS NULL THEN
        pFlagResidenzaNAO = soggetto.fl_residenza_nao;
      ELSIF soggetto.fl_residenza_nao <> 'S' THEN
        pFlagResidenzaNAO = soggetto.fl_residenza_nao;
      END IF;
    END IF;
  END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 9
7.	Ogni figlio/a fino a 10 anni di età di cui un genitore coabitante abbia l’affidamento condiviso (CF_INF_11_AFF_CON). 
  In questo caso si intende che il bambino/a deve avere un’età inferiore a 11 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
  I soggetti a cui occorre effettuare il controllo dell’età sono:
    •	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 6 (AFF) 
    •	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CF_INF_11_AFF_CON  ( IN  pIdDomandaIscrizione  INTEGER
                                      ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza     INTEGER;
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  nRicorrenza = 0;
  nAnnoScolastico = GetAnnoScolastico();
  --------
  FOR soggetto IN SELECT  anSog.data_nascita      data_nascita
                        , anSog.fl_residenza_nao  fl_residenza_nao
                    FROM  iscritto_t_anagrafica_sog   anSog
                        , iscritto_r_soggetto_rel     sogRel
                        , iscritto_d_tipo_sog         tipSog
                        , iscritto_d_relazione_par    relPar
                    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                      AND anSog.id_rel_parentela = relPar.id_rel_parentela
                      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
                      AND tipSog.cod_tipo_soggetto = 'AFF'  -- Affido
  LOOP
    SELECT  *
      INTO  nEta
      FROM  EXTRACT(YEAR FROM AGE( GetUltimoGiornoAnno(nAnnoScolastico), soggetto.data_nascita ));
    IF nEta < 11 THEN
      nRicorrenza = nRicorrenza + 1;
    END IF;
  END LOOP;
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 9
6.	Ogni figlio/a fino a 10 anni di età ( CF_INF_11 ). 
  In questo caso si intende che il bambino/a deve avere un’età inferiore a 11 anni al 31/12 dell’anno scolastico di riferimento.
  L’anno scolastico di riferimento si ricava selezionando il record dalla tabella ISCRITTO_T_ANAGRAFICA_GRA in cui la data di sistema
  è compresa tra la data dt_inizio_iscrizioni e la data dt_fine_iscr per recuperare l’id_anno_scolastico.
  Con l’id_anno_scolastico si accede alla tabella ISCRITTO_T_ANNO_SCO per recuperare l’anno della data data_da. Esempio:
  se la data_da= ‘01/09/2018’  il bambino deve avere un’età inferiore a 11 anni alla data del 31/12/2018.
  I soggetti a cui occorre effettuare il controllo dell’età sono:
    •	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 4 (CMP_NUC) o 7 (ALT_CMP) che hanno ISCRITTO_T_ANAGRAFICA_SOG.id_rel_parentela in 1 (FGL_RICH)
      o 2 (FGL_GEN) o 3 (FGL_COA) o 4 (MIN_AFF).
    •	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
    •	Se il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ per tutti i soggetti trovati allora il flag fl_valida dovrà essere impostato a ‘S’.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CF_INF_11  ( IN  pIdDomandaIscrizione  INTEGER
                              , OUT pRicorrenza           INTEGER
                              , OUT pFlagResidenzaNAO     VARCHAR(1)
                              ) AS
$BODY$
DECLARE
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = NULL;
  nAnnoScolastico = GetAnnoScolastico();
  --------
  FOR soggetto IN SELECT  anSog.data_nascita                    data_nascita
                        , COALESCE(anSog.fl_residenza_nao,'N')  fl_residenza_nao
                    FROM  iscritto_t_anagrafica_sog   anSog
                        , iscritto_r_soggetto_rel     sogRel
                        , iscritto_d_tipo_sog         tipSog
                        , iscritto_d_relazione_par    relPar
                    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                      AND anSog.id_rel_parentela = relPar.id_rel_parentela
                      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
                      AND tipSog.cod_tipo_soggetto IN ( 'CMP_NUC', 'ALT_CMP' )                      -- "ALTRI SOGGETTI DEL NUCLEO" oppure "Altri componenti"
                      AND relPar.cod_parentela IN ( 'FGL_RICH', 'FGL_GEN', 'FGL_COA', 'MIN_AFF' )   -- "Figlio del richiedente" oppure "Figlio dell altro genitore" oppure "Figlio del coabitante non genitore" oppure "Minore in affidamento"
  LOOP
    SELECT  *
      INTO  nEta
      FROM  EXTRACT(YEAR FROM AGE( GetUltimoGiornoAnno(nAnnoScolastico), soggetto.data_nascita ));
    IF nEta < 11 THEN
      pRicorrenza = pRicorrenza + 1;
      IF pFlagResidenzaNAO IS NULL THEN
        pFlagResidenzaNAO = soggetto.fl_residenza_nao;
      ELSIF soggetto.fl_residenza_nao <> 'S' THEN
        pFlagResidenzaNAO = soggetto.fl_residenza_nao;
      END IF;
    END IF;
  END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 12
11.	Stato di gravidanza della madre (CF_GRA).
  Attribuzione della condizione di punteggio se esiste un soggetto della domanda
  se c’è l’allegato cioè esiste un record con ISCRITTO_T_ALLEGATO.id_tipo_allegato=1 (GRA) per lo stesso id_anagrafica_sog.
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CF_GRA ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  CASE WHEN COUNT(1) = 0 THEN 0 ELSE 1 END
    INTO  nRicorrenza
    FROM  iscritto_t_anagrafica_sog   anSog
        , iscritto_t_condizione_san   condSan
        , iscritto_t_allegato         alleg
        , iscritto_d_tipo_all         tipAlleg
    WHERE anSog.id_anagrafica_soggetto = condSan.id_anagrafica_soggetto
      AND anSog.id_anagrafica_soggetto = alleg.id_anagrafica_soggetto
      AND alleg.id_tipo_allegato = tipAlleg.id_tipo_allegato
      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipAlleg.cod_tipo_allegato = 'GRA';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 11
10.	Presenza di fratelli/sorelle frequentanti o iscrivendi lo stesso nido (CF_FRA_FRE).
  Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_fratello_freq=’S’
*/
CREATE OR REPLACE
FUNCTION iscritto.Punteggio_CF_FRA_FRE ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
      AND fl_fratello_freq = 'S';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION iscritto.Punteggio  ( IN  pCodCondizione        VARCHAR(20)
                    , IN  pIdDomandaIscrizione  INTEGER
                    , OUT pRicorrenza           INTEGER
                    , OUT pFlagValida           VARCHAR(1)
                    ) AS
$BODY$
DECLARE
  rec RECORD;
BEGIN
  pRicorrenza = 0;
  -------
  SELECT  CASE WHEN fl_istruttoria = 'N' THEN 'S' ELSE NULL END
    INTO  pFlagValida
    FROM  iscritto_d_condizione_pun
    WHERE cod_condizione = pCodCondizione;
  -------
  IF pCodCondizione = 'RES_TO' THEN
    SELECT  *
      INTO  rec
      FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
    pRicorrenza = rec.pRicorrenza;
    IF rec.pFlagResidenzaNAO = 'S' THEN
      pFlagValida = 'S';
    END IF;
  ELSIF pCodCondizione =  'RES_TO_FUT' THEN
    pRicorrenza = Punteggio_RES_TO_FUT(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'RES_NOTO_LAV' THEN
    pRicorrenza = Punteggio_RES_NOTO_LAV(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'RES_NOTO' THEN
    pRicorrenza = Punteggio_RES_NOTO(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'PA_DIS' THEN
    pRicorrenza = Punteggio_PA_DIS(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'PA_SOC' THEN
    pRicorrenza = Punteggio_PA_SOC(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'PA_PRB_SAL' THEN
    pRicorrenza = Punteggio_PA_PRB_SAL(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'GEN_SOLO' THEN
    pRicorrenza = Punteggio_GEN_SOLO(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'GEN_SEP' THEN
    pRicorrenza = Punteggio_GEN_SEP(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'CF_INF_11' THEN
    SELECT  *
      INTO  rec
      FROM  Punteggio_CF_INF_11(pIdDomandaIscrizione);
    pRicorrenza = rec.pRicorrenza;
    IF rec.pFlagResidenzaNAO = 'S' THEN
      pFlagValida = 'S';
    END IF;
  ELSIF pCodCondizione = 'CF_TRA_11_17' THEN
    SELECT  *
      INTO  rec
      FROM  Punteggio_CF_TRA_11_17(pIdDomandaIscrizione);
    pRicorrenza = rec.pRicorrenza;
    IF rec.pFlagResidenzaNAO = 'S' THEN
      pFlagValida = 'S';
    END IF;
  ELSIF pCodCondizione = 'CF_FRA_FRE' THEN
    pRicorrenza = Punteggio_CF_FRA_FRE(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CF_GRA' THEN
    pRicorrenza = Punteggio_CF_GRA(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CF_INF_11_AFF_CON' THEN
    pRicorrenza = Punteggio_CF_INF_11_AFF_CON(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CF_TRA_11_17_AFF_CON' THEN
    pRicorrenza = Punteggio_CF_TRA_11_17_AFF_CON(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CL_LAV' THEN
    pRicorrenza = Punteggio_CL_LAV(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CL_NON_OCC' THEN
    pRicorrenza = Punteggio_CL_NON_OCC(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CL_DIS' THEN
    SELECT  *
      INTO  rec
      FROM  Punteggio_CL_DIS(pIdDomandaIscrizione);
    pRicorrenza = rec.pRicorrenza;
    IF rec.pDisoccupatoOltre3mesi THEN
      pFlagValida = 'N';
    END IF;
  ELSIF pCodCondizione = 'CL_STU' THEN
    pRicorrenza = Punteggio_CL_STU(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'LA_PER' THEN
    pRicorrenza = Punteggio_LA_PER(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'TR_TRA_NID' THEN
    pRicorrenza = Punteggio_TR_TRA_NID(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'PAR_ISEE' THEN
    pRicorrenza = Punteggio_PAR_ISEE(pIdDomandaIscrizione);
  END IF;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


---------------------------------------------------------------------------------------------------------------------------------


/*
  Legge l'anno scolastico corrente
*/
CREATE OR REPLACE
FUNCTION iscritto.GetUltimoGiornoAnno  ( pAnno NUMERIC(4)
                              ) RETURNS DATE AS
$BODY$
DECLARE
BEGIN
  RETURN DATE (TO_CHAR(pAnno) || '-12-31');
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

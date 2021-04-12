DROP FUNCTION punteggio_cl_dis(IN piddomandaiscrizione INTEGER, OUT pricorrenza INTEGER, OUT pdisoccupatooltre3mesi BOOLEAN);
DROP FUNCTION punteggio_cf_inf_11(IN piddomandaiscrizione INTEGER, OUT pricorrenza INTEGER, OUT pflagresidenzanao CHARACTER VARYING);
DROP FUNCTION punteggio_cf_tra_11_17(IN piddomandaiscrizione INTEGER, OUT pricorrenza INTEGER, OUT pflagresidenzanao CHARACTER VARYING);


--------------------------------------------------------------------------------------------------------------------------------------


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
------
Elaborazione allegati pervenuti
Per questa seconda fase le operazioni da eseguire sono le seguenti:
1.	Selezionare tutti gli allegati arrivati nel giorno o nel range di date preso in considerazione raggruppandoli per id_tipo_allegato.
•	Selezionare gli allegati da processare filtrando ISCRITTO_T_ALLEGATO.data_inserimento= sysdate  se il range di date è NULL altrimenti Data_da<=ISCRITTO_T_ALLEGATO.data_inserimento <= data_a
2.	La domanda d’iscrizione degli allegati selezionati al punto 1 non deve avere la data di consegna uguale alla data di inserimento dell’allegato ( perché già presi in considerazione nell’elaborazione delle domande ).
•	ISCRITTO_T_DOMANDA_ISC.data_consegna <> ISCRITTO_T_ALLEGATO.data_inserimento
3.	Per tutti gli allegati rimasti dopo il punto 2 verificare il tipo di allegato e associare la condizione di punteggio appropriata alla domanda dell’allegato.
•	Corrispondenza ISCRITTO_D_TIPO_ALL con ISCRITTO_D_CONDIZIONE_PUNTEGGIO
DIS  PA_DIS
SAL  PA_PRB_SAL
GRA  CF_GRA
Inserire un record in tabella ISCRITTO_R_PUNTEGGIO_DOM se non c’è ancora un record per la domanda con lo stesso id_condizione_punteggio da inserire:
id_domanda_iscrizione= id_domanda
dt_inizio_validita = sysdate
dt_fine_validita= NULL
id_utente=NULL
note=NULL
ricorrenza= 1 
id_condizione_punteggio= id_condizione_punteggio corrispondente al tipo di allegato
fl_valida = NULL 

Se per la domanda ci sono già uno o più record con lo stesso id_condizione_punteggio occorre selezionare quello con d_fine_validità null:
o	Se  fl_valida <> N non si fa nulla
o	Se fl_valida = N inserire nel campo d_fine_validita il valore sysdate-1 nel record valido e poi inserire il nuovo record.
*/
CREATE OR REPLACE
FUNCTION AttribuisciCondizioni  ( pDataDa DATE
                                , pDataA  DATE
                                ) RETURNS SMALLINT AS
$BODY$
DECLARE
  domanda                 RECORD;
  alleg                   RECORD;
  condPunt                RECORD;
  rec                     RECORD;
  nIdDomandaIscrizione    iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
  nIdCondizionePunteggio  iscritto_d_condizione_pun.id_condizione_punteggio%TYPE;
  sCodCondizione          iscritto_d_condizione_pun.cod_condizione%TYPE;
  dDataDa                 DATE;
  dDataA                  DATE;
  nRetCode                INTEGER;
  sFlagValida             iscritto_r_punteggio_dom.fl_valida%TYPE;
  bDaInserire             BOOLEAN;
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
        nRetCode = AggiungiCondizionePunteggio ( domanda.id_domanda_iscrizione, condPunt.id_condizione_punteggio, rec.pRicorrenza, rec.pFlagValida );
      END IF;
    END LOOP;
  END LOOP;
  -- Ciclo sugli allegati
  FOR alleg IN  SELECT  dom.id_domanda_iscrizione   id_domanda_iscrizione
                      , cp.id_condizione_punteggio  id_condizione_punteggio
                  FROM  iscritto_t_allegato         al
                      , iscritto_t_condizione_san   cs
                      , iscritto_t_anagrafica_sog   anag
                      , iscritto_t_domanda_isc      dom
                      , iscritto_d_tipo_all         tipAlleg
                      , iscritto_d_condizione_pun   cp
                  WHERE al.id_anagrafica_soggetto = cs.id_anagrafica_soggetto
                    AND cs.id_anagrafica_soggetto = anag.id_anagrafica_soggetto
                    AND anag.id_domanda_iscrizione = dom.id_domanda_iscrizione
                    AND al.id_tipo_allegato = tipAlleg.id_tipo_allegato
                    AND date_trunc('day',al.data_inserimento) > date_trunc('day',dom.data_consegna)
                    AND DATE_TRUNC('day',al.data_inserimento) BETWEEN dDataDa AND dDataA  -- Per range (se valorizzato) oppure in data di oggi
                    AND tipAlleg.cod_tipo_allegato IN ('DIS','SAL','GRA')
                    AND tipAlleg.id_tipo_allegato = cp.id_tipo_allegato
  LOOP
    bDaInserire = FALSE;
    BEGIN
      SELECT  *
        INTO STRICT rec
        FROM  iscritto_r_punteggio_dom
        WHERE id_domanda_iscrizione = alleg.id_domanda_iscrizione
          AND id_condizione_punteggio = alleg.id_condizione_punteggio
          AND dt_fine_validita IS NULL;
      IF NVL(rec.fl_valida,' ') = 'N' THEN
        UPDATE  iscritto_r_punteggio_dom
          SET dt_fine_validita = CURRENT_DATE - INTERVAL '1 second'
          WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione
            AND id_condizione_punteggio = rec.id_condizione_punteggio
            AND dt_inizio_validita = rec.dt_inizio_validita;
        bDaInserire = TRUE;
      END IF;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        bDaInserire = TRUE;
    END;
    -------
    IF bDaInserire THEN
      nRetCode = AggiungiCondizionePunteggio ( alleg.id_domanda_iscrizione, alleg.id_condizione_punteggio, 1, NULL );
    END IF;
  END LOOP;
  -------
  nRetCode = SetDataUltimaAttribuzione(dDataA);
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


CREATE OR REPLACE
FUNCTION Punteggio  ( IN  pCodCondizione        VARCHAR(20)
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
    IF rec.pFlagResidenzaNAO = 'S' OR rec.pResidentiFuoriTorino THEN
      pFlagValida = 'S';
    END IF;
  ELSIF pCodCondizione = 'CF_TRA_11_17' THEN
    SELECT  *
      INTO  rec
      FROM  Punteggio_CF_TRA_11_17(pIdDomandaIscrizione);
    pRicorrenza = rec.pRicorrenza;
    IF rec.pFlagResidenzaNAO = 'S' OR rec.pResidentiFuoriTorino THEN
      pFlagValida = 'S';
    END IF;
  ELSIF pCodCondizione = 'CF_FRA_FRE' THEN
    pRicorrenza = Punteggio_CF_FRA_FRE(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'CF_FRA_ISC' THEN
    pRicorrenza = Punteggio_CF_FRA_ISC(pIdDomandaIscrizione);
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
    pRicorrenza = Punteggio_CL_DIS(pIdDomandaIscrizione);
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


--------------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 17
14.	Genitore disoccupato da almeno tre mesi (CL_DIS).
  Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda
  e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=3 (DIS).
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati.
*/
CREATE OR REPLACE
FUNCTION Punteggio_CL_DIS ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
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
      AND tipCondOcc.cod_tip_cond_occupazionale = 'DIS';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 9
6.	Ogni figlio/a fino a 10 anni di età ( CF_INF_11 ). 
  In questo caso si intende che il bambino/a deve avere un’età inferiore a 11 anni al 31/12 dell’anno scolastico di riferimento.
  L’anno scolastico di riferimento si ricava selezionando il record dalla tabella ISCRITTO_T_ANAGRAFICA_GRA in cui la data di sistema
  è compresa tra la data dt_inizio_iscrizioni e la data dt_fine_iscr per recuperare l’id_anno_scolastico.
  Con l’id_anno_scolastico si accede alla tabella ISCRITTO_T_ANNO_SCO per recuperare l’anno della data data_da. Esempio:
  se la data_da= ‘01/09/2018’  il bambino deve avere un’età inferiore a 11 anni alla data del 31/12/2018.
  I soggetti a cui occorre effettuare il controllo dell’età sono:
    •	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 4 (CMP_NUC) o 7 (ALT_CMP) che hanno ISCRITTO_T_ANAGRAFICA_SOG.id_rel_parentela in 1 (FGL) o 4 (MIN_AFF).
    •	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
    •	Se il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ per tutti i soggetti trovati allora il flag fl_valida dovrà essere impostato a ‘S’.
    •	Se i soggetti hanno tutti una residenza fuori Torino ( ISCRITTO_T_INDIRIZZO_RES.id_comune <> 8207 ( TORINO ) allora il flag fl_valida dovrà essere impostato a ‘S’.
*/
CREATE OR REPLACE
FUNCTION Punteggio_CF_INF_11  ( IN  pIdDomandaIscrizione  INTEGER
                              , OUT pRicorrenza           INTEGER
                              , OUT pFlagResidenzaNAO     VARCHAR(1)
                              , OUT pResidentiFuoriTorino BOOLEAN
                              ) AS
$BODY$
DECLARE
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = NULL;
  pResidentiFuoriTorino = TRUE;
  nAnnoScolastico = GetAnnoScolastico();
  --------
  FOR soggetto IN SELECT  anSog.id_anagrafica_soggetto          id_anagrafica_soggetto
                        , anSog.data_nascita                    data_nascita
                        , COALESCE(anSog.fl_residenza_nao,'N')  fl_residenza_nao
                    FROM  iscritto_t_anagrafica_sog   anSog
                        , iscritto_r_soggetto_rel     sogRel
                        , iscritto_d_tipo_sog         tipSog
                        , iscritto_d_relazione_par    relPar
                    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                      AND anSog.id_rel_parentela = relPar.id_rel_parentela
                      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
                      AND tipSog.cod_tipo_soggetto IN ( 'CMP_NUC', 'ALT_CMP' )  -- "ALTRI SOGGETTI DEL NUCLEO" oppure "Altri componenti"
                      AND relPar.cod_parentela IN ( 'FGL', 'MIN_AFF' )          -- "Figlio/a del richiedente o altro genitore" oppure "Minore in affidamento"
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
    --
    IF ResidenteInTorino(soggetto.id_anagrafica_soggetto) THEN
      pResidentiFuoriTorino = FALSE;
    END IF;
  END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


/*
  Dice se un soggetto è residente in Torino
*/
CREATE OR REPLACE
FUNCTION ResidenteInTorino  ( pIdAnagraficaSoggetto INTEGER
                            ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  bResidenteInTorino  BOOLEAN;
BEGIN
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  bResidenteInTorino
    FROM  iscritto_t_indirizzo_res  indRes
        , iscritto_t_comune         com
    WHERE indRes.id_comune = com.id_comune
      AND indRes.id_anagrafica_soggetto = pIdAnagraficaSoggetto
      AND com.istat_comune = '001272';
  RETURN bResidenteInTorino;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 11
10.	Presenza di fratelli/sorelle frequentanti o iscrivendi lo stesso nido (CF_FRA_FRE).
  Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_fratello_freq=’S’ e ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 1 ( FREQ ).
*/
CREATE OR REPLACE
FUNCTION Punteggio_CF_FRA_FRE ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc    domIsc
        , iscritto_t_fratello_fre   fraFre
        , iscritto_d_tipo_fra       tipFra
    WHERE domIsc.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND domIsc.id_domanda_iscrizione = pIdDomandaIscrizione
      AND fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
      AND domIsc.fl_fratello_freq = 'S'
      AND tipFra.cod_tipo_fratello = 'FREQ';
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 23
  11.	Presenza di fratelli/sorelle iscrivendi gli stessi nidi (CF_FRA_ISC).
  Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_fratello_freq=’S’ e 
  ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 2 ( ISCR ).
*/
CREATE OR REPLACE
FUNCTION Punteggio_CF_FRA_ISC ( IN  pIdDomandaIscrizione  INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc    domIsc
        , iscritto_t_fratello_fre   fraFre
        , iscritto_d_tipo_fra       tipFra
    WHERE domIsc.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND domIsc.id_domanda_iscrizione = pIdDomandaIscrizione
      AND fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
      AND domIsc.fl_fratello_freq = 'S'
      AND tipFra.cod_tipo_fratello = 'ISCR';
  -------
  RETURN nRicorrenza;
  -------
  RETURN nRicorrenza;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


/*
ID_CONDIZIONE_PUNTEGGIO = 8
8.	Ogni figlio/a di età  tra 11 e 17 anni (CF_TRA_11_17). 
  In questo caso si intende che il bambino/a deve avere un’età compresa tra gli 11 e i 17 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
  I soggetti a cui occorre effettuare il controllo dell’età sono:
    •	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 4 (CMP_NUC) o 7 (ALT_CMP) che hanno ISCRITTO_T_ANAGRAFICA_SOG.id_rel_parentela in 1 (FGL) o 4 (MIN_AFF).
    •	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
    •	Se il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ per tutti i soggetti trovati allora il flag fl_valida dovrà essere impostato a ‘S’.
    •	Se i soggetti hanno tutti una residenza fuori Torino ( ISCRITTO_T_INDIRIZZO_RES.id_comune <> 8207 ( TORINO ) allora il flag fl_valida dovrà essere impostato a ‘S’.
*/
CREATE OR REPLACE
FUNCTION Punteggio_CF_TRA_11_17 ( IN  pIdDomandaIscrizione  INTEGER
                                , OUT pRicorrenza           INTEGER
                                , OUT pFlagResidenzaNAO     VARCHAR(1)
                                , OUT pResidentiFuoriTorino BOOLEAN
                                ) AS
$BODY$
DECLARE
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = NULL;
  pResidentiFuoriTorino = TRUE;
  nAnnoScolastico = GetAnnoScolastico();
  --------
  FOR soggetto IN SELECT  anSog.id_anagrafica_soggetto          id_anagrafica_soggetto
                        , anSog.data_nascita                    data_nascita
                        , COALESCE(anSog.fl_residenza_nao,'N')  fl_residenza_nao
                    FROM  iscritto_t_anagrafica_sog   anSog
                        , iscritto_r_soggetto_rel     sogRel
                        , iscritto_d_tipo_sog         tipSog
                        , iscritto_d_relazione_par    relPar
                    WHERE anSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                      AND anSog.id_rel_parentela = relPar.id_rel_parentela
                      AND anSog.id_domanda_iscrizione = pIdDomandaIscrizione
                      AND tipSog.cod_tipo_soggetto IN ( 'CMP_NUC', 'ALT_CMP' )    -- "ALTRI SOGGETTI DEL NUCLEO" oppure "Altri componenti"
                      AND relPar.cod_parentela IN ( 'FGL', 'MIN_AFF' )            -- "Figlio/a del richiedente o altro genitore" oppure "Minore in affidamento"
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
    --
    IF ResidenteInTorino(soggetto.id_anagrafica_soggetto) THEN
      pResidentiFuoriTorino = FALSE;
    END IF;
  END LOOP;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;


--------------------------------------------------------------------------------------------------------------------------------------


/*
  Aggiunge unna nuova condizione di punteggio per una certa domanda
*/
CREATE OR REPLACE
FUNCTION AggiungiCondizionePunteggio  ( pIdDomandaIscrizione    INTEGER
                                      , pIdCondizionePunteggio  INTEGER
                                      , pRicorrenza             INTEGER
                                      , pFlagValida             CHARACTER VARYING(1)
                                      ) RETURNS INTEGER AS
$BODY$
DECLARE
BEGIN
  INSERT INTO iscritto_r_punteggio_dom
              ( id_domanda_iscrizione
              , id_condizione_punteggio
              , ricorrenza
              , fl_valida
              , dt_inizio_validita
              )
    VALUES  ( pIdDomandaIscrizione
            , pIdCondizionePunteggio
            , pRicorrenza
            , pFlagValida
            , CURRENT_DATE
            );
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

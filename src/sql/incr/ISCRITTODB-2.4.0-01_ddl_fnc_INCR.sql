DROP FUNCTION attribuiscicondizioni(pcodordinescuola character varying, pdatada date, pdataa date);
--
CREATE OR REPLACE FUNCTION attribuiscicondizioni(pcodordinescuola character varying, pdatada date, pdataa date)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
    domanda                RECORD;
    alleg                  RECORD;
    condiz                 RECORD;
    rec                    RECORD;
    nIdDomandaIscrizione   iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
    nIdCondizionePunteggio iscritto_d_condizione_pun.id_condizione_punteggio%TYPE;
    sCodCondizione         iscritto_d_condizione_pun.cod_condizione%TYPE;
    dDataDa                DATE;
    dDataA                 DATE;
    nRetCode               INTEGER;
    sFlagValida            iscritto_r_punteggio_dom.fl_valida%TYPE;
    bDaInserire            BOOLEAN;
    vFound                 BOOLEAN;
    COND_MIN               INTEGER;
    COND_ALT               INTEGER;
    ordineScuola           iscritto_t_domanda_isc.id_ordine_scuola%TYPE;
BEGIN
    ordineScuola = getidordinescuola(pcodordineScuola);
    dDataDa = pDataDa;
    dDataA = pDataA;
    IF dDataDa IS NULL OR dDataA IS NULL THEN
        dDataDa = GetDataUltimaAttribuzione(ordineScuola) + INTERVAL '1 day';
        IF dDataDa IS NULL THEN
            dDataDa = CURRENT_DATE - INTERVAL '1 day';
        END IF;
        dDataA = CURRENT_DATE - INTERVAL '1 day';
    END IF;
    -- Ciclo sulle domande che non hanno ancora nessun record nella tabella ISCRITTO_R_PUNTEGGIO_DOM
    FOR domanda IN SELECT id_domanda_iscrizione
                   FROM iscritto_t_domanda_isc
                   WHERE id_stato_dom = 2                                            -- Domande in stato "INVIATA"
                     AND id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
                     AND DATE_TRUNC('day', data_consegna) BETWEEN dDataDa AND dDataA -- Per range (se valorizzato) oppure in data di oggi
                     AND id_domanda_iscrizione NOT IN (SELECT id_domanda_iscrizione
                                                       FROM iscritto_r_punteggio_dom
                   )
        LOOP
            nIdDomandaIscrizione = domanda.id_domanda_iscrizione;
            -- Scorro tutte le possibili condizioni di punteggio
            FOR condiz IN SELECT con.id_condizione_punteggio id_condizione_punteggio
                               , cod_condizione              cod_condizione
                          FROM iscritto_d_condizione_pun con,
                               iscritto_t_punteggio pun
                          WHERE con.id_condizione_punteggio = pun.id_condizione_punteggio
                            and TRUNC(current_date) between pun.dt_inizio_validita and coalesce(pun.dt_fine_validita, TRUNC(current_date))
                            and pun.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
                            and cod_condizione <> 'LA_PER'
                          ORDER BY con.id_condizione_punteggio
                LOOP
                    sCodCondizione = condiz.cod_condizione;
                    SELECT *
                    INTO rec
                    FROM Punteggio(sCodCondizione, nIdDomandaIscrizione);
                    IF rec.pRicorrenza > 0 THEN
                        nRetCode = AggiungiCondizionePunteggio(domanda.id_domanda_iscrizione,
                                                               condiz.id_condizione_punteggio, rec.pRicorrenza,
                                                               rec.pFlagValida);
                    END IF;
                END LOOP;
            ---------
            /*
              Se tutte le condizioni di punteggio associate alla domanda che sono legate al tipo di istruttoria 'Preventiva' sono state tutte istruite occorre settare il flag di domanda istruita della domanda.
              1.	Selezionare tutte le condizioni di punteggio della domanda che hanno l'istruttoria preventiva.
              Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM con filtro: id_domanda_iscrizione, dt_fine_validita=NULL e fl_validita=NULL e id_condizione_punteggio che ha fl_istruttoria='P' nel record della tabella ISCRITTO_D_CONDIZIONE_PUNTEGGIO.
            */
            SELECT CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
            INTO vFound
            FROM iscritto_r_punteggio_dom puntDom
               , iscritto_d_condizione_pun condPunt
            WHERE puntDom.id_condizione_punteggio = condPunt.id_condizione_punteggio
              AND puntDom.id_domanda_iscrizione = nIdDomandaIscrizione
              AND puntDom.dt_fine_validita IS NULL
              AND puntDom.fl_valida IS NULL
              AND condPunt.fl_istruttoria = 'P';
            /*
              2.	Se sono non sono stati trovati record si imposta il flag ISCRITTO_T_DOMANDA_ISC.fl_istruita='S'
            */
            IF NOT vFound THEN
                UPDATE iscritto_t_domanda_isc
                SET fl_istruita = 'S'
                WHERE id_domanda_iscrizione = nIdDomandaIscrizione;
            END IF;
        END LOOP;
    /*
        1.	Verificare se la sysdate e' minore della alla data limite per la considerazione degli allegati
      *	Eseguire una query sulla tabella ISCRITTO_T_STEP_GRA filtrando per dt_step_gra <= sysdate e id_anagrafica_gra corrispondente alle graduatorie
          appartenenti all'ordine scolastico passato come parametro e ordinare per dt_step_gra discendente.
      *	Se dt_allegati del primo record della query e' >= sysdate si procede al punto 2, altrimenti la procedura termina.
    */
    SELECT CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO vFound
    FROM (SELECT dt_allegati
          FROM (SELECT stepGra.dt_allegati dt_allegati
                FROM iscritto_t_step_gra stepGra
                   , iscritto_t_anagrafica_gra anagGra
                WHERE stepGra.id_anagrafica_gra = anagGra.id_anagrafica_gra
                  AND stepGra.dt_step_gra > CURRENT_DATE
                  AND anagGra.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
                ORDER BY stepGra.dt_step_gra
               ) a
          LIMIT 1
         ) b
    WHERE dt_allegati >= CURRENT_DATE;
    IF vFound THEN
        -- Ciclo sugli allegati
        FOR alleg IN SELECT dom.id_domanda_iscrizione  id_domanda_iscrizione
                          , cp.id_condizione_punteggio id_condizione_punteggio
                          , tipAlleg.cod_tipo_allegato tipo_allegato
                     FROM iscritto_t_allegato al
                        , iscritto_t_condizione_san cs
                        , iscritto_t_anagrafica_sog anag
                        , iscritto_t_domanda_isc dom
                        , iscritto_d_tipo_all tipAlleg
                        , iscritto_d_condizione_pun cp
                     WHERE al.id_anagrafica_soggetto = cs.id_anagrafica_soggetto
                       AND cs.id_anagrafica_soggetto = anag.id_anagrafica_soggetto
                       AND anag.id_domanda_iscrizione = dom.id_domanda_iscrizione
                       AND al.id_tipo_allegato = tipAlleg.id_tipo_allegato
                       AND date_trunc('day', al.data_inserimento) > date_trunc('day', dom.data_consegna)
                       AND DATE_TRUNC('day', al.data_inserimento) BETWEEN dDataDa AND dDataA -- Per range (se valorizzato) oppure in data di oggi
                       AND tipAlleg.cod_tipo_allegato IN ('DIS', 'SAL', 'GRA')
                       AND tipAlleg.id_tipo_allegato = cp.id_tipo_allegato
                       and dom.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)

            LOOP
                bDaInserire = FALSE;
                BEGIN
                    SELECT *
                    INTO STRICT rec
                    FROM iscritto_r_punteggio_dom
                    WHERE id_domanda_iscrizione = alleg.id_domanda_iscrizione
                      AND id_condizione_punteggio = alleg.id_condizione_punteggio
                      AND dt_fine_validita IS NULL;
                    IF NVL(rec.fl_valida, ' ') = 'N' THEN
                        UPDATE iscritto_r_punteggio_dom
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
                IF bDaInserire then

                    IF alleg.tipo_allegato = 'SAL' THEN
                        nRetCode = Punteggio_PA_PRB_SAL_MIN(alleg.id_domanda_iscrizione);
                        IF nRetCode > 0 THEN
                            select id_condizione_punteggio
                            into COND_MIN
                            from iscritto_d_condizione_pun
                            where cod_condizione = 'PA_PRB_SAL_MIN';

                            IF alleg.id_condizione_punteggio = COND_MIN then
                                nRetCode = AggiungiCondizionePunteggio(alleg.id_domanda_iscrizione, COND_MIN, 1, null);
                            end if;
                        end if;

                        nRetCode = Punteggio_PA_PRB_SAL_ALT(alleg.id_domanda_iscrizione);
                        IF nRetCode > 0 then
                            select id_condizione_punteggio
                            into COND_ALT
                            from iscritto_d_condizione_pun
                            where cod_condizione = 'PA_PRB_SAL_ALT';

                            IF alleg.id_condizione_punteggio = COND_ALT then
                                nRetCode = AggiungiCondizionePunteggio(alleg.id_domanda_iscrizione, COND_ALT, 1, null);
                            END IF;
                        end if;
                    ELSE
                        nRetCode =
                                AggiungiCondizionePunteggio(alleg.id_domanda_iscrizione, alleg.id_condizione_punteggio,
                                                            1, NULL);
                    END IF;
/*
5. Se e' stato inserito un nuovo record nella tabella ISCRITTO_R_PUNTEGGIO_DOM allora occorre resettare il flag di domanda istruita della domanda:
  Impostare ISCRITTO_T_DOMANDA_ISC.fl_istruita'N'
*/
                    UPDATE iscritto_t_domanda_isc
                    SET fl_istruita = 'N'
                    WHERE id_domanda_iscrizione = alleg.id_domanda_iscrizione;
                END IF;
            END LOOP;
    END IF;
-------
    nRetCode = SetDataUltimaAttribuzione(dDataA,ordineScuola);
-------
    RETURN 0;
END;
$function$
;

--
--
DROP FUNCTION attribuisciposti(pidstepgraduatoriacon integer);
--
CREATE OR REPLACE FUNCTION attribuisciposti(pidstepgraduatoriacon integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  scuola  RECORD;
  classe  RECORD;
  fascia  RECORD;
  grad    RECORD;
  ----
  vIdAnnoScolastico iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
  vRetCode          SMALLINT;
  vIdClasse         iscritto_t_classe.id_classe%TYPE;
  vPaSocFound       BOOLEAN;
BEGIN
  -- Ricavo l'anno scolastico
  vIdAnnoScolastico = GetIdAnnoScolastico(pIdStepGraduatoriaCon);
  -- Cancellazione posti ammessi
  FOR scuola IN SELECT  scu.id_scuola   id_scuola
                  FROM  iscritto_d_ordine_scuola    ordScu
                      , iscritto_t_scuola           scu
                  WHERE ordScu.id_ordine_scuola = scu.id_ordine_scuola
  LOOP
    FOR classe IN SELECT  id_classe
                        , posti_liberi
                        , posti_ammessi
                    FROM  iscritto_t_classe
                    WHERE id_anno_scolastico = vIdAnnoScolastico
                      AND id_scuola = scuola.id_scuola
    LOOP
      UPDATE  iscritto_t_classe
        SET posti_liberi = classe.posti_liberi + classe.posti_ammessi
          , posti_ammessi = 0
        WHERE id_classe = classe.id_classe;
    END LOOP;
  END LOOP;
  -------
    -------
  --UPDATE  iscritto_t_graduatoria
  --  SET id_stato_scu = GetIdStatoScuola('PEN')
  --  WHERE id_step_gra_con = pIdStepGraduatoriaCon
  --   AND id_stato_scu = GetIdStatoScuola('AMM');
  
  --iscritto-35 Borazio
  UPDATE  iscritto_t_graduatoria
    SET id_stato_scu = GetIdStatoScuola('PEN')
    WHERE id_step_gra_con = pIdStepGraduatoriaCon
    AND ordine_preferenza = 1
    AND id_stato_scu IN ( GetIdStatoScuola('AMM'), GetIdStatoScuola('CAN_1SC'));

  UPDATE  iscritto_t_graduatoria
    SET id_stato_scu = GetIdStatoScuola('PEN')
    WHERE id_step_gra_con = pIdStepGraduatoriaCon
    AND ordine_preferenza <> 1
    AND id_stato_scu = GetIdStatoScuola('AMM');
  -------
  -- *	Calcolo del punteggio
  vRetCode = CalcolaPunteggio(pIdStepGraduatoriaCon);
  -------
  vRetCode = OrdinaGraduatoria(pIdStepGraduatoriaCon);
  -------
  -- ATTRIBUZIONE POSTI LIBERI
  FOR fascia IN SELECT  id_fascia_eta
                  FROM  iscritto_d_fascia_eta
                  ORDER BY CASE WHEN cod_fascia_eta = 'L' THEN 1
                                WHEN cod_fascia_eta = 'P' THEN 2
                                WHEN cod_fascia_eta = 'G' THEN 3
                           END
  LOOP
    DELETE FROM iscritto_tmp_domanda;
    --------
    FOR grad IN SELECT  id_graduatoria
                      , id_domanda_iscrizione
                      , id_scuola
                      , id_tipo_frequenza
                      , ordine_preferenza
                  FROM  iscritto_t_graduatoria
                  WHERE id_step_gra_con = pIdStepGraduatoriaCon
                    AND id_fascia_eta = fascia.id_fascia_eta
                    AND id_stato_scu = GetIdStatoScuola('PEN')
                  ORDER BY  ordinamento
    LOOP
      -- Verifico se la domanda e' tra quelle non piu' da elaborare
      IF DomandaDaElaborare(grad.id_domanda_iscrizione) THEN
        SELECT CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END 
          INTO  vPaSocFound
          FROM  iscritto_r_punteggio_dom    puntDom
              , iscritto_d_condizione_pun   condPun
          WHERE puntDom.id_condizione_punteggio = condPun.id_condizione_punteggio
            AND puntDom.id_domanda_iscrizione = grad.id_domanda_iscrizione
            AND condPun.cod_condizione = 'PA_SOC'
            AND puntDom.dt_fine_validita IS NULL
            AND puntDom.fl_valida = 'S';
        ------
        BEGIN
          SELECT  cl.id_classe
            INTO STRICT vIdClasse
            FROM  iscritto_t_classe   cl
                , iscritto_t_eta      eta
            WHERE cl.id_eta = eta.id_eta
              AND cl.id_anno_scolastico = vIdAnnoScolastico
              AND cl.id_scuola = grad.id_scuola
              AND cl.id_tipo_frequenza = grad.id_tipo_frequenza
              AND eta.id_fascia_eta = fascia.id_fascia_eta
              AND cl.posti_liberi > 0
              AND COALESCE(cl.fl_ammissione_dis,' ') = CASE WHEN vPaSocFound THEN 'S' ELSE COALESCE(cl.fl_ammissione_dis,' ') END;
          UPDATE  iscritto_t_graduatoria
            SET id_stato_scu = GetIdStatoScuola('AMM')
            WHERE id_graduatoria = grad.id_graduatoria;
         
			-- inizio modifica - CH-207
			IF grad.ordine_preferenza = 1 THEN
				UPDATE iscritto_t_graduatoria
				SET id_stato_scu = getidstatoscuola('CAN_1SC')
				WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
				AND id_graduatoria <> grad.id_graduatoria
				AND id_step_gra_con = pIdStepGraduatoriaCon
				AND id_stato_scu = getidstatoscuola('PEN');
			END IF;
			-- fine modifica           
            
          UPDATE  iscritto_t_classe
            SET posti_ammessi = posti_ammessi + 1
              , posti_liberi = posti_liberi - 1
            WHERE id_classe = vIdClasse;
          -- Inserisco la domanda nell'insieme da escludere
          INSERT INTO iscritto_tmp_domanda ( id_domanda_iscrizione ) VALUES ( grad.id_domanda_iscrizione );
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            NULL;
        END;
      END IF;
    END LOOP;
  END LOOP;
  -------
  RETURN 0;
END;
$function$
;

--
--
DROP FUNCTION calcolagraduatoria(pidstepgraddacalcolare integer, pidstepgradprecedente integer, pflag character varying);
--
CREATE OR REPLACE FUNCTION calcolagraduatoria(pidstepgraddacalcolare integer, pidstepgradprecedente integer, pflag character varying)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRetCode      INTEGER;
  nOrdinamento  iscritto_t_graduatoria.ordinamento%TYPE;
  -------
  grad  RECORD;
BEGIN
  IF pFlag = 'P' THEN
    -- FLAG "P"
    IF pIdStepGradPrecedente IS NOT NULL THEN
      -- Se esiste uno step precedente pulisco la tabella di tutti i record relativi allo step attuale
      DELETE FROM iscritto_t_graduatoria
        WHERE id_step_gra_con = pIdStepGradPrecedente;
    END IF;
    -------
    nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare);
    nRetCode = AttribuisciCondizione(pIdStepGradDaCalcolare, 'LA_PER');
    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);
    nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
  ELSIF pFlag = 'D' THEN
    -- FLAG "D"
    --  3. Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l'id_step_graduatoria_con precedente
    --      nella stessa tabella con l'id_step_graduatoria_con da calcolare.
    nRetCode = DuplicaGraduatoria(pIdStepGradPrecedente, pIdStepGradDaCalcolare);
    FOR grad IN SELECT  id_domanda_iscrizione   id_domanda_iscrizione
                      , id_scuola               id_scuola
                      , id_tipo_frequenza       id_tipo_frequenza
                      , punteggio               punteggio
                  FROM  iscritto_t_graduatoria
                  WHERE id_step_gra_con = pIdStepGradPrecedente
    LOOP
      UPDATE  iscritto_r_scuola_pre
        SET id_stato_scu = GetIdStatoScuola('PEN')
          , punteggio = grad.punteggio
          , dt_stato = CURRENT_TIMESTAMP
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
          AND id_scuola = grad.id_scuola
          AND id_tipo_frequenza = grad.id_tipo_frequenza;
      UPDATE  iscritto_t_domanda_isc
        SET id_stato_dom = GetIdStatoDomanda('GRA')
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
    END LOOP;
  ELSIF pFlag = 'S' THEN
    -- FLAG "S"
    -- 1. Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l'id_step_graduatoria_con precedente nella
    --    stessa tabella con l'id_step_graduatoria_con da calcolare.
    nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare);
    nRetCode = AttribuisciCondizione(pIdStepGradDaCalcolare, 'LA_PER');
--    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);   FE 16/09/2019
    nRetCode = DuplicaGraduatoria(pIdStepGradPrecedente, pIdStepGradDaCalcolare);
    /* Inserimento in graduatoria scuole fuori termine
          +	Per tutte le domande copiate nella nuova graduatoria occorre verificare se nella data dello step sono state aggiunte
            scuole di preferenza: ISCRITTO_R_SCUOLA_PRE.dt_ins_scu compresa tra ISCRITTO_T_STEP_GRA.dt_dom_inv_da
            e ISCRITTO_T_STEP_GRA.dt_dom_inv_a
          +	Per ogni record di ISCRITTO_R_SCUOLA_PRE trovato nel passo precedente:
          o	Eseguire lo step 5 del caso con il FLAG P.
    */
    FOR grad IN SELECT  DISTINCT
                          scuPre.id_scuola              id_scuola
                        , scuPre.id_domanda_iscrizione  id_domanda_iscrizione
                        , scuPre.fl_fuori_termine       fl_fuori_termine
                        , scuPre.id_tipo_frequenza      id_tipo_frequenza
                        , scuPre.posizione              posizione
                  FROM  iscritto_t_graduatoria    gr
                      , iscritto_t_domanda_isc    domIsc
                      , iscritto_r_scuola_pre     scuPre
                      , iscritto_t_step_gra_con   stepGraCon
                      , iscritto_t_step_gra       stepGra
                  WHERE gr.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                    AND domIsc.id_domanda_iscrizione = scuPre.id_domanda_iscrizione
                    AND gr.id_step_gra_con = stepGraCon.id_step_gra_con
                    AND stepGraCon.id_step_gra = stepGra.id_step_gra
                    AND gr.id_step_gra_con = pIdStepGradDaCalcolare
                    AND scuPre.dt_ins_scu BETWEEN stepGra.dt_dom_inv_da AND stepGra.dt_dom_inv_a
    LOOP
      INSERT INTO iscritto_t_graduatoria
                  ( id_graduatoria
                  , id_step_gra_con
                  , id_scuola
                  , id_domanda_iscrizione
                  , fl_fuori_termine
                  , id_tipo_frequenza
                  , id_stato_scu
                  , isee
                  , ordine_preferenza
                  , id_fascia_eta
                  )
        VALUES  ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
                , pIdStepGradDaCalcolare
                , grad.id_scuola
                , grad.id_domanda_iscrizione
                , grad.fl_fuori_termine
                , grad.id_tipo_frequenza
                , GetIdStatoScuola('PEN')
                , GetValoreIsee(grad.id_domanda_iscrizione)
                , grad.posizione
                , GetIdFasciaEta(grad.id_domanda_iscrizione)
                );
    END LOOP;
    ------
    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);  -- FE 16/09/2019
    nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
  END IF;
  -------
  RETURN 0;
END;
$function$
;

--
--
DROP FUNCTION calcolapunteggio(pidstepgracon integer);
--
CREATE OR REPLACE FUNCTION calcolapunteggio(pidstepgracon integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  vDataUltimoCalcoloPunteggio iscritto_t_parametro.dt_ult_calcolo_pun%TYPE;
  grad                        RECORD;
  vRetCode                    SMALLINT;
BEGIN
  vDataUltimoCalcoloPunteggio = GetDataUltimoCalcoloPunteggio(pidstepgracon);
  -- Elaborare tutte le domande d'iscrizione in graduatoria ( ISCRITTO_T_GRADUATORIA.id_step_gra_con uguale a quello passato come parametro )
  -- che hanno avuto una modifica delle condizioni di punteggio uguale o superiore alla data di calcolo oppure che hanno ISCRITTO_T_GRADUATORIA.punteggio=NULL
  FOR grad IN SELECT  DISTINCT
                        dom.id_domanda_iscrizione   id_domanda_iscrizione
                FROM  iscritto_t_graduatoria    gr
                    , iscritto_t_domanda_isc    dom
                    , iscritto_r_punteggio_dom  puntDom
                WHERE gr.id_domanda_iscrizione = dom.id_domanda_iscrizione
                  AND gr.id_domanda_iscrizione = puntDom.id_domanda_iscrizione
                  AND gr.id_step_gra_con = pIdStepGraCon
                  AND (   puntDom.dt_inizio_validita >= vDataUltimoCalcoloPunteggio
                      OR  gr.punteggio IS NULL
                      )
  LOOP
    vRetCode = CalcolaPunteggioDomanda(grad.id_domanda_iscrizione, pIdStepGraCon);
  END LOOP;
  -------
  vRetCode = SetDataUltimoCalcoloPunteggio(LOCALTIMESTAMP,pidstepgracon);
  -------
  RETURN 0;
END;
$function$
;
--
--
DROP FUNCTION getdatanascita(piddomandaiscrizione integer, pcodtiposoggetto character varying);
--
CREATE OR REPLACE FUNCTION getdatanascita(piddomandaiscrizione integer, pcodtiposoggetto character varying)
  RETURNS date
  LANGUAGE plpgsql
AS
$body$
DECLARE
  dDataNascita  iscritto_t_anagrafica_sog.data_nascita%TYPE;
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
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION getdataultimaattribuzione(pordinescuola integer);
--
CREATE OR REPLACE FUNCTION getdataultimaattribuzione(pordinescuola integer)
  RETURNS date
  LANGUAGE plpgsql
AS
$body$
DECLARE
  dDataUltimaAttribuzione DATE;
BEGIN
  SELECT  dt_ult_attribuzione_con
    INTO  dDataUltimaAttribuzione
    FROM  iscritto_t_parametro
    WHERE iscritto_t_parametro.id_ordine_scuola = pOrdineScuola;
  RETURN dDataUltimaAttribuzione;
END;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION getdataultimocalcolopunteggio(pidstepgracon integer);
--
CREATE OR REPLACE FUNCTION getdataultimocalcolopunteggio(pidstepgracon integer)
  RETURNS date
  LANGUAGE plpgsql
AS
$body$
DECLARE
    dDataUltimoCalcoloPunteggio DATE;
    ordineScuola                iscritto_t_parametro.id_ordine_scuola%TYPE;
BEGIN
    SELECT dom.id_ordine_scuola
    INTO ordineScuola
    FROM iscritto_t_graduatoria gr
       , iscritto_t_domanda_isc dom
       , iscritto_r_punteggio_dom puntDom
    WHERE gr.id_domanda_iscrizione = dom.id_domanda_iscrizione
      AND gr.id_domanda_iscrizione = puntDom.id_domanda_iscrizione
      AND gr.id_step_gra_con = pIdStepGraCon
    LIMIT 1;

    SELECT dt_ult_calcolo_pun
    INTO dDataUltimoCalcoloPunteggio
    FROM iscritto_t_parametro
    WHERE iscritto_t_parametro.id_ordine_scuola = ordineScuola;
    RETURN dDataUltimoCalcoloPunteggio;
END;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION gettestoemail(pidaccettazionerin integer);
--
CREATE OR REPLACE FUNCTION gettestoemail(pidaccettazionerin integer)
  RETURNS character varying
  LANGUAGE plpgsql
AS
$body$
DECLARE
    sTestoEmail               iscritto_t_parametro.testo_mail_eco%TYPE;
    sTestoEmailFinale         iscritto_t_parametro.testo_mail_eco%TYPE;
    nIdDomandaIscrizione      iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
    sProtocollo               iscritto_t_domanda_isc.protocollo%TYPE;
    nIdAnnoScolastico         iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
    nIdOrdineScuola           iscritto_t_domanda_isc.id_ordine_scuola%TYPE;
    sCognomeNome              VARCHAR(101);
    dDataNascita              iscritto_t_anagrafica_sog.data_nascita%TYPE;
    sDescFasciaEta            iscritto_d_fascia_eta.descrizione%TYPE;
    sDescTipoFrequenza        iscritto_d_tipo_fre.descrizione%TYPE;
    dDataOperazione           iscritto_t_acc_rin.dt_operazione%TYPE;
    sTelefono                 iscritto_t_invio_acc.telefono%TYPE;
    sCognomeNomeCodFiscRichiedente   VARCHAR(117);
    sCodiceFiscaleMinore      iscritto_t_anagrafica_sog.codice_fiscale%TYPE;
    sCittadinanzaMinore       iscritto_t_stato.cittadinanza%TYPE;
    sComuneDiResidenzaMinore  iscritto_t_comune.desc_comune%TYPE;
    sIndirizzoMinore          iscritto_t_indirizzo_res.indirizzo%TYPE;
    sTipologiaPasto           iscritto_d_tipo_pasto.descrizione%TYPE;
    nOrdineScuola             iscritto_t_domanda_isc.id_ordine_scuola%TYPE;
    dDataFasciaEtaDa          iscritto_t_eta.data_da%TYPE;
    dDataFasciaEtaA           iscritto_t_eta.data_a%TYPE;
    sNomeNido                 iscritto_t_scuola.descrizione%TYPE;
BEGIN
    -- Stabilisco l'ordine scuola
    SELECT domIscr.id_ordine_scuola
    INTO nOrdineScuola
    FROM iscritto_t_domanda_isc domIscr
       , iscritto_t_acc_rin accRin
    WHERE accRin.id_accettazione_rin = pIdAccettazioneRin
      AND domIscr.id_domanda_iscrizione = accRin.id_domanda_iscrizione;

    IF nOrdineScuola = 1 THEN
        -- [CASO NIDI]
        -- Recupero il modello del testo della email
        SELECT testo_mail_eco
        INTO sTestoEmail
        FROM iscritto_t_parametro
        WHERE iscritto_t_parametro.id_ordine_scuola = 1;

        -- Recupero l'ID della domanda di iscrizione, il Tipo frequenza, la Data operazione e il telefono
        -- + Tipologia pasto
        -- + 27/07 Nome del nido
        SELECT accRin.id_domanda_iscrizione
             , tipoFre.descrizione
             , TRUNC(accRin.dt_operazione)
             , invAcc.telefono
             , tipoPasto.descrizione
             , scu.descrizione
        INTO nIdDomandaIscrizione
            , sDescTipoFrequenza
            , dDataOperazione
            , sTelefono
            , sTipologiaPasto
            , sNomeNido
        FROM iscritto_t_acc_rin accRin
           , iscritto_d_tipo_fre tipoFre
           , iscritto_t_invio_acc invAcc
           , iscritto_d_tipo_pasto tipoPasto
           , iscritto_t_scuola scu
        WHERE accRin.id_tipo_frequenza = tipoFre.id_tipo_frequenza
          AND accRin.id_accettazione_rin = invAcc.id_accettazione_rin
          AND accRin.id_accettazione_rin = pIdAccettazioneRin
          AND invAcc.id_tipo_pasto = tipoPasto.id_tipo_pasto
          AND accRin.id_scuola = scu.id_scuola;
        -------
        -- Recupero il numero della domanda
        SELECT protocollo
             , id_anno_scolastico
             , id_ordine_scuola
        INTO sProtocollo
            , nIdAnnoScolastico
            , nIdOrdineScuola
        FROM iscritto_t_domanda_isc
        WHERE id_domanda_iscrizione = nIdDomandaIscrizione;
        -------
        -- Recupero cognome e nome del minore e la data di nascita
        -- + aggiunta 29/06/2020 codice fiscale, cittadinanza, comune di residenza, indirizzo del minore
        SELECT anagSog.cognome || ' ' || anagSog.nome
             , anagSog.data_nascita
             , anagSog.codice_fiscale
             , statoSog.cittadinanza
             , comuneSog.desc_comune
             , indiRes.indirizzo
        INTO sCognomeNome
            , dDataNascita
            , sCodiceFiscaleMinore
            , sCittadinanzaMinore
            , sComuneDiResidenzaMinore
            , sIndirizzoMinore
        FROM iscritto_t_anagrafica_sog anagSog
           , iscritto_r_soggetto_rel sogRel
           , iscritto_d_tipo_sog tipoSog
           , iscritto_t_stato statoSog
           , iscritto_t_indirizzo_res indiRes
           , iscritto_t_comune comuneSog
        WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
          AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
          AND anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
          AND tipoSog.cod_tipo_soggetto = 'MIN'
          AND anagSog.id_stato_citt = statoSog.id_stato
          AND anagSog.id_anagrafica_soggetto = indiRes.id_anagrafica_soggetto
          AND indiRes.id_comune = comuneSog.id_comune
          AND comuneSog.rel_status = '1';
        -------
        -- Recupero la fascia d'età
        SELECT fasciaEta.descrizione
        INTO sDescFasciaEta
        FROM iscritto_t_anagrafica_gra anagGra
           , iscritto_t_eta eta
           , iscritto_d_fascia_eta fasciaEta
        WHERE anagGra.id_anagrafica_gra = eta.id_anagrafica_gra
          AND eta.id_fascia_eta = fasciaEta.id_fascia_eta
          AND anagGra.id_anno_scolastico = nIdAnnoScolastico
          AND anagGra.id_ordine_scuola = nIdOrdineScuola
          AND dDataNascita BETWEEN eta.data_da AND eta.data_a;
        -------
        -- + Recupero Nome, Cognome e codice fiscale del Richiedente
        SELECT anagSog.cognome || ' ' || anagSog.nome || ' ' || anagSog.codice_fiscale
        INTO sCognomeNomeCodFiscRichiedente
        FROM iscritto_t_anagrafica_sog anagSog
           , iscritto_r_soggetto_rel sogRel
        WHERE anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
          AND sogRel.id_anagrafica_soggetto = anagSog.id_anagrafica_soggetto
          AND sogRel.id_tipo_soggetto = 5;
        ------
        -- gestione casi null
        IF sCittadinanzaMinore IS NULL THEN
           sCittadinanzaMinore = 'non dichiarata';
        END IF;
        IF sTipologiaPasto IS NULL THEN
           sTipologiaPasto = 'scelta tipo pasto non richiesta in accettazione';
        END IF;
        ------
        sTestoEmailFinale = ' ';
        FOR i IN 1..LENGTH(sTestoEmail)
            LOOP
                IF SUBSTR(sTestoEmail, i, 1) = '1' THEN
                    sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataOperazione, 'DD/MM/YYYY');
                ELSIF SUBSTR(sTestoEmail, i, 1) = '2' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sProtocollo;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '3' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCognomeNome;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '4' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sDescFasciaEta;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '5' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sDescTipoFrequenza;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '6' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sTelefono;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '7' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCognomeNomeCodFiscRichiedente;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '8' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCodiceFiscaleMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '9' THEN
                    sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataNascita, 'DD/MM/YYYY');
                ELSIF SUBSTR(sTestoEmail, i, 1) = '!' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCittadinanzaMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '"' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sComuneDiResidenzaMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '#' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sIndirizzoMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '$' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sTipologiaPasto;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '%' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sNomeNido;
                ELSE
                    IF ASCII(SUBSTR(sTestoEmail, i, 1)) <> 13 THEN
                        sTestoEmailFinale = sTestoEmailFinale || SUBSTR(sTestoEmail, i, 1);
                    END IF;
                END IF;
            END LOOP;
        -------

    END IF;


    IF nOrdineScuola = 2 THEN
        -- [CASO MATERNE]
        -- Recupero il modello del testo della email
        SELECT testo_mail_eco
        INTO sTestoEmail
        FROM iscritto_t_parametro
        WHERE iscritto_t_parametro.id_ordine_scuola = 2;
        -- Recupero l'ID della domanda di iscrizione, la Data operazione e il telefono *2
        -- + Tipologia pasto
        SELECT accRin.id_domanda_iscrizione
             , TRUNC(accRin.dt_operazione)
             , telefono
             , tipoPasto.descrizione
        INTO nIdDomandaIscrizione
            , dDataOperazione
            , sTelefono
            , sTipologiaPasto
        FROM iscritto_t_acc_rin accRin
           , iscritto_t_invio_acc invAcc
           , iscritto_d_tipo_pasto tipoPasto
        WHERE accRin.id_accettazione_rin = invAcc.id_accettazione_rin
          AND accRin.id_accettazione_rin = pIdAccettazioneRin
          AND invAcc.id_tipo_pasto = tipoPasto.id_tipo_pasto;
        -------
        -- Recupero il numero della domanda
        SELECT protocollo
             , id_anno_scolastico
             , id_ordine_scuola
        INTO sProtocollo
            , nIdAnnoScolastico
            , nIdOrdineScuola
        FROM iscritto_t_domanda_isc
        WHERE id_domanda_iscrizione = nIdDomandaIscrizione;
        -------
        -- Recupero cognome e nome del minore e la data di nascita *1
        -- + aggiunta 29/06/2020 codice fiscale, cittadinanza, comune di residenza, indirizzo del minore
        SELECT anagSog.cognome || ' ' || anagSog.nome
             , anagSog.data_nascita
             , anagSog.codice_fiscale
             , statoSog.cittadinanza
             , comuneSog.desc_comune
             , indiRes.indirizzo
        INTO sCognomeNome
            , dDataNascita
            , sCodiceFiscaleMinore
            , sCittadinanzaMinore
            , sComuneDiResidenzaMinore
            , sIndirizzoMinore
        FROM iscritto_t_anagrafica_sog anagSog
           , iscritto_r_soggetto_rel sogRel
           , iscritto_d_tipo_sog tipoSog
           , iscritto_t_stato statoSog
           , iscritto_t_indirizzo_res indiRes
           , iscritto_t_comune comuneSog
        WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
          AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
          AND anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
          AND tipoSog.cod_tipo_soggetto = 'MIN'
          AND anagSog.id_stato_citt = statoSog.id_stato
          AND anagSog.id_anagrafica_soggetto = indiRes.id_anagrafica_soggetto
          AND indiRes.id_comune = comuneSog.id_comune
          AND comuneSog.rel_status = '1';
        -------
        -- +Recupero la fascia d'età
        SELECT eta.data_da
             , eta.data_a
        INTO dDataFasciaEtaDa
            , dDataFasciaEtaA
        FROM iscritto_t_anagrafica_gra anagGra
           , iscritto_t_eta eta
           , iscritto_d_fascia_eta fasciaEta
        WHERE anagGra.id_anagrafica_gra = eta.id_anagrafica_gra
          AND eta.id_fascia_eta = fasciaEta.id_fascia_eta
          AND anagGra.id_anno_scolastico = nIdAnnoScolastico
          AND anagGra.id_ordine_scuola = nIdOrdineScuola
          AND dDataNascita BETWEEN eta.data_da AND eta.data_a;
        -------
        -- +Recupero Nome, Cognome e codice fiscale del Richiedente
       SELECT anagSog.cognome || ' ' || anagSog.nome || ' ' || anagSog.codice_fiscale
        INTO sCognomeNomeCodFiscRichiedente
        FROM iscritto_t_anagrafica_sog anagSog
           , iscritto_r_soggetto_rel sogRel
        WHERE anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
          AND sogRel.id_anagrafica_soggetto = anagSog.id_anagrafica_soggetto
          AND sogRel.id_tipo_soggetto = 5;
        ------
        -- gestione casi null
        IF sCittadinanzaMinore IS NULL THEN
           sCittadinanzaMinore = 'non dichiarata';
        END IF;
        IF sTipologiaPasto IS NULL THEN
           sTipologiaPasto = 'scelta tipo pasto non richiesta in accettazione';
        END IF;
        ------
        sTestoEmailFinale = ' ';
        FOR i IN 1..LENGTH(sTestoEmail)
            LOOP
                IF SUBSTR(sTestoEmail, i, 1) = '1' THEN
                    sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataOperazione, 'DD/MM/YYYY');
                ELSIF SUBSTR(sTestoEmail, i, 1) = '2' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sProtocollo;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '3' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCognomeNome;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '4' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sDescFasciaEta;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '5' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sDescTipoFrequenza;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '6' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sTelefono;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '7' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCognomeNomeCodFiscRichiedente;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '8' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCodiceFiscaleMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '9' THEN
                    sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataNascita, 'DD/MM/YYYY');
                ELSIF SUBSTR(sTestoEmail, i, 1) = '!' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sCittadinanzaMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '"' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sComuneDiResidenzaMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '#' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sIndirizzoMinore;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '$' THEN
                    sTestoEmailFinale = sTestoEmailFinale || sTipologiaPasto;
                ELSIF SUBSTR(sTestoEmail, i, 1) = '%' THEN
                    sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataFasciaEtaDa, 'DD/MM/YYYY');
                ELSIF SUBSTR(sTestoEmail, i, 1) = '&' THEN
                    sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataFasciaEtaA, 'DD/MM/YYYY');
                ELSE
                    IF ASCII(SUBSTR(sTestoEmail, i, 1)) <> 13 THEN
                        sTestoEmailFinale = sTestoEmailFinale || SUBSTR(sTestoEmail, i, 1);
                    END IF;
                END IF;
            END LOOP;
        -------
    END IF;


    RETURN sTestoEmailFinale;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN 0;
END;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION gettestosmsammissione(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION gettestosmsammissione(piddomandaiscrizione integer)
  RETURNS character varying
  LANGUAGE plpgsql
AS
$body$
DECLARE
  vNome                 iscritto_t_anagrafica_sog.nome%TYPE;
  vTesto                VARCHAR(500);
  vLunghezzaMassimaNome INTEGER;
BEGIN
  select  TRIM(SCU.indirizzo), --anagSog.id_domanda_iscrizione,TRIM(anagSog.nome) , 
          REPLACE( par.testo_sms_amm , 'gg/mm/yyyy', TO_CHAR(NextSunday(CURRENT_DATE+1),'DD/MM/YYYY') )
    INTO  vNome, vTesto
    FROM  iscritto_t_parametro        par
        , iscritto_t_anagrafica_sog   anagSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipSog
        , iscritto_t_graduatoria      pre
        , iscritto_t_scuola           scu
    WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto        = tipSog.id_tipo_soggetto
      and pre.id_domanda_iscrizione      = anagsog.id_domanda_iscrizione 
      and pre.id_stato_scu               = GetIdStatoScuola('AMM')
      and pre.id_step_gra_con            = (select max(gra.id_step_gra_con ) 
                                              from iscritto_t_graduatoria gra
                                             where gra.id_domanda_iscrizione = anagsog.id_domanda_iscrizione 
                                               and gra.id_stato_scu = GetIdStatoScuola('AMM')
                                            )
      and scu.id_scuola                  = pre.id_scuola 
      AND anagSog.id_domanda_iscrizione  = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto       = 'MIN'
      AND scu.id_ordine_scuola           = par.id_ordine_scuola;
     
 -- SELECT  TRIM(anagSog.nome)
 --       , REPLACE( par.testo_sms_amm , 'gg/mm/yyyy', TO_CHAR(NextSunday(CURRENT_DATE+1),'DD/MM/YYYY') )
 --   INTO  vNome
 --       , vTesto
 --   FROM  iscritto_t_parametro        par
 --       , iscritto_t_anagrafica_sog   anagSog
 --       , iscritto_r_soggetto_rel     sogRel
 --       , iscritto_d_tipo_sog         tipSog
 --   WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
 --     AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
 --     AND anagSog.id_domanda_iscrizione = pIdDomandaIscrizione
 --     AND tipSog.cod_tipo_soggetto = 'MIN';	   ---------
  vLunghezzaMassimaNome = 159-GetLunghezzaSms(vTesto)+1;
  WHILE LENGTH(vNome) > vLunghezzaMassimaNome
  LOOP
    IF INSTR(vNome,' ',-1) = 0 THEN
      vNome = SUBSTR(vNome, 1, vLunghezzaMassimaNome);
    ELSE
      vNome = SUBSTR(vNome, 1, INSTR(vNome,' ',-1)-1);
    END IF;
  END LOOP;
  ---------
  RETURN REPLACE(vTesto,'X',vNome);
END;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION ins_posti(pid_anno_sco integer, pid_ordine_scu integer);
--
CREATE OR REPLACE FUNCTION ins_posti(pid_anno_sco integer, pid_ordine_scu integer)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
declare
	rpl integer  := 0;
	rpa integer  := 0;
  	scuola  RECORD;
    eta RECORD;
begin
-- UM 2020-03-25
-- Funzione ad USO di TEST per riempire velocemente la tabella delle classi
-- richiede in ingresso idannoscolastico e idordine scuola


    FOR scuola IN SELECT  id_scuola
                    FROM  iscritto_t_scuola
                    WHERE fl_eliminata  = 'N'
					  AND id_ordine_scuola = pid_ordine_scu
    LOOP
	-- genero un numero casuale tra 1 e 20 per posti liberi e ammessi
		SELECT into rpl floor(random() * 20 + 1)::int;
		SELECT into rpa floor(random() * 20 + 1)::int;
		
		FOR eta IN SELECT id_eta 
					FROM iscritto_t_eta
					WHERE id_anagrafica_gra = (
							select g.id_anagrafica_gra
							from iscritto_t_anagrafica_gra g
							where g.id_ordine_scuola = 2
							and g.id_anno_scolastico = 3)
					 AND id_fascia_eta  in (4,7,8)
		LOOP
						INSERT INTO iscritto.iscritto_t_classe
								(id_classe,
								id_scuola,
								posti_liberi,
								posti_ammessi,
								denominazione,
								id_anno_scolastico,
								id_tipo_frequenza,
								id_eta,
								fl_ammissione_dis)
						VALUES	( nextval('iscritto_t_classe_id_classe_seq'),
								scuola.id_scuola,
								rpl,
								rpa,
								decode(eta.id_eta, 16, 'I', 14, 'II', 15, 'III'),
								pid_anno_sco,
								0,
								eta.id_eta,
								'S');
		END LOOP;
	END LOOP;
	
	return(0);
	exception
	  when others then   
		return(1);   
end;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION preparadatisise();
--
CREATE OR REPLACE FUNCTION preparadatisise()
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  rec RECORD;
  sCodiceFiscaleRichiedente   iscritto_t_anagrafica_sog.codice_fiscale%TYPE;
  sCognomeRichiedente         iscritto_t_anagrafica_sog.cognome%TYPE;
  sNomeRichiedente            iscritto_t_anagrafica_sog.nome%TYPE;
  nIdTmpFlusso                iscritto_tmp_flusso.id_tmp_fusso%TYPE;
  sRecord                     iscritto_tmp_flusso.record%TYPE;
  sCodiceParentela            iscritto_d_relazione_par.cod_parentela%TYPE;
BEGIN
  DELETE FROM iscritto_tmp_flusso;
  nIdTmpFlusso = 0;
  ---------
  FOR rec IN  SELECT  domIsc.id_domanda_iscrizione  id_domanda_iscrizione
                    , anagSog.codice_fiscale        codice_fiscale_minore
                    , anagSog.cognome               cognome_minore
                    , anagSog.nome                  nome_minore
                    , anagSog.data_nascita          data_nascita_minore
                    , invAcc.telefono               telefono
                    , invAcc.id_accettazione_rin    id_acc_rin
                    , indRes.indirizzo              indirizzo_residenza
                    , indRes.cap                    cap_residenza
                    , COALESCE(com.cod_catasto,sta.codice) istat_comune_residenza
--                    com.istat_comune              istat_comune_residenza
                    , scu.cod_scuola                cod_nido_accettazione
                    , tipFre.cod_tipo_frequenza     cod_tipo_frequenza
                    , annoSco.data_da               inizio_anno_scolastico
                    , annoSco.data_a                fine_anno_scolastico
                    , accRin.dt_operazione          data_accettazione
                    , tipPas.cod_tipo_pasto 		tipo_pasto
                    , domIsc.protocollo             protocollo
                FROM  iscritto_t_invio_acc        invAcc
                    left join iscritto_d_tipo_pasto tipPas on invAcc.id_tipo_pasto=tipPas.id_tipo_pasto
                    , iscritto_t_acc_rin          accRin
                    , iscritto_t_domanda_isc      domIsc
                    , iscritto_t_anagrafica_sog   anagSog
                    , iscritto_r_soggetto_rel     sogRel
                    , iscritto_d_tipo_sog         tipSog
                    , iscritto_t_indirizzo_res    indRes
                    left join iscritto_t_comune com on indRes.id_comune=com.id_comune
                    left join iscritto_t_stato sta on indRes.id_stato_residenza=sta.id_stato
                    , iscritto_t_scuola           scu
                    , iscritto_d_tipo_fre         tipFre
                    , iscritto_t_anno_sco         annoSco
                    , iscritto_d_categoria_scu    catScu
                 WHERE invAcc.id_accettazione_rin = accRin.id_accettazione_rin
                  AND accRin.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
                  AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                  AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                  AND tipSog.cod_tipo_soggetto = 'MIN'
                  AND anagSog.id_anagrafica_soggetto = indRes.id_anagrafica_soggetto
                  AND accRin.id_scuola = scu.id_scuola
                  AND accRin.id_tipo_frequenza = tipFre.id_tipo_frequenza
                  AND domIsc.id_anno_scolastico = annoSco.id_anno_scolastico
                  and SCU.id_categoria_scu=catScu.id_categoria_scu
                  and catScu.codice_categoria_scu <> 'P'
                  AND invAcc.dt_invio_sise IS NULL
  LOOP
    SELECT  anagSog.codice_fiscale
          , anagSog.cognome
          , anagSog.nome
          , relPar.cod_parentela
      INTO  sCodiceFiscaleRichiedente
          , sCognomeRichiedente
          , sNomeRichiedente
          , sCodiceParentela
      FROM  iscritto_t_anagrafica_sog   anagSog
          , iscritto_r_soggetto_rel     sogRel
          , iscritto_d_tipo_sog         tipSog
          , iscritto_d_relazione_par    relPar
      WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
        AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
        AND anagSog.id_domanda_iscrizione = rec.id_domanda_iscrizione
        AND tipSog.cod_tipo_soggetto = 'RIC'
        AND anagSog.id_rel_parentela=relPar.id_rel_parentela;
    nIdTmpFlusso = nIdTmpFlusso + 1;
    ---------
    sRecord = rec.codice_fiscale_minore;                                            -- *	Codice fiscale minore
    sRecord = sRecord || ';' || rec.cognome_minore;                                 -- *	Cognome minore
    sRecord = sRecord || ';' || rec.nome_minore;                                    -- *	Nome minore
    sRecord = sRecord || ';' || sCodiceFiscaleRichiedente;                          -- *	Codice fiscale richiedente
    sRecord = sRecord || ';' || sCognomeRichiedente;                                -- *	Cognome richiedente
    sRecord = sRecord || ';' || sNomeRichiedente;                                   -- *	Nome richiedente
    sRecord = sRecord || ';' || rec.telefono;                                       -- *	Telefono
    sRecord = sRecord || ';' || TO_CHAR(rec.data_nascita_minore,'DD/MM/YYYY');      -- *	Data nascita minore
    sRecord = sRecord || ';' || rec.indirizzo_residenza;                            -- *	Indirizzo residenza
    sRecord = sRecord || ';' || rec.cap_residenza;                                  -- *	CAP
    sRecord = sRecord || ';' || rec.istat_comune_residenza;                         -- *	Codice istat comune di residenza
--    sRecord = sRecord || ';' || rec.valore_isee;                                  -- *	Valore ISEE
    sRecord = sRecord || ';' || rec.cod_nido_accettazione;                          -- *	Codice nido accettazione
    sRecord = sRecord || ';' || GetCodFasciaEta(rec.id_domanda_iscrizione);         -- *	Codice fascia d'eta'
    sRecord = sRecord || ';' || rec.cod_tipo_frequenza;                             -- *	Tempo di frequenza
    sRecord = sRecord || ';' || TO_CHAR(rec.inizio_anno_scolastico,'DD/MM/YYYY');   -- *	Data inizio anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.fine_anno_scolastico,'DD/MM/YYYY');     -- *	Data fine anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.data_accettazione,'DD/MM/YYYY');        -- *	Data accettazione
    sRecord = sRecord || ';';                                                       -- *	Esito trasferimento
    sRecord = sRecord || ';';                                                       -- *	Dettaglio errore
    sRecord = sRecord || ';' ||sCodiceParentela;                                    -- *	Tipo prichiedente
    sRecord = sRecord || ';' ||coalesce(rec.tipo_pasto,'');                         -- *	Tipo pasto
    sRecord = sRecord || ';' || rec.protocollo;                                     -- *	Protocollo
    --------
    INSERT INTO iscritto_tmp_flusso ( id_tmp_fusso, record )
      VALUES ( nIdTmpFlusso, sRecord );
     
    update iscritto_t_invio_acc 
    set dt_invio_sise=trunc(CURRENT_TIMESTAMP) 
    where id_accettazione_rin=rec.id_acc_rin;
  END LOOP;
  --------
  RETURN 0;
END;
$function$
;

--
--
DROP FUNCTION preparadatisisematerne();
--
CREATE OR REPLACE FUNCTION preparadatisisematerne()
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  rec RECORD;
  sCodiceFiscaleRichiedente   iscritto_t_anagrafica_sog.codice_fiscale%TYPE;
  sCognomeRichiedente         iscritto_t_anagrafica_sog.cognome%TYPE;
  sNomeRichiedente            iscritto_t_anagrafica_sog.nome%TYPE;
  nIdTmpFlusso                iscritto_tmp_flusso.id_tmp_fusso%TYPE;
  sRecord                     iscritto_tmp_flusso.record%TYPE;
  sCodiceParentela            iscritto_d_relazione_par.cod_parentela%TYPE;
BEGIN
  DELETE FROM iscritto_tmp_flusso;
  nIdTmpFlusso = 0;
  ---------
  FOR rec IN  SELECT  domIsc.id_domanda_iscrizione  id_domanda_iscrizione
                    , anagSog.codice_fiscale        codice_fiscale_minore
                    , anagSog.cognome               cognome_minore
                    , anagSog.nome                  nome_minore
                    , anagSog.data_nascita          data_nascita_minore
                    , invAcc.telefono               telefono
                    , invAcc.id_accettazione_rin    id_acc_rin
                    , indRes.indirizzo              indirizzo_residenza
                    , indRes.cap                    cap_residenza
                    , COALESCE(com.cod_catasto,sta.codice) istat_comune_residenza
--                    com.istat_comune              istat_comune_residenza
                    , scu.cod_scuola                cod_nido_accettazione
                    , tipFre.cod_tipo_frequenza     cod_tipo_frequenza
                    , annoSco.data_da               inizio_anno_scolastico
                    , annoSco.data_a                fine_anno_scolastico
                    , accRin.dt_operazione          data_accettazione
                    , tipPas.cod_tipo_pasto 		tipo_pasto
                    , domIsc.protocollo             protocollo
                FROM  iscritto_t_invio_acc        invAcc
                    left join iscritto_d_tipo_pasto tipPas on invAcc.id_tipo_pasto=tipPas.id_tipo_pasto
                    , iscritto_t_acc_rin          accRin
                    , iscritto_t_domanda_isc      domIsc
                    , iscritto_t_anagrafica_sog   anagSog
                    , iscritto_r_soggetto_rel     sogRel
                    , iscritto_d_tipo_sog         tipSog
                    , iscritto_t_indirizzo_res    indRes
                    left join iscritto_t_comune com on indRes.id_comune=com.id_comune
                    left join iscritto_t_stato sta on indRes.id_stato_residenza=sta.id_stato
                    , iscritto_t_scuola           scu
                    , iscritto_d_tipo_fre         tipFre
                    , iscritto_t_anno_sco         annoSco
                    , iscritto_d_categoria_scu    catScu
                 WHERE invAcc.id_accettazione_rin = accRin.id_accettazione_rin
                  AND accRin.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
                  AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                  AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                  AND tipSog.cod_tipo_soggetto = 'MIN'
                  AND anagSog.id_anagrafica_soggetto = indRes.id_anagrafica_soggetto
                  AND accRin.id_scuola = scu.id_scuola
                  AND accRin.id_tipo_frequenza = tipFre.id_tipo_frequenza
                  AND domIsc.id_anno_scolastico = annoSco.id_anno_scolastico
                  and SCU.id_categoria_scu=catScu.id_categoria_scu
                  and catScu.codice_categoria_scu <> 'P'
                  AND invAcc.dt_invio_sise IS NULL
  LOOP
    SELECT  anagSog.codice_fiscale
          , anagSog.cognome
          , anagSog.nome
          , relPar.cod_parentela
      INTO  sCodiceFiscaleRichiedente
          , sCognomeRichiedente
          , sNomeRichiedente
          , sCodiceParentela
      FROM  iscritto_t_anagrafica_sog   anagSog
          , iscritto_r_soggetto_rel     sogRel
          , iscritto_d_tipo_sog         tipSog
          , iscritto_d_relazione_par    relPar
      WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
        AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
        AND anagSog.id_domanda_iscrizione = rec.id_domanda_iscrizione
        AND tipSog.cod_tipo_soggetto = 'RIC'
        AND anagSog.id_rel_parentela=relPar.id_rel_parentela;
    nIdTmpFlusso = nIdTmpFlusso + 1;
    ---------
    sRecord = rec.codice_fiscale_minore;                                            -- *	Codice fiscale minore
    sRecord = sRecord || ';' || rec.cognome_minore;                                 -- *	Cognome minore
    sRecord = sRecord || ';' || rec.nome_minore;                                    -- *	Nome minore
    sRecord = sRecord || ';' || sCodiceFiscaleRichiedente;                          -- *	Codice fiscale richiedente
    sRecord = sRecord || ';' || sCognomeRichiedente;                                -- *	Cognome richiedente
    sRecord = sRecord || ';' || sNomeRichiedente;                                   -- *	Nome richiedente
    sRecord = sRecord || ';' || rec.telefono;                                       -- *	Telefono
    sRecord = sRecord || ';' || TO_CHAR(rec.data_nascita_minore,'DD/MM/YYYY');      -- *	Data nascita minore
    sRecord = sRecord || ';' || rec.indirizzo_residenza;                            -- *	Indirizzo residenza
    sRecord = sRecord || ';' || rec.cap_residenza;                                  -- *	CAP
    sRecord = sRecord || ';' || rec.istat_comune_residenza;                         -- *	Codice istat comune di residenza
--    sRecord = sRecord || ';' || rec.valore_isee;                                  -- *	Valore ISEE
    sRecord = sRecord || ';' || rec.cod_nido_accettazione;                          -- *	Codice nido accettazione
    sRecord = sRecord || ';' || GetCodFasciaEta(rec.id_domanda_iscrizione);         -- *	Codice fascia d'eta'
    sRecord = sRecord || ';' || rec.cod_tipo_frequenza;                             -- *	Tempo di frequenza
    sRecord = sRecord || ';' || TO_CHAR(rec.inizio_anno_scolastico,'DD/MM/YYYY');   -- *	Data inizio anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.fine_anno_scolastico,'DD/MM/YYYY');     -- *	Data fine anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.data_accettazione,'DD/MM/YYYY');        -- *	Data accettazione
    sRecord = sRecord || ';';                                                       -- *	Esito trasferimento
    sRecord = sRecord || ';';                                                       -- *	Dettaglio errore
    sRecord = sRecord || ';' ||sCodiceParentela;                                    -- *	Tipo prichiedente
    sRecord = sRecord || ';' ||coalesce(rec.tipo_pasto,'');                         -- *	Tipo pasto
    sRecord = sRecord || ';' || rec.protocollo;                                     -- *	Protocollo
    --------
    INSERT INTO iscritto_tmp_flusso ( id_tmp_fusso, record )
      VALUES ( nIdTmpFlusso, sRecord );
     
    update iscritto_t_invio_acc 
    set dt_invio_sise=trunc(CURRENT_TIMESTAMP) 
    where id_accettazione_rin=rec.id_acc_rin;
  END LOOP;
  --------
  RETURN 0;
END;
$function$
;
--
--
DROP FUNCTION punteggio(pcodcondizione character varying, piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio(pcodcondizione character varying, piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
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
  ELSIF pCodCondizione =  'RES_TO_FUT_NOTE' THEN                   -- E.F. 13/11/2019
    pRicorrenza = Punteggio_RES_TO_FUT_NOTE(pIdDomandaIscrizione); -- E.F. 13/11/2019
  ELSIF pCodCondizione =  'RES_NOTO_LAV' THEN
    pRicorrenza = Punteggio_RES_NOTO_LAV(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'RES_NOTO' THEN
    pRicorrenza = Punteggio_RES_NOTO(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'PA_DIS' THEN
    pRicorrenza = Punteggio_PA_DIS(pIdDomandaIscrizione);
  ELSIF pCodCondizione =  'PA_SOC' THEN
    pRicorrenza = Punteggio_PA_SOC(pIdDomandaIscrizione);
--  ELSIF pCodCondizione =  'PA_PRB_SAL' THEN                       E.F. 13/11/2019
--    pRicorrenza = Punteggio_PA_PRB_SAL(pIdDomandaIscrizione);     E.F. 13/11/2019
  ELSIF pCodCondizione =  'PA_PRB_SAL_MIN' then                  -- E.F. 13/11/2019   
    pRicorrenza = Punteggio_PA_PRB_SAL_MIN(pIdDomandaIscrizione);-- E.F. 13/11/2019
  ELSIF pCodCondizione =  'PA_PRB_SAL_ALT' then                  -- E.F. 13/11/2019
    pRicorrenza = Punteggio_PA_PRB_SAL_ALT(pIdDomandaIscrizione);-- E.F. 13/11/2019
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
      SELECT  *
      INTO  rec
      FROM  Punteggio_CF_FRA_FRE(pIdDomandaIscrizione);
    pRicorrenza = rec.pRicorrenza;
    pFlagValida = rec.pFlagvalida;
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
    pFlagValida = 'S';
  ELSIF pCodCondizione = 'TR_TRA_NID' THEN
    pRicorrenza = Punteggio_TR_TRA_NID(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'PAR_ISEE' THEN
    pRicorrenza = Punteggio_PAR_ISEE(pIdDomandaIscrizione);
  ELSEIF pCodCondizione = 'XT_PT_AGG' THEN
    pRicorrenza = punteggio_xt_pt_agg(pIdDomandaIscrizione);
  END IF;
END;
$function$
;

--
--
DROP FUNCTION rinuncia(pcodordinescuola character varying);
--
CREATE OR REPLACE FUNCTION rinuncia(pcodordinescuola character varying)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  vIdStepInCorso      iscritto_t_graduatoria.id_step_gra_con%TYPE;
  grad                RECORD;
  altreScuole         RECORD;
  classe              RECORD;
  vCancellatiRinuncia iscritto_t_graduatoria.id_graduatoria%TYPE;
  vIdAnnoScolastico   iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
BEGIN
  vIdStepInCorso = GetStepInCorso(pCodOrdineScuola);
  ----------
  FOR grad IN SELECT  gr.id_graduatoria         id_graduatoria
                    , gr.id_scuola              id_scuola
                    , gr.ordine_preferenza      ordine_preferenza
                    , gr.id_domanda_iscrizione  id_domanda_iscrizione
                    , gr.id_tipo_frequenza      id_tipo_frequenza
                FROM  iscritto_t_graduatoria  gr
                    , iscritto_d_stato_scu    statScu
                WHERE gr.id_stato_scu = statScu.id_stato_scu
                  AND statScu.cod_stato_scu = 'AMM'
                  AND gr.id_step_gra_con = vIdStepInCorso
  LOOP
    UPDATE  iscritto_t_graduatoria
      SET id_stato_scu = GetIdStatoScuola('RIN_AUTO')
      WHERE id_graduatoria = grad.id_graduatoria;
    UPDATE  iscritto_r_scuola_pre
      SET id_stato_scu = GetIdStatoScuola('RIN_AUTO')
        , dt_stato = CURRENT_TIMESTAMP
      WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
        AND id_scuola = grad.id_scuola
        AND id_tipo_frequenza = grad.id_tipo_frequenza;
    IF grad.ordine_preferenza = 1 THEN
      FOR altreScuole IN  SELECT  id_scuola
                                , id_tipo_frequenza
                            FROM  iscritto_t_graduatoria
                            WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
--                              AND id_stato_scu = GetIdStatoScuola('PEN') --CH207 da modificare da PEN a CAN_1SC dopo la modifica alla procedura dell'ammissione
                              AND id_stato_scu = GetIdStatoScuola('CAN_1SC')
                              AND id_step_gra_con = vIdStepInCorso
      LOOP
        /*
          *	Impostare per le scuole trovate lo stato di CANCELLATO PER RINUNCIA PRIMA SCELTA
          *	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu con lo stato corrispondente a CANCELLATO PER RINUNCIA PRIMA SCELTA. 
        */
        UPDATE  iscritto_t_graduatoria
          SET id_stato_scu = GetIdStatoScuola('CAN_R_1SC')
          WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
            AND id_scuola = altreScuole.id_scuola
            AND id_tipo_frequenza = altreScuole.id_tipo_frequenza
            AND id_step_gra_con = vIdStepInCorso;
        UPDATE  iscritto_r_scuola_pre
          SET id_stato_scu = GetIdStatoScuola('CAN_R_1SC')
            , dt_stato = CURRENT_TIMESTAMP
          WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
            AND id_scuola = altreScuole.id_scuola
            AND id_tipo_frequenza = altreScuole.id_tipo_frequenza;
        /*
          *	Impostare lo stato della domanda a RINUNCIATO
          *	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
        */
      END LOOP;
      /*
        *	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
      */
      UPDATE  iscritto_t_domanda_isc
        SET id_stato_dom = GetIdStatoDomanda('RIN')
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
    ELSE
      SELECT  COUNT(1)
        INTO  vCancellatiRinuncia
        FROM  iscritto_t_graduatoria
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
          AND id_graduatoria <> grad.id_graduatoria
          AND id_stato_scu IN ( GetIdStatoScuola('RIN') , GetIdStatoScuola('RIN_AUTO') )
          AND id_step_gra_con = vIdStepInCorso;
      IF vCancellatiRinuncia >= 2 THEN
        FOR altreScuole IN  SELECT  id_scuola
                                  , id_tipo_frequenza
                              FROM  iscritto_t_graduatoria
                              WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
                                AND id_stato_scu = GetIdStatoScuola('PEN') --CH207 da modificare da PEN a CAN_1SC dopo la modifica alla procedura dell'ammissione
                                AND id_step_gra_con = vIdStepInCorso
        LOOP
          /*
            *	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a CANCELLATO PER RINUNCIA.
          */
          UPDATE  iscritto_t_graduatoria
            SET id_stato_scu = GetIdStatoScuola('CAN_RIN')
            WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
              AND id_scuola = altreScuole.id_scuola
              AND id_tipo_frequenza = altreScuole.id_tipo_frequenza
              AND id_step_gra_con = vIdStepInCorso;
          UPDATE  iscritto_r_scuola_pre
            SET id_stato_scu = GetIdStatoScuola('CAN_RIN')
              , dt_stato = CURRENT_TIMESTAMP
            WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
              AND id_scuola = altreScuole.id_scuola
              AND id_tipo_frequenza = altreScuole.id_tipo_frequenza;
        END LOOP;
        /*
          *	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
        */
        UPDATE  iscritto_t_domanda_isc
          SET id_stato_dom = GetIdStatoDomanda('RIN')
          WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
      ELSE
        UPDATE  iscritto_t_domanda_isc
          SET id_stato_dom = GetIdStatoDomanda('GRA')
          WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
      END IF;
    END IF;
    -------
    /*
      7.	Eliminare i posti ammessi nelle classi ( uguale all'operazione che viene eseguita dalla function 'attribuisciposti' )
        *	Individuare l'anno scolastico e le scuole attraverso le tabelle messe in join: ISCRITTO_T_STEP_GRA_CON, ISCRITTO_T_STEP_GRA, ISCRITTO_T_ANAGRAFICA_GRA, ISCRITTO_T_SCUOLA filtrando per lo step in corso.
        *	Selezionare i record dalla tabella ISCRITTO_T_CLASSE filtrando per id_anno_scolastico, id__scuola individuati al passo precedente e per posti_ammessi<>0
        *	Per ogni record di ISCRITTO_T_CLASSE individuato impostare posti_liberi= posti_liberi+posti_ammessi e posti ammessi=0.
    */
    vIdAnnoScolastico = GetIdAnnoScolastico(vIdStepInCorso);
    FOR classe IN SELECT  id_classe
                        , posti_liberi
                        , posti_ammessi
                    FROM  iscritto_t_classe
                    WHERE id_anno_scolastico = vIdAnnoScolastico
                      AND id_scuola = grad.id_scuola
                      AND posti_ammessi <> 0
    LOOP
      UPDATE  iscritto_t_classe
        SET posti_liberi = classe.posti_liberi + classe.posti_ammessi
          , posti_ammessi = 0
        WHERE id_classe = classe.id_classe;
    END LOOP;
  END LOOP;
  -------
  -- 6.	Impostare il flag fl_ammissioni'S' nel record di tabella ISCRITTO_T_STEP_GRA per la graduatoria in corso
  UPDATE  iscritto_t_step_gra_con
    SET fl_ammissioni = 'S'
    WHERE id_step_gra_con = vIdStepInCorso;
  -------
  RETURN 0;
END;
$function$
;

--
--
DROP FUNCTION setdataultimaattribuzione(pdataultimaattribuzione date, pordinescuola integer);
--
CREATE OR REPLACE FUNCTION setdataultimaattribuzione(pdataultimaattribuzione date, pordinescuola integer)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
DECLARE
BEGIN
  UPDATE  iscritto_t_parametro
    SET dt_ult_attribuzione_con = pDataUltimaAttribuzione
    WHERE iscritto_t_parametro.id_ordine_scuola = pOrdineScuola;
  RETURN 0;
END;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION setdataultimocalcolopunteggio(pdataultimocalcolopunteggio timestamp without time zone, pidstepgracon integer);
--
CREATE OR REPLACE FUNCTION setdataultimocalcolopunteggio(pdataultimocalcolopunteggio timestamp without time zone, pidstepgracon integer)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
DECLARE
    ordineScuola                iscritto_t_parametro.id_ordine_scuola%TYPE;
BEGIN
   SELECT dom.id_ordine_scuola
    INTO ordineScuola
    FROM iscritto_t_graduatoria gr
       , iscritto_t_domanda_isc dom
       , iscritto_r_punteggio_dom puntDom
    WHERE gr.id_domanda_iscrizione = dom.id_domanda_iscrizione
      AND gr.id_domanda_iscrizione = puntDom.id_domanda_iscrizione
      AND gr.id_step_gra_con = pIdStepGraCon
    LIMIT 1;

  UPDATE  iscritto_t_parametro
    SET dt_ult_calcolo_pun = pDataUltimoCalcoloPunteggio
   WHERE iscritto_t_parametro.id_ordine_scuola = ordineScuola;
  RETURN 0;
END;
$body$
  VOLATILE
  COST 100;
--
--
DROP FUNCTION punteggio_xt_pt_agg(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_xt_pt_agg(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
  nIdScuola   INTEGER;
BEGIN
    SELECT id_scuola
    INTO nIdScuola
    FROM iscritto_r_scuola_pre
    WHERE iscritto_r_scuola_pre.id_domanda_iscrizione = piddomandaiscrizione
    AND iscritto_r_scuola_pre.posizione = 1;

    SELECT COUNT(1)
    INTO nRicorrenza
    FROM iscritto_r_punteggio_scu 
    WHERE iscritto_r_punteggio_scu.id_scuola = nIdScuola
    AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL;

  RETURN nRicorrenza;
END;
$function$
;

drop function inseriscidomandeingraduatoria(pidstepgraddacalcolare integer);
--
CREATE OR REPLACE FUNCTION inseriscidomandeingraduatoria(pidstepgraddacalcolare integer)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
DECLARE
  param   RECORD;
  domanda RECORD;
  scuola  RECORD;
  -------
  nRetCode            INTEGER;
  bRetCode            BOOLEAN;
BEGIN
  -- Leggo i parametro generali relativi allo step da calcolare
  SELECT  *
    INTO  param
    FROM  GetInfoStepGraduatoria(pIdStepGradDaCalcolare);
  -------
  FOR domanda IN  SELECT  dom.id_domanda_iscrizione   id_domanda_iscrizione
                        , dom.fl_fratello_freq        fl_fratello_freq
                    FROM  iscritto_t_domanda_isc    dom
                        , iscritto_d_stato_dom      stDom
                    WHERE dom.id_stato_dom = stDom.id_stato_dom
                      AND stDom.cod_stato_dom = 'INV'
                      AND dom.fl_istruita = 'S'
                      AND DATE_TRUNC('day',dom.data_consegna) BETWEEN DATE_TRUNC('day',param.pDataDomandaInvioDa) AND DATE_TRUNC('day',param.pDataDomandaInvioA)
  LOOP
    bRetCode = ValidaCondizioneCfFraIsc(domanda.id_domanda_iscrizione);
    -- Per questa domanda leggo tutte le scuole collegate
    FOR scuola IN SELECT  id_scuola
                        , fl_fuori_termine
                        , id_tipo_frequenza
                        , posizione
                    FROM  iscritto_r_scuola_pre
                    WHERE id_domanda_iscrizione = domanda.id_domanda_iscrizione
    LOOP
      -- Per ogni scuola della domanda inserisco in record
      INSERT INTO iscritto_t_graduatoria
                  ( id_graduatoria
                  , id_step_gra_con
                  , id_scuola
                  , id_domanda_iscrizione
                  , fl_fuori_termine
                  , id_tipo_frequenza
                  , id_stato_scu
                  , isee
                  , ordine_preferenza
                  , id_fascia_eta
                  )
        VALUES  ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
                , pIdStepGradDaCalcolare
                , scuola.id_scuola
                , domanda.id_domanda_iscrizione
                , scuola.fl_fuori_termine
                , scuola.id_tipo_frequenza
                , GetIdStatoScuola('PEN')
                , GetValoreIsee(domanda.id_domanda_iscrizione)
                , scuola.posizione
                , GetIdFasciaEta(domanda.id_domanda_iscrizione)
                );
    END LOOP;
  END LOOP;
  --------
  RETURN 0;
END;
$body$
  VOLATILE
  COST 100;
  
commit;
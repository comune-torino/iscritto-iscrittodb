----------------------------------------------------------------------
-- 2020-05-28 -- Stored
----------------------------------------------------------------------
DROP FUNCTION attribuiscicondizioni(pcodordinescuola character varying, pdatada date, pdataa date);
--
CREATE OR REPLACE FUNCTION iscritto.attribuiscicondizioni(pcodordinescuola character varying, pdatada date, pdataa date)
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
              Se tutte le condizioni di punteggio associate alla domanda che sono legate al tipo di istruttoria ‘Preventiva’ sono state tutte istruite occorre settare il flag di domanda istruita della domanda.
              1.	Selezionare tutte le condizioni di punteggio della domanda che hanno l’istruttoria preventiva.
              Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM con filtro: id_domanda_iscrizione, dt_fine_validita=NULL e fl_validita=NULL e id_condizione_punteggio che ha fl_istruttoria=’P’ nel record della tabella ISCRITTO_D_CONDIZIONE_PUNTEGGIO.
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
              2.	Se sono non sono stati trovati record si imposta il flag ISCRITTO_T_DOMANDA_ISC.fl_istruita=’S’
            */
            IF NOT vFound THEN
                UPDATE iscritto_t_domanda_isc
                SET fl_istruita = 'S'
                WHERE id_domanda_iscrizione = nIdDomandaIscrizione;
            END IF;
        END LOOP;
    /*
        1.	Verificare se la sysdate è minore della alla data limite per la considerazione degli allegati
      •	Eseguire una query sulla tabella ISCRITTO_T_STEP_GRA filtrando per dt_step_gra <= sysdate e id_anagrafica_gra corrispondente alle graduatorie
          appartenenti all’ordine scolastico passato come parametro e ordinare per dt_step_gra discendente.
      •	Se dt_allegati del primo record della query è >= sysdate si procede al punto 2, altrimenti la procedura termina.
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
5. Se è stato inserito un nuovo record nella tabella ISCRITTO_R_PUNTEGGIO_DOM allora occorre resettare il flag di domanda istruita della domanda:
• Impostare ISCRITTO_T_DOMANDA_ISC.fl_istruita=’N’
*/
                    UPDATE iscritto_t_domanda_isc
                    SET fl_istruita = 'N'
                    WHERE id_domanda_iscrizione = alleg.id_domanda_iscrizione;
                END IF;
            END LOOP;
    END IF;
-------
    nRetCode = SetDataUltimaAttribuzione(dDataA);
-------
    RETURN 0;
END;
$function$
;

-- ----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION gettestosmsammissione(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION iscritto.gettestosmsammissione(piddomandaiscrizione integer)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
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
      AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
      and pre.id_domanda_iscrizione = anagsog.id_domanda_iscrizione 
      and pre.id_stato_scu = GetIdStatoScuola('AMM')
      and scu.id_scuola    = pre.id_scuola 
      AND anagSog.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipSog.cod_tipo_soggetto = 'MIN';
     
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
$function$
;

-- ----------------------------------------------------------------------------------------------------------------------------------



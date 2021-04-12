----------------------------------------------------------------------------------------------------------------------
DROP FUNCTION calcolapunteggiodomanda(piddomandaiscrizione integer, pidstepgracon integer);
--
CREATE OR REPLACE FUNCTION calcolapunteggiodomanda(piddomandaiscrizione integer, pidstepgracon integer)
  RETURNS smallint
  LANGUAGE plpgsql
AS
$body$
DECLARE
    scuola                       RECORD;
    cond                         RECORD;
    -----
    vPunteggio                   iscritto_t_graduatoria.punteggio%TYPE;
    vPunteggioSpecifico          iscritto_r_punteggio_scu.punti_scuola%TYPE;
    vValoreIsee                  iscritto_t_isee.valore_isee%TYPE;
    nIdDomandaIscrizioneFratello iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
    vIdScuolaFratello            iscritto_r_scuola_pre.id_scuola%TYPE;
    vControll                    INTEGER;
    vResult                      INTEGER;
    vPuntiExtra                  INTEGER;
    vPuntiExtraBis               INTEGER;
    vControlloScuola             INTEGER;

BEGIN
    -- 2.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per id_domanda_isc, per d_fine_validita= NULL e per fl_valida <> N
    -- 4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio e
    --      sysdate tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
    -- 5.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_SCU con id_punteggio dalla query precedente
    --      e sysdate tra dt_inizio_validita e dt_fine_validita . Questo per ricavare gli eventuali punteggi specifici per ogni scuola
    --      della condizione di punteggio presa in considerazione.
    -- 4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio e
    --  sysdate tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
    FOR scuola IN SELECT DISTINCT id_scuola         id_scuola
                                , posizione         posizione
                                , id_tipo_frequenza id_tipo_frequenza
                                , fl_fuori_termine  fl_fuori_termine
                  FROM iscritto_r_scuola_pre
                  WHERE id_domanda_iscrizione = pIdDomandaIscrizione
        LOOP
            vPunteggio = 0;
            FOR cond IN SELECT condPun.cod_condizione                                          cod_condizione
                             , puntDom.ricorrenza                                              ricorrenza
                             , GetPunteggio(scuola.id_scuola, puntDom.id_condizione_punteggio) punteggio
                        FROM iscritto_r_punteggio_dom puntDom
                           , iscritto_d_condizione_pun condPun
                        WHERE puntDom.id_condizione_punteggio = condPun.id_condizione_punteggio
                          AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
                          AND puntDom.dt_fine_validita IS NULL
                          AND COALESCE(puntDom.fl_valida, ' ') <> 'N'
                LOOP

                    IF cond.cod_condizione = 'CF_FRA_FRE' THEN
                        /*  Se per questa condizione il valore nel campo ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 1 ( FREQ )
                            allora il punteggio di questa condizione deve essere preso in considerazione solo per la scuola di prima scelta
                            ( ISCRITTO_R_SCUOLA_PRE.POSIZIONE=1 ).
                        */
                        IF FratelloFrequentante(pIdDomandaIscrizione) THEN
                            IF scuola.posizione = 1 THEN
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                            END IF;
                        END IF;
                    ELSIF cond.cod_condizione = 'CF_FRA_ISC' THEN
                        /*  Se per questa condizione il valore nel campo ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 2 ( ISCR ) allora il punteggio di questa
                            condizione deve essere preso in considerazione solo per le scuole di preferenza scelte da entrambe le domande:
                              *	Domanda 1 quella sottoposta al calcolo del punteggio
                              *	Domanda 2 quella in cui ISCRITTO_T_FRATELLO_FRE.cf_fratello della domanda 1 e' uguale a ISCRITTO_T_ANAGRAFICA_SOG.codice_fiscale
                                del minore della domanda 2.
                              Esempio:
                                1a scelta 	2a scelta	3a scelta
                                      Domanda 1	Scuola 1	Scuola 2
                                      Domanda 2	Scuola 2	Scuola 3	Scuola 1
                                Nell'esempio riportato la Scuola 1 e la scuola 2 avranno i punti per la condizione di punteggio CF_FRA_ISC per entrambe
                                le domande mentre non ce l'avra' la scuola 3.
                        */
                        IF FratelloIscrivendo(pIdDomandaIscrizione) THEN
                            nIdDomandaIscrizioneFratello = GetIdDomandaIscrizioneFratello(pIdDomandaIscrizione);
                            IF EsistePreferenzaScuola(nIdDomandaIscrizioneFratello, scuola.id_scuola) THEN
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                            END IF;
                        END IF;
                        --start mod BB
                    ELSEIF cond.cod_condizione = 'RES_TO_EXTRA' THEN
                        IF scuola.posizione = 1 THEN
                            vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                        END IF;
                    ELSEIF cond.cod_condizione = 'XT_PT_AGG' THEN
                        IF scuola.posizione = 1 THEN
                            vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                        END IF;
                    ELSIF cond.cod_condizione = 'CF_FRA_FRE_MAT' THEN
                        IF FratelloFrequentante(pIdDomandaIscrizione) THEN
                            IF scuola.posizione = 1 THEN
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                            END IF;
                        END IF;
                    ELSIF cond.cod_condizione = 'CF_FRA_FRE_MAT_EXTRA' THEN
                        --aggiornamento, applicare logica solo se in prima scelta
                        if (scuola.posizione = 1) then

                            --filtrare la tabella ISCRITTO_R_PUNTEGGIO_DOM per l'id_domanda_iscrizione, e per l'id del codice di punteggio CF_FRA_FRE_MAT e per fl_valida = TRUE e per dt_fine_validita a NULL
                            SELECT COUNT(1)
                            INTO vResult
                            FROM iscritto_r_punteggio_dom
                            WHERE id_domanda_iscrizione = piddomandaiscrizione
                              AND id_condizione_punteggio = 31 --CF_FRA_FRE_MAt
                              AND fl_valida = 'S'
                              AND dt_fine_validita is null;

                            if (vResult > 0) then
                                -- se ci sono record
                                -- eseguire un update sul campo fl_valida= S della tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per l'id_domanda_iscrizione, e per l'id del codice di punteggio CF_FRA_FRE_MAT_EXTRA e per dt_fine_validita a NULL
                                UPDATE iscritto_r_punteggio_dom
                                SET fl_valida = 'S'
                                WHERE id_domanda_iscrizione = piddomandaiscrizione
                                  AND id_condizione_punteggio = 35 --CF_FRA_FRE_MAT_EXTRA
                                  AND dt_fine_validita is null;
                                -- Aggiungere il punteggio previsto per la condizione di punteggio CF_FRA_FRE_MAT_EXTRA
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                                -- Filtrare la tabella ISCRITTO_R_PUNTEGGIO_DOM per l'id_domanda_iscrizione, e per l'id del codice di punteggio RES_NOTO e per fl_valida = TRUE e per dt_fine_validita a NULL
                                vResult = 0;
                                SELECT COUNT(1)
                                INTO vResult
                                FROM iscritto_r_punteggio_dom
                                WHERE id_domanda_iscrizione = piddomandaiscrizione
                                  AND id_condizione_punteggio = 3 --RES_NOTO
                                  AND fl_valida = 'S'
                                  AND dt_fine_validita is null;

                                if (vResult > 0) then
                                    -- Se trovato record aggiungere i punti restituiti dalla function GetPunteggio passando come parametri l'id della scuola che si sta processando e il codice di punteggio uguale a RES_TO e la modifica termina.
                                    vPuntiExtra = getpunteggio(scuola.id_scuola, 1);
                                    vPunteggio = vPunteggio + vPuntiExtra;
                                else
                                    -- Se non ho trovato record Filtrare la tabella ISCRITTO_R_PUNTEGGIO_DOM per l'id_domanda_iscrizione, e per l'id del codice di punteggio RES_NOTO_LAV e per fl_valida = TRUE e per dt_fine_validita a NULL
                                    vResult = 0;
                                    SELECT COUNT(1)
                                    INTO vResult
                                    FROM iscritto_r_punteggio_dom
                                    WHERE id_domanda_iscrizione = piddomandaiscrizione
                                      AND id_condizione_punteggio = 2 --RES_NOTO_LAV
                                      AND (fl_valida is null or fl_valida ='S') 
                                      AND dt_fine_validita is null;

                                    if (vResult > 0) then
                                        -- Se trovato record aggiungere i punti restituiti dalla function GetPunteggio passando come parametri l'id della scuola che si sta processando e il codice di punteggio uguale a RES_TO meno i punti restituiti dalla function GetPunteggio passando come parametri l'id della scuola che si sta processando e il codice di punteggio uguale a RES_NOTO_LAV.
                                        vPuntiExtra = getpunteggio(scuola.id_scuola, 1);
                                        vPuntiExtraBis = getpunteggio(scuola.id_scuola, 2);
                                        vPunteggio = vPunteggio + (vPuntiExtra - vPuntiExtraBis);
                                    end if;
                                end if;

                            else
                                -- se non ci sono record
                                -- eseguire un update sul campo fl_valida= N della tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per l'id_domanda_iscrizione, e per l'id del codice di punteggio CF_FRA_FRE_MAT_EXTRA e per dt_fine_validita a NULL non aggiungere punteggio
                                UPDATE iscritto_r_punteggio_dom
                                SET fl_valida = 'N'
                                WHERE id_domanda_iscrizione = piddomandaiscrizione
                                  AND id_condizione_punteggio = 35 --CF_FRA_FRE_MAT_EXTRA
                                  AND dt_fine_validita is null;

                            end if;


                        end if;
                    ELSIF cond.cod_condizione = 'CF_FRA_FRE_MAT_AGG' THEN
                        --aggiornamento, applicare logica solo se in prima scelta
                        if (scuola.posizione = 1) then

                            --filtrare la tabella ISCRITTO_R_PUNTEGGIO_DOM per l'id_domanda_iscrizione, e per l'id del codice di punteggio CF_FRA_FRE_MAT e per fl_valida = TRUE e per dt_fine_validita a NULL
                            SELECT COUNT(1)
                            INTO vResult
                            FROM iscritto_r_punteggio_dom
                            WHERE id_domanda_iscrizione = piddomandaiscrizione
                              AND id_condizione_punteggio = 31 --CF_FRA_FRE_MAt
                              AND fl_valida = 'S'
                              AND dt_fine_validita is null;

                            if (vResult > 0) then
                                -- se ci sono record
                                -- eseguire un update sul campo fl_valida= S della tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per l'id_domanda_iscrizione, e per l'id del codice di punteggio CF_FRA_FRE_MAT_EXTRA e per dt_fine_validita a NULL
                                UPDATE iscritto_r_punteggio_dom
                                SET fl_valida = 'S'
                                WHERE id_domanda_iscrizione = piddomandaiscrizione
                                  AND id_condizione_punteggio = 36 --CF_FRA_FRE_MAT_AGG
                                  AND dt_fine_validita is null;
                                -- Aggiungere il punteggio previsto per la condizione di punteggio CF_FRA_FRE_MAT_AGG
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                            else
                                -- se non ci sono record
                                -- eseguire un update sul campo fl_valida= N della tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per l'id_domanda_iscrizione, e per l'id del codice di punteggio CF_FRA_FRE_MAT_AGG e per dt_fine_validita a NULL non aggiungere punteggio
                                UPDATE iscritto_r_punteggio_dom
                                SET fl_valida = 'N'
                                WHERE id_domanda_iscrizione = piddomandaiscrizione
                                  AND id_condizione_punteggio = 36 --CF_FRA_FRE_MAT_AGG
                                  AND dt_fine_validita is null;
                            end if;
                        end if;
                    ELSIF cond.cod_condizione = 'CF_FRA_ISC_MAT' THEN
                        IF FratelloIscrivendo(pIdDomandaIscrizione) THEN
                            if Fratelloiscrivendomeno5(piddomandaiscrizione) then
                                --Verifico se e' presente un'altra domanda per l'iscrivendo con lo stesso anno scolastico della domanda per la quale si sta calcolando il punteggio.
                                --Se la trovo assegno il punteggio a tutte le preferenze corrispondenti tra le due domande, altrimenti
                                nIdDomandaIscrizioneFratello = GetIdDomandaIscrizioneFratello(pIdDomandaIscrizione);
                                IF EsistePreferenzaScuola(nIdDomandaIscrizioneFratello, scuola.id_scuola) THEN
                                    vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                                END IF;
                            else
                                IF scuola.posizione = 1 THEN
                                    vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                                END IF;
                            end if;
                        END IF;
                    ELSIF cond.cod_condizione = 'CF_FRA_ISC_MAT_EXTRA' THEN
                        vControll = 0;
                        IF scuola.posizione = 1 THEN
                            if Fratelloiscrivendomeno5(piddomandaiscrizione) then
                                nIdDomandaIscrizioneFratello = GetIdDomandaIscrizioneFratello(pIdDomandaIscrizione);
                                vControlloScuola = 0;
                                SELECT COUNT(1)
                                INTO vControlloScuola
                                FROM iscritto_r_scuola_pre
                                WHERE id_domanda_iscrizione = nIdDomandaIscrizioneFratello
                                  AND id_scuola = scuola.id_scuola;

                                if (vControlloScuola > 0) then
                                    vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                                end if;
                            else
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                            end if;

                            vResult = 0;
                            SELECT COUNT(1)
                            INTO vResult
                            FROM iscritto_r_punteggio_dom
                            WHERE id_domanda_iscrizione = piddomandaiscrizione
                              AND id_condizione_punteggio = 3 --RES_NOTO
                              AND fl_valida = 'S'
                              AND dt_fine_validita is null;

                            if (vResult > 0) then
                                -- Se trovato record aggiungere i punti restituiti dalla function GetPunteggio passando come parametri l'id della scuola che si sta processando e il codice di punteggio uguale a RES_TO e la modifica termina.
                                vPuntiExtra = getpunteggio(scuola.id_scuola, 1);
                                vPunteggio = vPunteggio + vPuntiExtra;
                            else
                                -- Se non ho trovato record Filtrare la tabella ISCRITTO_R_PUNTEGGIO_DOM per l'id_domanda_iscrizione, e per l'id del codice di punteggio RES_NOTO_LAV e per fl_valida = TRUE e per dt_fine_validita a NULL
                                vResult = 0;
                                SELECT COUNT(1)
                                INTO vResult
                                FROM iscritto_r_punteggio_dom
                                WHERE id_domanda_iscrizione = piddomandaiscrizione
                                  AND id_condizione_punteggio = 2 --RES_NOTO_LAV
                                  AND (fl_valida is null or fl_valida ='S')  
                                  AND dt_fine_validita is null;

                                if (vResult > 0) then
                                    -- Se trovato record aggiungere i punti restituiti dalla function GetPunteggio passando come parametri l'id della scuola che si sta processando e il codice di punteggio uguale a RES_TO meno i punti restituiti dalla function GetPunteggio passando come parametri l'id della scuola che si sta processando e il codice di punteggio uguale a RES_NOTO_LAV.
                                    vPuntiExtra = getpunteggio(scuola.id_scuola, 1);
                                    vPuntiExtraBis = getpunteggio(scuola.id_scuola, 2);
                                    vPunteggio = vPunteggio + (vPuntiExtra - vPuntiExtraBis);
                                end if;
                            end if;


                        END IF;
                    ELSIF cond.cod_condizione = 'CF_FRA_ISC_MAT_AGG' THEN
                        IF scuola.posizione = 1 THEN
                            if Fratelloiscrivendomeno5(piddomandaiscrizione) then
                                nIdDomandaIscrizioneFratello = GetIdDomandaIscrizioneFratello(pIdDomandaIscrizione);
                                vControlloScuola = 0;
                                SELECT COUNT(1)
                                INTO vControlloScuola
                                FROM iscritto_r_scuola_pre
                                WHERE id_domanda_iscrizione = nIdDomandaIscrizioneFratello
                                  AND id_scuola = scuola.id_scuola;

                                if (vControlloScuola > 0) then
                                    vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                                end if;
                            else
                                vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                            end if;

                        END IF;
                        --end mod BB
                    ELSE
                        vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
                    END IF;
                END LOOP;
            -- 7.	Eseguire l'update del campo ISCRITTO_T_GRADUATORIA.punteggio con il valore calcolato
            -- al punto precedente per ogni singola scuola della domanda.
            SELECT CASE WHEN COALESCE(puntDom.fl_valida, 'S') = 'N' THEN NULL ELSE isee.valore_isee END
            INTO vValoreIsee
            FROM iscritto_r_punteggio_dom puntDom
               , iscritto_t_isee isee
            WHERE puntDom.id_domanda_iscrizione = isee.id_domanda_iscrizione
              AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
              AND puntDom.id_condizione_punteggio = GetIdCondizionePunteggio('PAR_ISEE')
              AND dt_fine_validita IS NULL;
            UPDATE iscritto_t_graduatoria
            SET punteggio        = vPunteggio
              , isee             = vValoreIsee
              , fl_fuori_termine = scuola.fl_fuori_termine
            WHERE id_domanda_iscrizione = pIdDomandaIscrizione
              AND id_scuola = scuola.id_scuola
              AND id_step_gra_con = pIdStepGraCon
              AND id_tipo_frequenza = scuola.id_tipo_frequenza;
        END LOOP;
    -------
    RETURN 0;
END;
$body$
  VOLATILE
  COST 100;
  
----------------------------------------
  
DROP FUNCTION getiddomandaiscrizionefratello(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION getiddomandaiscrizionefratello(piddomandaiscrizione integer)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
DECLARE
  nIdDomandaIscrizioneFratello  iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
BEGIN
  SELECT  DISTINCT
            anagSog2.id_domanda_iscrizione
    INTO  nIdDomandaIscrizioneFratello
    FROM  iscritto_t_anagrafica_sog   anagSog1
        , iscritto_t_fratello_fre     fraFre
        , iscritto_t_anagrafica_sog   anagSog2
        , iscritto_t_domanda_isc      dom1
        , iscritto_t_domanda_isc      dom2
        , iscritto_r_soggetto_rel     relSog2
        , iscritto_d_tipo_sog         tipSog2
    WHERE anagSog1.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND UPPER(fraFre.cf_fratello) = UPPER(anagSog2.codice_fiscale)
      AND anagSog2.id_anagrafica_soggetto = relSog2.id_anagrafica_soggetto
      AND relSog2.id_tipo_soggetto = tipSog2.id_tipo_soggetto
      AND tipSog2.cod_tipo_soggetto = 'MIN'
      AND anagSog1.id_domanda_iscrizione = pIdDomandaIscrizione
      and anagSog1.id_domanda_iscrizione=dom1.id_domanda_iscrizione
      and anagSog2.id_domanda_iscrizione=dom2.id_domanda_iscrizione
      and dom1.id_anno_scolastico=dom2.id_anno_scolastico
      and dom2.id_stato_dom not in (1,3,9);
  --------
  RETURN nIdDomandaIscrizioneFratello;
END;
$body$
  VOLATILE
  COST 100;
  
----------------------------------------

DROP FUNCTION attribuisciposti(pidstepgraduatoriacon integer);
--
CREATE OR REPLACE FUNCTION attribuisciposti(pidstepgraduatoriacon integer)
  RETURNS smallint
  LANGUAGE plpgsql
AS
$body$
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
  FOR scuola IN SELECT  id_scuola
                  FROM  iscritto_t_scuola
                  WHERE id_ordine_scuola=getidordinescuola_dastep(pIdStepGraduatoriaCon)
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
  
/*EA JIRA ISCRITTO-67    -- ATTRIBUZIONE POSTI LIBERI
  FOR fascia IN SELECT  id_fascia_eta
                  FROM  iscritto_d_fascia_eta
                  WHERE id_ordine_scuola=getidordinescuola_dastep(pIdStepGraduatoriaCon)
                  order by cod_fascia_eta
 --                 ORDER BY CASE WHEN cod_fascia_eta = 'L' THEN 1
 --                               WHEN cod_fascia_eta = 'P' THEN 2
 --                               WHEN cod_fascia_eta = 'G' THEN 3
 --                          END
  LOOP*/
 
    DELETE FROM iscritto_tmp_domanda;
    --------
    FOR grad IN SELECT  id_graduatoria
                      , id_domanda_iscrizione
                      , id_scuola
                      , id_tipo_frequenza
                      , ordine_preferenza
                      , id_fascia_eta --EA JIRA ISCRITTO-67  
                  FROM  iscritto_t_graduatoria
                  WHERE id_step_gra_con = pIdStepGraduatoriaCon
                   -- AND id_fascia_eta = fascia.id_fascia_eta  --EA JIRA ISCRITTO-67  
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
              --AND eta.id_fascia_eta = fascia.id_fascia_eta --EA JIRA ISCRITTO-67  
              AND eta.id_fascia_eta = grad.id_fascia_eta   --EA JIRA ISCRITTO-67  
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
  --END LOOP;  --EA JIRA ISCRITTO-67  
  -------
  RETURN 0;
END;
$body$
  VOLATILE
  COST 100;
----------------------------------------

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
  vOrdineScuola         iscritto_t_domanda_isc.id_ordine_Scuola%type;--EA JIRA ISCRITTO-68
begin
	--EA JIRA ISCRITTO-68
	select id_ordine_scuola
	into vOrdineScuola
	from iscritto_t_domanda_isc
	where id_domanda_iscrizione=piddomandaiscrizione;
	
  select  TRIM(SCU.indirizzo), --anagSog.id_domanda_iscrizione,TRIM(anagSog.nome) , 
          -- EA JIRA ISCRITTO-68 REPLACE( par.testo_sms_amm , 'gg/mm/yyyy', TO_CHAR(NextSunday(CURRENT_DATE+1),'DD/MM/YYYY') )
             case when vOrdineScuola = 1 THEN REPLACE( par.testo_sms_amm , 'gg/mm/yyyy', TO_CHAR(NextSunday(CURRENT_DATE+1),'DD/MM/YYYY') )
                       else REPLACE( par.testo_sms_amm , 'gg/mm/yyyy', TO_CHAR(Nexttuesday(CURRENT_DATE+1),'DD/MM/YYYY') )
                       end
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
----------------------------------------

DROP FUNCTION fratelloiscrivendomeno5(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION fratelloiscrivendomeno5(piddomandaiscrizione integer)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
-- la function serve a verificare se il fratello e' di un altro ordine scolastico    
DECLARE
  vCodiceFisc          char(16);
  vDataNascitaFratello date;
  vData                date;

BEGIN
    -- Prelevo codice fiscale fratello
    SELECT fraFre.cf_fratello
    into vCodiceFisc
    FROM iscritto_t_domanda_isc domIsc
       , iscritto_t_fratello_fre fraFre
       , iscritto_d_tipo_fra tipFra
    WHERE domIsc.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND domIsc.id_domanda_iscrizione = pIdDomandaIscrizione
      AND fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
      AND domIsc.fl_fratello_freq = 'S'
      AND tipFra.cod_tipo_fratello = 'ISCR'
    group by fraFre.cf_fratello;

    if (vCodiceFisc is not null) then

        --recupero data di nascita del fratello dal cf
        SELECT data_nascita
        INTO vDataNascitaFratello
        FROM iscritto_t_anagrafica_sog
        WHERE upper(codice_fiscale) = upper(vCodiceFisc);

        --verifico e' nello stesso ordinamento
        select min(e.data_da)
        into vData
        from iscritto_t_eta e
        join iscritto_t_anagrafica_gra ag on ag.id_anagrafica_gra = e.id_anagrafica_gra
        join iscritto_t_domanda_isc d on d.id_anno_scolastico = ag.id_anno_scolastico
        and d.id_ordine_scuola = ag.id_ordine_scuola
        where d.id_domanda_iscrizione = piddomandaiscrizione;

        IF (vDataNascitaFratello < vData) THEN
            --l'iscrivendo e' di un altro ordine scolastico
            return false;
        else
            --l'iscrivendo e' nella materna
            return true;
        END IF;
  end if;
  END;
$function$
;

----------------------------------------

drop FUNCTION nexttuesday(pdata date);
--
CREATE OR REPLACE FUNCTION nexttuesday(pdata date)
  RETURNS date
  LANGUAGE plpgsql
AS
$body$
DECLARE
  dData   DATE;
BEGIN
  dData = pData;
  WHILE EXTRACT(DOW FROM dData) <> 2
  LOOP
    dData = dData + 1;
  END LOOP;
  --------
  RETURN dData;
END;
$body$
  VOLATILE
  COST 100;
----------------------------------------
----------------------------------------
----------------------------------------
  
----------------------------------------------------------------------------------------------------------------------

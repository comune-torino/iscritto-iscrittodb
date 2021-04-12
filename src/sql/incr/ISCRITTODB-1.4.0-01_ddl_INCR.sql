CREATE OR REPLACE
FUNCTION CalcolaPunteggioDomanda  ( pIdDomandaIscrizione  INTEGER
                                  , pIdStepGraCon         INTEGER
                                  ) RETURNS SMALLINT AS
$BODY$
DECLARE
  scuola  RECORD;
  cond    RECORD;
  -----
  vPunteggio          iscritto_t_graduatoria.punteggio%TYPE;
  vPunteggioSpecifico iscritto_r_punteggio_scu.punti_scuola%TYPE;
  vValoreIsee         iscritto_t_isee.valore_isee%TYPE;
BEGIN
  -- 2.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per id_domanda_isc, per d_fine_validita= NULL e per fl_valida <> N
  -- 4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio e
  --      sysdate tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
  -- 5.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_SCU con id_punteggio dalla query precedente
  --      e sysdate tra dt_inizio_validita e dt_fine_validita . Questo per ricavare gli eventuali punteggi specifici per ogni scuola
  --      della condizione di punteggio presa in considerazione.
  -- 4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio e
  --  sysdate tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
  FOR scuola IN SELECT  DISTINCT
                          id_scuola           id_scuola
                        , posizione           posizione
                        , id_tipo_frequenza   id_tipo_frequenza
                  FROM  iscritto_r_scuola_pre
                  WHERE id_domanda_iscrizione = pIdDomandaIscrizione
  LOOP
    vPunteggio = 0;
    FOR cond IN SELECT  condPun.cod_condizione                                          cod_condizione
                      , puntDom.ricorrenza                                              ricorrenza
                      , GetPunteggio(scuola.id_scuola,puntDom.id_condizione_punteggio)  punteggio
                  FROM  iscritto_r_punteggio_dom    puntDom
                      , iscritto_d_condizione_pun   condPun
                  WHERE puntDom.id_condizione_punteggio = condPun.id_condizione_punteggio
                    AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
                    AND puntDom.dt_fine_validita IS NULL
                    AND COALESCE(puntDom.fl_valida,' ') <> 'N'
    LOOP
      IF cond.cod_condizione = 'CF_FRA_FRE' THEN
        IF FratelloFrequentante(pIdDomandaIscrizione) THEN
          IF scuola.posizione = 1 THEN
            vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
          END IF;
        END IF;
      ELSE
        vPunteggio = vPunteggio + cond.punteggio * cond.ricorrenza;
      END IF;
    END LOOP;
    -- 7.	Eseguire l’update del campo ISCRITTO_T_GRADUATORIA.punteggio con il valore calcolato
    -- al punto precedente per ogni singola scuola della domanda.
    SELECT  CASE WHEN COALESCE(puntDom.fl_valida,'S') = 'N' THEN NULL ELSE isee.valore_isee END
      INTO  vValoreIsee
      FROM  iscritto_r_punteggio_dom  puntDom
          , iscritto_t_isee           isee
      WHERE puntDom.id_domanda_iscrizione = isee.id_domanda_iscrizione
        AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
        AND puntDom.id_condizione_punteggio = GetIdCondizionePunteggio('PAR_ISEE')
        AND dt_fine_validita IS NULL;
    UPDATE  iscritto_t_graduatoria
      SET punteggio = vPunteggio
        , isee = vValoreIsee
      WHERE id_domanda_iscrizione = pIdDomandaIscrizione
        AND id_scuola = scuola.id_scuola
        AND id_step_gra_con = pIdStepGraCon
        AND id_tipo_frequenza = scuola.id_tipo_frequenza;
  END LOOP;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
/*
RINUNCE AUTOMATICHE
Se l’utente non conferma il posto che le è stato assegnato viene posto a rinunciato automaticamente da questa procedura.
Procedura batch eseguita settimanalmente verso le 00:15 del Lunedì eseguita con il parametro id_ordine_scuola valorizzato a 1 per i NIDI o 2 per le MATERNE.
-	DA STATO AMMESSO A STATO RINUNCIATO
Tutti i nidi dello step che hanno lo stato AMMESSO occorre portarli in RINUNCIA AUTOMATICA.
1.	Selezionare tutte le domande in graduatoria in stato AMMESSO per lo step in corso e impostare per ogni una di esse lo stato RINUNCIA AUTOMATICA: 
•	Selezionare i record ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente ad AMMESSO, ISCRITTO_T_GRADUATORIA.id_step_gra=ISCRITTO_T_PARAMETRO.step_in_corso
•	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu con lo stato corrispondente a RINUNCIA AUTOMATICA     
2.	Per ogni record selezionato al punto 1 verificare se la scuola è quella di prima scelta:
•	ISCRITTO_T_GRADUATORIA.ordine_preferenza=1
3.	Se la condizione al punto 2 è verificata occorre inserire lo stato CANCELLAZIONE PER RINUNCIA PRIMA SCELTA per le altre scuole della domanda che sono ancora nello stato di PENDENTE:
•	Selezione delle altre scuole della domanda:
•	ISCRITTO_T_GRADUATORIA.id_domanda_iscrizione= id_iscrizione della domanda  posta a RINUNCIA AUTOMATICA e ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a PENDENTE e sempre ISCRITTO_T_GRADUATORIA.id_step_gra dello step in corso.
•	Impostare per le scuole trovate lo stato di CANCELLATO PER RINUNCIA PRIMA SCELTA
•	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu con lo stato corrispondente a CANCELLATO PER RINUNCIA PRIMA SCELTA. 
•	Impostare lo stato della domanda a RINUNCIATO
•	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
4.	Se la condizione 2 non è verificata occorre verificare se per la domanda sono state già operate 2 rinunce sulle altre scuole di preferenza:
•	Selezione delle eventuali altre scuole RINUNCIATE della domanda :
•	ISCRITTO_T_GRADUATORIA.id_domanda_iscrizione= id_iscrizione della domanda posta a RINUNCIA AUTOMATICA escludendo la scuola stessa e ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a RINUNCIATO o RINUNCIA AUTOMATICA e sempre ISCRITTO_T_GRADUATORIA.id_step_gra dello step in corso.
5.	Se sono stati trovati due record impostare lo stato di CANCELLATO PER RINUNCIA alle eventuali altre scuole di preferenza della domanda ancora in stato PENDENTE:
•	Selezione delle altre scuole della domandaISCRITTO_T_GRADUATORIA.id_domanda_iscrizione= id_iscrizione della domanda  posta a RINUNCIA AUTOMATICA e ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a PENDENTE e sempre ISCRITTO_T_GRADUATORIA.id_step_gra dello step in corso.
•	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a CANCELLATO PER RINUNCIA.
•	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN

6.	Impostare il flag fl_ammissioni=’S’ nel record di tabella ISCRITTO_T_STEP_GRA per la graduatoria in corso
*/
CREATE OR REPLACE
FUNCTION Rinuncia ( pCodOrdineScuola  VARCHAR(20)
                  ) RETURNS SMALLINT AS
$BODY$
DECLARE
  vIdStepInCorso      iscritto_t_graduatoria.id_step_gra_con%TYPE;
  grad                RECORD;
  altreScuole         RECORD;
  vCancellatiRinuncia iscritto_t_graduatoria.id_graduatoria%TYPE;
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
                              AND id_stato_scu = GetIdStatoScuola('PEN')
                              AND id_step_gra_con = vIdStepInCorso
      LOOP
        /*
          •	Impostare per le scuole trovate lo stato di CANCELLATO PER RINUNCIA PRIMA SCELTA
          •	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu con lo stato corrispondente a CANCELLATO PER RINUNCIA PRIMA SCELTA. 
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
          •	Impostare lo stato della domanda a RINUNCIATO
          •	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
        */
      END LOOP;
      /*
        •	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
      */
      UPDATE  iscritto_t_domanda_isc
        SET id_stato_dom = GetIdStatoDomanda('RIN')
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
    ELSE
      SELECT  COUNT(1)
        INTO  vCancellatiRinuncia
        FROM  iscritto_t_graduatoria
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
          AND id_scuola <> grad.id_scuola
          AND id_stato_scu IN ( GetIdStatoScuola('RIN') , GetIdStatoScuola('RIN_AUTO') )
          AND id_step_gra_con = vIdStepInCorso;
      IF vCancellatiRinuncia >= 2 THEN
        FOR altreScuole IN  SELECT  id_scuola
                                  , id_tipo_frequenza
                              FROM  iscritto_t_graduatoria
                              WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
                                AND id_stato_scu = GetIdStatoScuola('PEN')
                                AND id_step_gra_con = vIdStepInCorso
        LOOP
          /*
            •	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a CANCELLATO PER RINUNCIA.
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
          •	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
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
  END LOOP;
  -------
  -- 6.	Impostare il flag fl_ammissioni=’S’ nel record di tabella ISCRITTO_T_STEP_GRA per la graduatoria in corso
  UPDATE  iscritto_t_step_gra_con
    SET fl_ammissioni = 'S'
    WHERE id_step_gra_con = vIdStepInCorso;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

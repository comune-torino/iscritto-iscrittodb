DROP FUNCTION CalcolaPunteggio(pIdDomandaIscrizione INTEGER);
DROP FUNCTION attribuiscicondizioni(pdatada date,pdataa date);



/*
  Legge il testo di ammissione per SMS
*/
CREATE OR REPLACE
FUNCTION GetTestoSmsAmmissione() RETURNS VARCHAR(180) AS
$BODY$
DECLARE
  vTesto  iscritto_t_parametro.testo_sms_amm%TYPE;
BEGIN
  SELECT  testo_sms_amm
    INTO  vTesto
    FROM  iscritto_t_parametro;
  RETURN vTesto;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION EsisteScuolaInStato  ( IN  pIdDomandaIscrizione  INTEGER
                              , IN  pCodStatoScuola       VARCHAR(10)
                              ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  vFound  BOOLEAN;
BEGIN
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  vFound
    FROM  iscritto_r_scuola_pre   scuPre
        , iscritto_d_stato_scu    statScu
    WHERE scuPre.id_stato_scu = statScu.id_stato_scu
      AND scuPre.id_domanda_iscrizione = pIdDomandaIscrizione
      AND statScu.cod_stato_scu = pCodStatoScuola;
  RETURN vFound;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
Procedura batch eseguita settimanalmente, ogni martedì alle ore 4:15 con il parametro id_ordine_scuola valorizzato a 1 per i NIDI o 2 per le MATERNE.
-	CONGELAMENTO GRADUATORIA DEFINITIVA E APERTURA DELLA PUBBLICATA
1.	Filtrare la tabella ISCRITTO_T_ANAGRAFICA_GRA per id_ordine_scuola passato come parametro e metterla in join con la tabella ISCRITTO_T_STEP_GRA e ID_STEP_GRA_CON e ordinare per dt_step_con per data più recente
2.	Se il record più recente ha come id_stato_grad  che corrisponde a DEF nella tabella ISCRITTO_T_STEP_GRA_CON:
•	cambiare lo stato in DEF_CON e la data dt_step_con con la sysdate
•	inserire un nuovo record: 
•	id_step_gra_con  sequenziale
•	id_step_gra  id_step_gra precedente
•	id_stato_grad  corrispondente al codie stato ‘PUB’
•	fl_ammissioni  ‘N’
•	dt_step_con  sysdate
3.	Copia dei record dal precedente id_step
•	Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente ( quelli con stato graduatoria DEF_CON nella stessa tabella con l’id_step_graduatoria_con nuovo ( PUB).
4.	Se nel punto 2 il record ha come id_stato_grad corrispondente a PUB:
•	Impostare il flag fl_ammissioni=’N’

-	AGGIORNAMENTO STATI/PUNTEGGIO DELLE SCUOLE E STATI DELLE DOMANDE

1.	Eseguire una query sulla tabella ISCRITTO_T_GRADUATORIA filtrando per l’id_step_gra_con del record  con id_stato_gra corrispondente a PUB.
2.	Per ogni record individuato confrontare ISCRITTO_T_GRADUATORIA.id_stato_scu con ISCRITTO_R_SCUOLA_PRE.id_stato_scu e ISCRITTO_T_GRADUATORIA.punteggio con ISCRITTO_R_SCUOLA_PRE.punteggio a parità di id_domanda_isc, id_tipo_frequenza, id_scuola.
3.	Se diversi aggiornare ISCRITTO_R_SCUOLA_PRE inserendo anche la data ISCRITTO_R_SCUOLA_PRE.dt_stato con il valore della sysdate e aggiornare anche lo stato della domanda ( ISCRITTO_T_DOMANDA_ISC.id_stato_dom ) in base a questo algoritmo:
•	Se c’è un nido della domanda in stato AMM  stato_domanda AMM
•	Se c’è un nido della domanda in stato PEN  stato domanda GRA
•	Se c’è un nido della domanda in stato CAN_R_1SC o CAN_RIN  stato_domanda RIN

-	POPOLAMENTO TABELLA SMS
1.	Selezionare dalla tabella ISCRITTO_T_GRADUATORIA i record che hanno l’id_step_grad_con del record  con id_stato_gra corrispondente a PUB e con id_stato_scu corrispondente a AMM.
2.	Per ogni record selezionato inserire un record nella tabella ISCRITTO_T_INVIO_SMS con i seguenti valori:
•	Id_invio_SMS  numero sequenziale
•	Testo  ISCRITTO_T_PARAMETRO.testo_ammissioni
•	Id_domanda_iscr  ISCRITTO_T_GRADUATORIA.Id_domanda_iscr
•	Dt_inserimento  sysdate
•	Dt_invio NULL
•	Esito  NULL
•	Telefono  ISCRITTO_T_DOMANDA_ISC.telefono

-	INVIO SMS
Esecuzione della procedura java di invio SMS e scrittura nella tabella ISCRITTO_T_INVIO_SMS della data di invio ( dt_invio ) e dell’esito ( esito ).
*/
CREATE OR REPLACE
FUNCTION InviaSMS ( pCodOrdineScuola  VARCHAR(20)
                  ) RETURNS SMALLINT AS
$BODY$
DECLARE
  vIdStepGraCon     iscritto_t_step_gra_con.id_step_gra_con%TYPE;
  vIdStepGraConNew  iscritto_t_step_gra_con.id_step_gra_con%TYPE;
  vIdStepGra        iscritto_t_step_gra_con.id_step_gra%TYPE;
  vCodStatoGra      iscritto_d_stato_gra.cod_stato_gra%TYPE;
  -----
  step              RECORD;
  grad              RECORD;
  vCodStatoDomanda  iscritto_d_stato_dom.cod_stato_dom%TYPE;
BEGIN
  -- CONGELAMENTO GRADUATORIA DEFINITIVA E APERTURA DELLA PUBBLICATA
  SELECT  id_step_gra_con
        , cod_stato_gra
        , id_step_gra
    INTO STRICT vIdStepGraCon
              , vCodStatoGra
              , vIdStepGra
    FROM  ( SELECT  stepGraCon.id_step_gra_con  id_step_gra_con
                  , statGra.cod_stato_gra       cod_stato_gra
                  , stepGraCon.id_step_gra      id_step_gra
              FROM  iscritto_t_anagrafica_gra   anagGra
                  , iscritto_t_step_gra         stepGra
                  , iscritto_t_step_gra_con     stepGraCon
                  , iscritto_d_stato_gra        statGra
              WHERE anagGra.id_anagrafica_gra = stepGra.id_anagrafica_gra
                AND stepGra.id_step_gra = stepGraCon.id_step_gra
                AND stepGraCon.id_stato_gra = statGra.id_stato_gra
              ORDER BY  stepGraCon.dt_step_con  DESC
          ) t
    LIMIT 1;
  IF vCodStatoGra = 'DEF' THEN
    /*
      2.	Se il record più recente ha come id_stato_grad  che corrisponde a DEF nella tabella ISCRITTO_T_STEP_GRA_CON:
      •	cambiare lo stato in DEF_CON e la data dt_step_con con la sysdate
      •	inserire un nuovo record: 
      •	id_step_gra_con  sequenziale
      •	id_step_gra  id_step_gra precedente
      •	id_stato_grad  corrispondente al codie stato ‘PUB’
      •	fl_ammissioni  ‘N’
      •	dt_step_con  sysdate
      3.	Copia dei record dal precedente id_step
      •	Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente ( quelli con stato graduatoria
          DEF_CON nella stessa tabella con l’id_step_graduatoria_con nuovo ( PUB).
    */
    UPDATE  iscritto_t_step_gra_con
      SET id_stato_gra = GetIdStatoGraduatoria('DEF_CON')
        , dt_step_con = CURRENT_TIMESTAMP
      WHERE id_step_gra_con = vIdStepGraCon;
    vIdStepGraConNew := nextval('iscritto_t_step_gra_con_id_step_gra_con_seq');
    INSERT INTO iscritto_t_step_gra_con
                ( id_step_gra_con
                , id_step_gra
                , id_stato_gra
                , fl_ammissioni
                , dt_step_con
                )
      VALUES  ( vIdStepGraConNew
              , vIdStepGra
              , GetIdStatoGraduatoria('PUB')
              , 'N'
              , CURRENT_TIMESTAMP
              );
    FOR grad IN SELECT  *
                  FROM  iscritto_t_graduatoria
                  WHERE id_step_gra_con = vIdStepGraCon
    LOOP
      INSERT INTO iscritto_t_graduatoria
                  ( id_graduatoria
                  , id_scuola
                  , id_domanda_iscrizione
                  , punteggio
                  , fl_fuori_termine
                  , id_tipo_frequenza
                  , isee
                  , ordine_preferenza
                  , id_fascia_eta
                  , ordinamento
                  , id_stato_scu
                  , id_step_gra_con
                  )
      VALUES  ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
              , grad.id_scuola
              , grad.id_domanda_iscrizione
              , grad.punteggio
              , grad.fl_fuori_termine
              , grad.id_tipo_frequenza
              , grad.isee
              , grad.ordine_preferenza
              , grad.id_fascia_eta
              , grad.ordinamento
              , grad.id_stato_scu
              , vIdStepGraConNew
              );
    END LOOP;
  ELSIF vCodStatoGra = 'PUB' THEN
    /*
      4.	Se nel punto 2 il record ha come id_stato_grad corrispondente a PUB:
      •	Impostare il flag fl_ammissioni=’N’
    */
    UPDATE  iscritto_t_step_gra_con
      SET fl_ammissioni = 'N'
      WHERE id_step_gra_con = vIdStepGraCon;
  END IF;
  ----------
  FOR grad IN SELECT  scuPre.id_domanda_iscrizione  id_domanda_iscrizione
                    , scuPre.id_scuola              id_scuola
                    , scuPre.id_tipo_frequenza      id_tipo_frequenza
                    , gr.id_stato_scu               id_stato_scuola_graduatoria
                    , scuPre.id_stato_scu           id_stato_scuola_pre
                    , gr.punteggio                  punteggio_graduatoria
                    , scuPre.punteggio              punteggio_scuola_pre
                FROM  iscritto_t_graduatoria  gr
                    , iscritto_r_scuola_pre   scuPre
                WHERE gr.id_domanda_iscrizione = scuPre.id_domanda_iscrizione
                  AND gr.id_tipo_frequenza = scuPre.id_tipo_frequenza
                  AND gr.id_scuola = scuPre.id_scuola
                  AND gr.id_step_gra_con = vIdStepGraCon
  LOOP
    IF grad.id_stato_scuola_graduatoria <> grad.id_stato_scuola_pre OR grad.punteggio_graduatoria <> grad.punteggio_scuola_pre THEN
      UPDATE  iscritto_r_scuola_pre
        SET dt_stato = CURRENT_TIMESTAMP
          , id_stato_scu = grad.id_stato_scuola_graduatoria
          , punteggio = grad.punteggio_graduatoria
        WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
          AND id_scuola = grad.id_scuola
          AND id_tipo_frequenza = grad.id_tipo_frequenza;
       /*
        aggiornare anche lo stato della domanda ( ISCRITTO_T_DOMANDA_ISC.id_stato_dom ) in base a questo algoritmo:
          •	Se c’è un nido della domanda in stato AMM  stato_domanda AMM
          •	Se c’è un nido della domanda in stato PEN  stato domanda GRA
          •	Se c’è un nido della domanda in stato CAN_R_1SC o CAN_RIN  stato_domanda RIN
       */
      vCodStatoDomanda = NULL;
      IF EsisteScuolaInStato(grad.id_domanda_iscrizione, 'AMM') THEN
        vCodStatoDomanda = 'AMM';
      ELSIF EsisteScuolaInStato(grad.id_domanda_iscrizione, 'PEN') THEN
        vCodStatoDomanda = 'GRA';
      ELSIF EsisteScuolaInStato(grad.id_domanda_iscrizione, 'CAN_R_1SC') OR EsisteScuolaInStato(grad.id_domanda_iscrizione, 'CAN_RIN') THEN
        vCodStatoDomanda = 'RIN';
      END IF;
      ------
      IF vCodStatoDomanda IS NOT NULL THEN
        UPDATE  iscritto_t_domanda_isc
          SET id_stato_dom = GetIdStatoDomanda(vCodStatoDomanda)
          WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
      END IF;
    END IF;
  END LOOP;
  --------
  FOR grad IN SELECT  gr.id_domanda_iscrizione  id_domanda_iscrizione
                    , domIsc.telefono           telefono
                FROM  iscritto_t_graduatoria  gr
                    , iscritto_t_domanda_isc  domIsc
                WHERE gr.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND gr.id_stato_scu = GetIdStatoScuola('AMM')
                  AND gr.id_step_gra_con = vIdStepGraConNew
  LOOP
    INSERT INTO iscritto_t_invio_sms
                ( id_invio_sms
                , testo
                , id_domanda_iscrizione
                , dt_inserimento
                , telefono
                )
      VALUES  ( nextval('iscritto_t_invio_sms_id_invio_sms_seq')
              , GetTestoSmsAmmissione()
              , grad.id_domanda_iscrizione
              , CURRENT_TIMESTAMP
              , grad.telefono
              );
  END LOOP;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdStatoDomanda  ( IN  pCodStatoDomanda  VARCHAR(20)
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
  vIdStatoDomanda   iscritto_d_stato_dom.id_stato_dom%TYPE;
BEGIN
  SELECT  id_stato_dom
    INTO  vIdStatoDomanda
    FROM  iscritto_d_stato_dom
    WHERE cod_stato_dom = pCodStatoDomanda;
  RETURN vIdStatoDomanda;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdStatoGraduatoria  ( pCodStatoGra  VARCHAR(10)
                                ) RETURNS INTEGER AS
$BODY$
DECLARE
  vIdStatoGraduatoria   iscritto_d_stato_gra.id_stato_gra%TYPE;
BEGIN
  SELECT  id_stato_gra
    INTO  vIdStatoGraduatoria
    FROM  iscritto_d_stato_gra
    WHERE cod_stato_gra = pCodStatoGra;
  RETURN vIdStatoGraduatoria;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetStepInCorso ( pCodOrdineScuola  VARCHAR(20)
                        ) RETURNS INTEGER AS
$BODY$
DECLARE
  vIdStepInCorso  iscritto_t_step_gra_con.id_step_gra_con%TYPE;
BEGIN
  SELECT  stepGraCon.id_step_gra_con  id_step_graduatoria_con
    INTO  vIdStepInCorso
    FROM  iscritto_t_step_gra         stepGra
        , iscritto_t_anagrafica_gra   anagGra
        , iscritto_t_step_gra_con     stepGraCon
    WHERE stepGra.id_anagrafica_gra = anagGra.id_anagrafica_gra
      AND stepGra.id_step_gra = stepGraCon.id_step_gra
      AND anagGra.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
      AND stepGraCon.id_stato_gra = GetIdStatoGraduatoria('PUB')
      AND stepGra.dt_step_grad <= CURRENT_TIMESTAMP;
  RETURN vIdStepInCorso;
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
        AND id_scuola = gr.id_scuola
        AND id_tipo_frequenza = gr.id_tipo_frequenza;
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



/*
AMMISSIONI

Procedura richiamata da funzionalità presente nell’interfaccia FrontEnd dell’applicativo.
Vuole come parametri d’ingresso: id_step_gra_con dello step in corso.
-	Cancellazione posti ammessi
1.	Eliminare eventuali posti ammessi nelle classi.
•	Individuare l’anno scolastico e le scuole attraverso le tabelle messe in join: ISCRITTO_T_STEP_GRA_CON, ISCRITTO_T_STEP_GRA, ISCRITTO_T_ANAGRAFICA_GRA, ISCRITTO_T_SCUOLA
•	Selezionare i record dalla tabella ISCRITTO_T_CLASSE filtrando per id_anno_scolastico, id__scuola individuati al passo precedente e per posti_ammessi<>0
•	Per ogni record di ISCRITTO_T_CLASSE individuato impostare posti_liberi= posti_liberi+posti_ammessi e posti ammessi=0.
2.	Portare gli stati delle scuole da AMMESSO a PENDENTE
•	Selezionare i record dalla tabella ISCRITTO_T_GRADUATORIA filtrando per id_stato_grad_con passato come parametro e id_stato_scu= corrispondente ad ’AMMESSO’
•	Impostare id_stato_scu= corrispondente a PENDENTE dei record selezionati.

-	Calcolo del punteggio
•	Calcolo del punteggio
-	Ordinamento
1.	Update di ISCRITTO_T_GRADUATORIA.ordinamento uguale a quello descritto per il ‘Calcolo della graduatoria’.

-	ATTRIBUZIONE POSTI LIBERI
A questo punto occorre attribuire i posti liberi delle varie classi dei nidi alle scuole delle domande in graduatoria in base al loro ordinamento e fascia d’età.
1.	Selezione dei record sulla tabella ISCRITTO_T_GRADUATORIA partendo dalla prima fascia d’età ( id_fascia_eta=1)
•	Selezionare i record che hanno l’id_step_gra_con uguale allo step di graduatoria passato come parametro, lo stato scuola in PENDENTE e fascia d’eta LATTANTI. Ordinare i record selezionati per il valore del campo ordinamento crescente.
2.	Partendo dal primo record selezionare il record sulla tabella ISCRITTO_T_CLASSE con questi filtri:
•	id_anno_scolastico uguale all’anno scolastico della graduatoria di riferimento.
•	Id_scuola uguale a quello del record selezionato al punto 1
•	Id_tipo_frequenza uguale a quello del record selezionato al punto 1
•	Id_fascia_eta del record selezionato al punto 1 deve essere uguale a quello della  tabella ISCRITTO_T_ETA che deve essere messa in join con ISCRITTO_T_CLASSE
•	La differenza tra i posti_liberi e posti_ammessi è Il numero di posti liberi maggiore di 0. 
•	se in tabella ISCRITTO_R_PUNTEGGIO_DOM per id_domanda_isc, id_condizione_punteggio corrispondente al codice ‘PA_SOC’ e dt_fine_validita è NULL il flag fl_valida=’S’  allora il flag fl_ammissione_dis di ISCRITTO_T_CLASSE  deve valere ‘S’ altrimenti se non è stato individuato il record in ISCRITTO_R_PUNTEGGIO_DOM non si fa il controllo sul valore del flag fl_ammissioni_dis.
3.	Solo se è stato trovato un record al punto 2:
•	Valorizzare id_stato_scu a AMMESSO in tabella ISCRITTO_T_GRADUATORIA.
•	Incrementare di 1 il numero dei posti_ammessi e decrementare di 1 i posti liberi nel record in tabella ISCRITTO_T_CLASSE.
•	Eliminare dalla selezione tutti i rimanenti record riferiti alla domanda passata in ammesso perché non bisogna più processarli.
4.	Ripetizione dei passi 2 e 3 per tutti i record della lista ordinata del punto 1.
5.	Concluso il ciclo ripeterlo per le altre fasce d’età.
*/
CREATE OR REPLACE
FUNCTION AttribuisciPosti ( pIdStepGraduatoriaCon INTEGER
                          ) RETURNS SMALLINT AS
$BODY$
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
  SELECT  DISTINCT
            anagGra.id_anno_scolastico  id_anno_scolastico
    INTO  vIdAnnoScolastico
    FROM  iscritto_t_step_gra_con     stepGraCon
        , iscritto_t_step_gra         stepGra
        , iscritto_t_anagrafica_gra   anagGra
    WHERE stepGraCon.id_step_gra = stepGra.id_step_gra
      AND stepGra.id_anagrafica_gra = anagGra.id_anagrafica_gra
      AND stepGraCon.id_step_gra_con = pIdStepGraduatoriaCon;
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
  UPDATE  iscritto_t_graduatoria
    SET id_stato_scu = GetIdStatoScuola('PEN')
    WHERE id_step_gra_con = pIdStepGraduatoriaCon
      AND id_stato_scu = GetIdStatoScuola('AMM');
  -------
  -- •	Calcolo del punteggio
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
                  FROM  iscritto_t_graduatoria
                  WHERE id_step_gra_con = pIdStepGraduatoriaCon
                    AND id_fascia_eta = fascia.id_fascia_eta
                    AND id_stato_scu = GetIdStatoScuola('PEN')
                  ORDER BY  ordinamento
    LOOP
      -- Verifico se la domanda è tra quelle non più da elaborare
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
  Update valore ordinamento
    8.	Selezionare tutti i record appena inseriti per lo step da calcolare.
    9.	Dividere la selezione in blocchi per fascia d’età
    10.	All’interno dei blocchi ordinare i record per:
      A.	Fuori termine/Nei termini in base al flag fl_fuori_termine
      B.	Punteggio decrescente
      C.	Isee crescente ( se presente, Isee NULL bassa priorità ) 
      D.	Età  precedenza a età maggiore per i lattanti ( 0-12 mesi ) e piccoli ( 13-24 mesi ) età minore per i grandi ( 25-36 mesi ). A parità di data di nascita occorre verificare anche l’ora di nascita).
      E.	Data di inserimento domanda ( anche ora minuti e secondi ).
      F.	Ordine di preferenza crescente.
    11.	Eseguire l’update del campo ISCRITTO_T_GRADUATORIA.ordinamento con il valore derivante dall’ordinamento effettuato.
*/
CREATE OR REPLACE
FUNCTION OrdinaGraduatoria  ( pIdStepGraduatoria  INTEGER
                            ) RETURNS SMALLINT AS
$BODY$
DECLARE
  grad  RECORD;
  -----
  nOrdinamento  iscritto_t_graduatoria.ordinamento%TYPE;
BEGIN
  -- Valorizzo il campo ordinamento per i record appena inseriti divisi per blocchi d'età
  ----------
  -- Fascia LATTANTI
  nOrdinamento = 0;
  ------
  FOR grad IN SELECT  gr.id_graduatoria   id_graduatoria
                FROM  iscritto_t_graduatoria      gr
                    , iscritto_t_domanda_isc      domIsc
                    , iscritto_t_anagrafica_sog   anagSog
                    , iscritto_r_soggetto_rel     sogRel
                    , iscritto_d_tipo_sog         tipoSog
                    , iscritto_d_fascia_eta       fascEta
                WHERE gr.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
                  AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                  AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
                  AND gr.id_fascia_eta = fascEta.id_fascia_eta
                  AND gr.id_step_gra_con = pIdStepGraduatoria
                  AND tipoSog.cod_tipo_soggetto = 'MIN'
                  AND fascEta.cod_fascia_eta = 'L'
                ORDER BY  gr.fl_fuori_termine
                        , gr.punteggio            DESC
                        , COALESCE(isee,99999999)
                        , anagSog.data_nascita
                        , domIsc.data_consegna
                        , gr.ordine_preferenza
  LOOP
    nOrdinamento = nOrdinamento + 1;
    UPDATE  iscritto_t_graduatoria
      SET ordinamento = nOrdinamento
      WHERE id_graduatoria = grad.id_graduatoria;
  END LOOP;
  ----------
  -- Fascia PICCOLI
  nOrdinamento = 0;
  ------
  FOR grad IN SELECT  gr.id_graduatoria   id_graduatoria
                FROM  iscritto_t_graduatoria      gr
                    , iscritto_t_domanda_isc      domIsc
                    , iscritto_t_anagrafica_sog   anagSog
                    , iscritto_r_soggetto_rel     sogRel
                    , iscritto_d_tipo_sog         tipoSog
                    , iscritto_d_fascia_eta       fascEta
                WHERE gr.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
                  AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                  AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
                  AND gr.id_fascia_eta = fascEta.id_fascia_eta
                  AND gr.id_step_gra_con = pIdStepGraduatoria
                  AND tipoSog.cod_tipo_soggetto = 'MIN'
                  AND fascEta.cod_fascia_eta = 'P'
                ORDER BY  gr.fl_fuori_termine
                        , gr.punteggio            DESC
                        , COALESCE(isee,99999999)
                        , anagSog.data_nascita
                        , domIsc.data_consegna
                        , gr.ordine_preferenza
  LOOP
    nOrdinamento = nOrdinamento + 1;
    UPDATE  iscritto_t_graduatoria
      SET ordinamento = nOrdinamento
      WHERE id_graduatoria = grad.id_graduatoria;
  END LOOP;
  ----------
  -- Fascia GRANDI
  nOrdinamento = 0;
  ------
  FOR grad IN SELECT  gr.id_graduatoria   id_graduatoria
                FROM  iscritto_t_graduatoria      gr
                    , iscritto_t_domanda_isc      domIsc
                    , iscritto_t_anagrafica_sog   anagSog
                    , iscritto_r_soggetto_rel     sogRel
                    , iscritto_d_tipo_sog         tipoSog
                    , iscritto_d_fascia_eta       fascEta
                WHERE gr.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
                  AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                  AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
                  AND gr.id_fascia_eta = fascEta.id_fascia_eta
                  AND gr.id_step_gra_con = pIdStepGraduatoria
                  AND tipoSog.cod_tipo_soggetto = 'MIN'
                  AND fascEta.cod_fascia_eta = 'G'
                ORDER BY  gr.fl_fuori_termine
                        , gr.punteggio            DESC
                        , COALESCE(isee,99999999)
                        , anagSog.data_nascita      DESC
                        , domIsc.data_consegna
                        , gr.ordine_preferenza
  LOOP
    nOrdinamento = nOrdinamento + 1;
    UPDATE  iscritto_t_graduatoria
      SET ordinamento = nOrdinamento
      WHERE id_graduatoria = grad.id_graduatoria;
  END LOOP;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION AttribuisciCondizione  ( pIdStepGraCon   INTEGER
                                , pCodCondizione  VARCHAR(20)
                                ) RETURNS SMALLINT AS
$BODY$
DECLARE
  grad      RECORD;
  rec       RECORD;
  vRetCode  SMALLINT;
BEGIN
  FOR grad IN SELECT  DISTINCT
                        dom.id_domanda_iscrizione   id_domanda_iscrizione
                FROM  iscritto_t_graduatoria    gr
                    , iscritto_t_domanda_isc    dom
                WHERE gr.id_domanda_iscrizione = dom.id_domanda_iscrizione
                  AND gr.id_step_gra_con = pIdStepGraCon
  LOOP
    -- Verifico se c'è da aggiungere la condizione LA_PER
    SELECT  *
      INTO  rec
      FROM  Punteggio(pCodCondizione, grad.id_domanda_iscrizione);
    IF rec.pRicorrenza > 0 THEN
      vRetCode = AggiungiCondizionePunteggio ( grad.id_domanda_iscrizione, GetIdCondizionePunteggio(pCodCondizione), rec.pRicorrenza, rec.pFlagValida );
    END IF;
    -----------
  END LOOP;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdFasciaEta ( IN  pIdDomandaIscrizione    INTEGER
                        ) RETURNS INTEGER AS
$BODY$
DECLARE
  nIdFasciaEta  iscritto_t_eta.id_fascia_eta%TYPE;
BEGIN
  SELECT  eta.id_fascia_eta
    INTO  nIdFasciaEta
    FROM  iscritto_t_domanda_isc      domIsc
        , iscritto_t_anno_sco         annoSco
        , iscritto_d_ordine_scuola    ordScu
        , iscritto_t_anagrafica_gra   anagGra
        , iscritto_t_eta              eta
        , iscritto_t_anagrafica_sog   anagSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipoSog
    WHERE domIsc.id_anno_scolastico = annoSco.id_anno_scolastico
      AND domIsc.id_ordine_scuola = ordScu.id_ordine_scuola
      AND annoSco.id_anno_scolastico = anagGra.id_anno_scolastico
      AND ordScu.id_ordine_scuola = anagGra.id_ordine_scuola
      AND anagGra.id_anagrafica_gra = eta.id_anagrafica_gra
      AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
      AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
      AND domIsc.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipoSog.cod_tipo_soggetto = 'MIN'
      AND anagSog.data_nascita BETWEEN eta.data_da AND eta.data_a;
  RETURN nIdFasciaEta;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetValoreIsee  ( IN  pIdDomandaIscrizione  INTEGER
                        ) RETURNS NUMERIC(10,2) AS
$BODY$
DECLARE
  sFlagValida   iscritto_r_punteggio_dom.fl_valida%TYPE;
  nValoreIsee   iscritto_t_isee.valore_isee%TYPE;
BEGIN
  SELECT  fl_valida
        , valore_isee
    INTO STRICT sFlagValida
              , nValoreIsee
    FROM  ( SELECT puntDom.fl_valida   fl_valida
                 , isee.valore_isee    valore_isee
              FROM  iscritto_r_punteggio_dom    puntDom
                  , iscritto_d_condizione_pun   condPun
                  , iscritto_t_domanda_isc      domIsc
                  , iscritto_t_isee             isee
              WHERE puntDom.id_condizione_punteggio = condPun.id_condizione_punteggio
                AND puntDom.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                AND domIsc.id_domanda_iscrizione = isee.id_domanda_iscrizione
                AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
                AND condPun.cod_condizione = 'PAR_ISEE'
                AND puntDom.dt_fine_validita IS NULL
              ORDER BY  puntDom.dt_inizio_validita DESC
          )                     isee
    LIMIT 1;
  ------
  IF COALESCE(sFlagValida,' ') = 'N' THEN
    nValoreIsee = NULL;
  END IF;
  ------
  RETURN nValoreIsee;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdStatoScuola ( IN  pCodStatoScuola VARCHAR(10)
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nIdStatoScuola  iscritto_d_stato_scu.id_stato_scu%TYPE;
BEGIN
  SELECT  id_stato_scu
    INTO  nIdStatoScuola
    FROM  iscritto_d_stato_scu
    WHERE cod_stato_scu = pCodStatoScuola;
  RETURN nIdStatoScuola;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
•	Accedere alla tabella ISCRITTO_R_PUNTEGGIO_DOM per id_domanda_isc, id_condizione_pun corrispondente a CF_FRA_ISC, dt_fine_validita=NULL e fl_valida=NULL 
•	Quando per la domanda è soddisfatta la condizione sopra riportata cercare una domanda in stato INSERITO e per lo stesso anno scolastico
  per il minore avente lo stesso codice fiscale trovato in ISCRITTO_T_FRATELLO_FRE.cf_fratello. 
•	Se trovata inserire un record  eseguire un update nella tabella ISCRITTO_R_PUNTEGGIO_DOM con valorizzato nel seguente modo:
    filtrando il record per id_domanda_isc della domanda trovata e id_condizione_pun corrispondente a CF_FRA_ISC e dt_fine_validita=NULL
    e valorizzando i seguenti campi:
      id_domanda_iscrizione= id_domanda elaborata
      dt_inizio_validita = sysdate
      dt_fine_validita= NULL
      id_utente=NULL
      fl_valida = ‘S’  se trovata altra domanda ‘N’ se non trovata
      note=NULL se trovata altra domanda ‘Non trovato fratello/sorella iscrivendo’ se non trovata
      ricorrenza= 1  
      id_condizione_punteggio= 23 ( CF_FRA_ISC )
      fl_integrazione=NULL.
*/
CREATE OR REPLACE
FUNCTION ValidaCondizioneCfFraIsc ( pIdDomandaIscrizione  INTEGER
                                  ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  vDaRicalcolare          BOOLEAN;
  vCfFratello             iscritto_t_fratello_fre.cf_fratello%TYPE;
  vIdAnnoScolastico       iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
  vIdCondizionePunteggio  iscritto_r_punteggio_dom.id_condizione_punteggio%TYPE;
  vFlagValida             iscritto_r_punteggio_dom.fl_valida%TYPE;
  vNote                   iscritto_r_punteggio_dom.note%TYPE;
BEGIN
  vDaRicalcolare = FALSE;
  -------
  BEGIN
    -- Cerco se per la domanda in elaborazione esiste un soggetto fratello/sorella
    SELECT  fratFre.cf_fratello               cf_fratello
          , domIsc.id_anno_scolastico         id_anno_scolastico
          , puntDom.id_condizione_punteggio   id_condizione_punteggio
      INTO STRICT vCfFratello
                , vIdAnnoScolastico
                , vIdCondizionePunteggio
      FROM  iscritto_r_punteggio_dom    puntDom
          , iscritto_d_condizione_pun   condPunt
          , iscritto_t_domanda_isc      domIsc
          , iscritto_t_fratello_fre     fratFre
      WHERE puntDom.id_condizione_punteggio = condPunt.id_condizione_punteggio
        AND puntDom.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
        AND domIsc.id_domanda_iscrizione = fratFre.id_domanda_iscrizione
        AND puntDom.id_domanda_iscrizione = pIdDomandaIscrizione
        AND condPunt.cod_condizione = 'CF_FRA_ISC'
        AND puntDom.dt_fine_validita IS NULL
        AND puntDom.fl_valida IS NULL;
    -- Se ha un fratello/sorella cerco se quest'ultimo ha una domanda in stato "INVIATA" per lo stesso anno scolastico
    SELECT  CASE WHEN COUNT(1) = 0 THEN 'N' ELSE 'S' END
          , CASE WHEN COUNT(1) = 0 THEN 'Non trovato fratello/sorella iscrivendo' ELSE NULL END
      INTO  vFlagValida
          , vNote
      FROM  iscritto_t_domanda_isc      domIsc
          , iscritto_t_anagrafica_sog   anagSog
          , iscritto_d_stato_dom        statDom
      WHERE domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
        AND domIsc.id_stato_dom = statDom.id_stato_dom
        AND anagSog.codice_fiscale = vCfFratello
        AND id_anno_scolastico = vIdAnnoScolastico
        AND statDom.cod_stato_dom = 'INV';
    -- Aggiorno la tabella delle condizioni di punteggio in base a cosa ho trovato in precedenza
    UPDATE  iscritto_r_punteggio_dom
      SET dt_inizio_validita = CURRENT_TIMESTAMP
        , fl_valida = vFlagValida
        , note = vNote
      WHERE id_domanda_iscrizione = pIdDomandaIscrizione
        AND id_condizione_punteggio = vIdCondizionePunteggio
        AND dt_fine_validita IS NULL;
    vDaRicalcolare = TRUE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      vDaRicalcolare = FALSE;
  END;
  -------
  RETURN vDaRicalcolare;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
A fronte di uno step legge le informazioni correlate
*/
CREATE OR REPLACE
FUNCTION GetInfoStepGraduatoria ( IN  pIdStepGraduatoria    INTEGER
                                , OUT pDataDomandaInvioDa   DATE
                                , OUT pDataDomandaInvioA    DATE
                                ) AS
$BODY$
DECLARE
BEGIN
  SELECT  stepGrad.dt_dom_inv_da
        , stepGrad.dt_dom_inv_a
    INTO  pDataDomandaInvioDa
        , pDataDomandaInvioA
    FROM  iscritto_t_step_gra       stepGrad
        , iscritto_t_step_gra_con   stepGradCon
        , iscritto_d_stato_gra      statGrad
    WHERE stepGrad.id_step_gra = stepGradCon.id_step_gra
      AND stepGradCon.id_stato_gra = statGrad.id_stato_gra
      AND stepGradCon.id_step_gra_con = pIdStepGraduatoria;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION InserisciDomandeInGraduatoria  ( pIdStepGradDaCalcolare  INTEGER
                                        ) RETURNS INTEGER AS
$BODY$
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
                      AND dom.data_consegna BETWEEN param.pDataDomandaInvioDa AND param.pDataDomandaInvioA
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
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
CALCOLO DELLA GRADUATORIA

Con il calcolo della graduatoria intendiamo l’operazione di pubblicazione delle domande in graduatoria ossia l’inserimento dei record nella tabella ISCRITTO_T_GRADUATORIA. 
La procedura che verrà richiamata da codice java vuole come parametro d’ingresso:
-	L’identificativo dello step di graduatoria da calcolare, l’identificativo dello step di graduatoria precedente, e il codice dello stato di graduatoria un flag valorizzato a ‘P’, ‘D’ o ‘S’

FLAG P
1.	Se l’identificativo della graduatoria precedente non è NULL, eliminare tutti i record dello step attuale di graduatoria: eliminare i record dalla tabella ISCRITTO_T_GRADUATORIA che hanno id_step_gra_con uguale a quello passato come parametro ( se esistono ).
2.	Se lo stato dello step di graduatoria attuale ( ISCRITTO_T_STEP_GRA.id_stato_gra ) è uguale a ‘definitivo’ azzerare anche i posti ammessi di tutte le classi ( ISCRITTO_T_CLASSE.posti_ammessi ) dell’ordine di scuola e anno scolastico definito dall’anagrafica di graduatoria a cui è collegato lo step.
3.	Selezionare i record nella tabella ISCRITTO_T_DOMANDA_ISC che hanno un id_stato_domanda che equivalente a INVIATA, flag f_istruita a ‘S’ e la data dt_consegna tra la data dt_dom_inv_da e dt_dom_inv_a della tabella ISCRITTO_T_STEP_GRA del record corrispondente allo step di graduatoria presa in considerazione da calcolare.
Inserimento nuove domande in graduatoria
4.	Per ogni record selezionato al punto 3 selezionare i record nella tabella ISCRITTO_R_SCUOLA_PRE attraverso l’id_domanda_iscrizione.
5.	Per ogni record selezionato al punto precedente si inserisce un record nella tabella ISCRITTO_T_GRADUATORIA:
•	id_graduatoria  sequenziale
•	id_step_gra_con l’id_step_gra_con da calcolare passata come parametro.
•	Id_scuola  id_scuola del record estratto 3
•	Id_domanda_iscrizione  id_domanda_iscrizione del record estratto al punto 3
•	Punteggio  NULL
•	Fl_fuori_termine  fl_fuori_termine del record estratto al punto 3
•	Id_tipo_frequenza  id_tipo_frequenza del record estratto al punto 3.
•	Id_stato_scu  lo stato che corrisponde a PENDENTE.
•	Isee  eseguire una query nella tabella ISCRITTO_R_PUNTEGGIO DOM con id_condizione_punteggio corrispondente a PAR_ISEE prendendo l’ultimo record valido. 
Se fl_valida <> ‘N’ inserire il valore ISCRITTO_T_ISEE.valore_isee
•	Ordine_preferenza  ISCRITTO_R_SCUOLA_PRE.posizione del record estratto al punto 6
•	Id_fascia_eta  id_fascia_eta del record sulla tabella ISCRITTO_T_ETA individuato dall’id_anagrafica_gra della graduatoria di cui si sta facendo il calcolo e la data data_nascita della tabella ISCRITTO_T_ANAGRAFICA_SOG del soggetto MIN deve essere compresa tra le date data_da e data_a
•	Ordinamento=NULL

Validazione condizione di punteggio CF_FRA_ISC
6.	Solo se lo step di graduatoria non aveva record in graduatoria verificare, per ogni domanda selezionata al punto 3 che:
•	ISCRITTO_T_DOMANDA_ISC.fl_fratello_freq=’S’ e ISCRITTO_T_FRATELLO_FRE.id_tipo_fra=2 ( ISCR ).
•	Accedere alla tabella ISCRITTO_R_PUNTEGGIO_DOM per id_domanda_isc, id_condizione_pun corrispondente a CF_FRA_ISC, dt_fine_validita=NULL e fl_valida=NULL 
•	Quando per la domanda è soddisfatta la condizione sopra riportata cercare una domanda in stato INSERITO e per lo stesso anno scolastico  per il minore avente lo stesso codice fiscale trovato in ISCRITTO_T_FRATELLO_FRE.cf_fratello. 
•	Se trovata inserire un record  eseguire un update nella tabella ISCRITTO_R_PUNTEGGIO_DOM con valorizzato nel seguente modo: filtrando il record per id_domanda_isc della domanda trovata e id_condizione_pun corrispondente a CF_FRA_ISC e dt_fine_validita=NULL e valorizzando i seguenti campi:
id_domanda_iscrizione= id_domanda elaborata
dt_inizio_validita = sysdate
dt_fine_validita= NULL
id_utente=NULL
fl_valida = ‘S’  se trovata altra domanda ‘N’ se non trovata
note=NULL se trovata altra domanda ‘Non trovato fratello/sorella iscrivendo’ se non trovata
ricorrenza= 1  
id_condizione_punteggio= 23 ( CF_FRA_ISC )
fl_integrazione=NULL.
7.	Calcolare il punteggio delle domande processo descritto nel documento “Calcolo_punteggio”.
Inserimento condizione di punteggio LA_PER
8.	Accedere alla tabella ISCRITTO_T_LISTA_ATTESA tramite il codice fiscale del soggetto della domanda che ha ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto=1 (MIN)
•	Attribuire il punteggio se è stato trovato record.
•	Valorizzare il campo ricorrenza con il numero di flag fl_anno1 e fl_anno2 valorizzati a ‘S’.
•	Valorizzare il flag fl_valida a ‘S’
Update valore ordinamento
9.	Selezionare tutti i record appena inseriti per lo step da calcolare.
10.	Dividere la selezione in blocchi per fascia d’età
11.	All’interno dei blocchi ordinare i record per:
A.	Fuori termine/Nei termini in base al flag fl_fuori_termine
B.	Punteggio decrescente
C.	Isee crescente ( se presente, Isee NULL bassa priorità ) 
D.	Età  precedenza a età maggiore per i lattanti ( 0-12 mesi ) e piccoli ( 13-24 mesi ) età minore per i grandi ( 25-36 mesi ). A parità di data di nascita occorre verificare anche l’ora di nascita).
E.	Data di inserimento domanda ( anche ora minuti e secondi ).
F.	Ordine di preferenza crescente.
12.	Eseguire l’update del campo ISCRITTO_T_GRADUATORIA.ordinamento con il valore derivante dall’ordinamento effettuato.

FLAG D
Copia dei record dal precedente id_step
1.	Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente nella stessa tabella con l’id_step_graduatoria_con da calcolare.
2.	AGGIORNAMENTO STATI/PUNTEGGIO DELLE SCUOLE E STATI DELLE DOMANDE
Impostare lo stato dei nidi delle domande in graduatoria a PENDENTE:
o	Eseguire una query sulla tabella ISCRITTO_T_GRADUATORIA filtrando per l’id_step_gra_con precedente
o	Per ogni record  trovato impostare il campo id_stato_scu con  il corrispondente stato con codice PEN e dt_stato con la sysdate nella tabella ISCRITTO_R_SCUOLA_PRE 
o	Per ogni id_domanda_iscr individuato nel primo step  impostare id_stato_dom con il corrispondente codice stato ‘IN GRAD’

FLAG S
Copia dei record dal precedente id_step
1.	Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente nella stessa tabella con l’id_step_graduatoria_con da calcolare.
Inserimento nuove domande in graduatoria
2.	Ripetere tutti gli step dal 3 al 8 del caso con il FLAG P.
Update valore ordinamento
3.	Ripetere tutti gli step dal 9 al 11 del caso con il FLAG P.
*/
CREATE OR REPLACE
FUNCTION CalcolaGraduatoria ( pIdStepGradDaCalcolare  INTEGER
                            , pIdStepGradPrecedente   INTEGER
                            , pFlag                   VARCHAR(1)
                            ) RETURNS SMALLINT AS
$BODY$
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
    --  3. Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente
    --      nella stessa tabella con l’id_step_graduatoria_con da calcolare.
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
    -- 1. Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente nella
    --    stessa tabella con l’id_step_graduatoria_con da calcolare.
    nRetCode = DuplicaGraduatoria(pIdStepGradPrecedente, pIdStepGradDaCalcolare);
    nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare);
    nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
  END IF;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
  Setta la data di ultimo calcolo punteggio
*/
CREATE OR REPLACE
FUNCTION SetDataUltimoCalcoloPunteggio  ( pDataUltimoCalcoloPunteggio TIMESTAMP WITHOUT TIME ZONE
                                        ) RETURNS INTEGER AS
$BODY$
DECLARE
BEGIN
  UPDATE  iscritto_t_parametro
    SET dt_ult_calcolo_pun = pDataUltimoCalcoloPunteggio;
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION FratelloFrequentante ( pIdDomandaIscrizione  INTEGER
                              ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  vFound  BOOLEAN;
BEGIN
  -- Verifico se il minore esiste ed è residente a Torino
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  vFound
    FROM  iscritto_t_fratello_fre   fraFre
        , iscritto_d_tipo_fra       tipFra
    WHERE fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
      AND fraFre.id_domanda_iscrizione = pIdDomandaIscrizione
      AND tipFra.cod_tipo_fratello = 'FREQ';
  RETURN vFound;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetPunteggio ( pIdScuola               INTEGER
                      , pIdCondizionePunteggio  INTEGER
                      ) RETURNS INTEGER AS
$BODY$
DECLARE
  vPunteggio    iscritto_t_punteggio.punti%TYPE;
  vIdPunteggio  iscritto_t_punteggio.id_punteggio%TYPE;
BEGIN
  SELECT  id_punteggio
        , punti
    INTO  vIdPunteggio
        , vPunteggio
    FROM  iscritto_t_punteggio
    WHERE id_condizione_punteggio = pIdCondizionePunteggio
      AND CURRENT_TIMESTAMP BETWEEN dt_inizio_validita AND COALESCE(dt_fine_validita,DATE '9999-12-31');
  BEGIN
    SELECT  punti_scuola
      INTO STRICT vPunteggio
      FROM  iscritto_r_punteggio_scu
      WHERE id_punteggio = vIdPunteggio
        AND id_scuola = pIdScuola
        AND CURRENT_TIMESTAMP BETWEEN dt_inizio_validita AND COALESCE(dt_fine_validita,DATE '9999-12-31');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      NULL;
  END;
  -------
  RETURN vPunteggio;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



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
                          id_scuola    id_scuola
                        , posizione    posizione
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
    UPDATE  iscritto_t_graduatoria
      SET punteggio = vPunteggio
      WHERE id_domanda_iscrizione = pIdDomandaIscrizione
        AND id_scuola = scuola.id_scuola
        AND id_step_gra_con = pIdStepGraCon;
  END LOOP;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
  Legge la data di ultimo calcolo punteggio
*/
CREATE OR REPLACE
FUNCTION GetDataUltimoCalcoloPunteggio() RETURNS DATE AS
$BODY$
DECLARE
  dDataUltimoCalcoloPunteggio DATE;
BEGIN
  SELECT  dt_ult_calcolo_pun
    INTO  dDataUltimoCalcoloPunteggio
    FROM  iscritto_t_parametro;
  RETURN dDataUltimoCalcoloPunteggio;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
CALCOLO PUNTEGGIO

Procedura batch eseguita giornalmente a seguire l’esecuzione della procedura di attribuzione condizioni di punteggio.
La procedura vuole come parametro di input id_step_gra_con che identifica i record in graduatoria.
La procedura elabora tutte le domande d’iscrizione che hanno avuto una modifica delle condizioni di punteggio compresi nei giorni tra la data
ultima elaborazione ( ISCRITTO_T_PARAMETRO.dt_ult_calcolo_pun) e la sysdate -1. e quelle che non hanno ancora il punteggio 
In alternativa la procedura deve poter accettare come parametri un range di date: data_da a data_a.
Al termine dell’esecuzione la procedura deve aggiornare la data di ultima elaborazione.

Verifica delle domande istruite
Elaborare tutte le domande d’iscrizione che hanno avuto una modifica delle condizioni di punteggio all’interno del range di date:
•	Tutte le domande che hanno almeno un record con
Sysdate -1 > = ISCRITTO_R_PUNTEGGIO_DOM.dt_inizio_validita => ISCRITTO_T_PARAMETRO.dt_ult_calcolo_pun
Tra tutte le domande selezionate, per ogni domanda verificare che se tutte le condizioni di punteggio cha hanno un’istruttoria di tipo
‘P’ ( preventiva ) sono state istruite ( validate o invalidate ) la domanda diventi ‘Istruita’ altrimenti se anche solo una condizione
non è stata ancora istruita allora la domanda deve essere ‘non istruita’.
•	Selezionare tutte le condizioni di punteggio della domanda valide e con tipologia di istruttoria ‘P’
o	ISCRITTO_R_PUNTEGGIO_DOM.dt_fine_validita is null
o	ISCRITTO_D_CONDIZIONE_PUN.fl_istruttoria=’P’
•	Se almeno una condizione di punteggio selezionata precedentemente ha ISCRITTO_R_PUNTEGGIO_DOM.fl_valida=NULL allora valorizzare
ISCRITTO_T_DOMANDA_ISC.fl_istruita=’N’ altrimenti se ‘S’.

Calcolo punteggio
La procedura calcola il punteggio in base alle condizioni di punteggio legate alla domanda e alla singola scuola della domanda
ed esegue un update sul campo ISCRITTO_R_PUNTEGGIO_SCU.punteggio ISCRITTO_T_GRADUATORIA.punteggio con il valore calcolato.

Parametri di in put:  l’id_domanda_isc

1.	Se il flag ISCRITTO_T_DOMANDA_ISC.fl_istruita = N allora la procedura termina con un errore .
Elaborare tutte le domande d’iscrizione in graduatoria ( ISCRITTO_T_GRADUATORIA.id_step_gra_con uguale a quello passato come parametro )
che hanno avuto una modifica delle condizioni di punteggio uguale o superiore alla data di calcolo e che sono istruite ISCRITTO_T_DOMANDA_ISC.fl_istruita=’S’.
oppure che hanno ISCRITTO_T_GRADUATORIA.punteggio=NULL
2.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per id_domanda_isc, per d_fine_validita= NULL e per fl_valida <> N
3.	Eseguire una query sulla tabella ISCRITTO_R_SCUOLA_PRE filtrando per id_domanda_isc per ricavare tutti gli id_scuola legati alla domanda.
4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio e sysdate
tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
5.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_SCU con id_punteggio dalla query precedente e per tutti gli id_scuola trovati al punto 3 e
sysdate tra dt_inizio_validita e dt_fine_validita . Questo per ricavare gli eventuali punteggi specifici per ogni scuola della condizione di punteggio
presa in considerazione.
6.	Moltiplicare per tutte le condizioni di punteggio valide della domanda ( 2 ) il valore contenuto nel campo ISCRITTO_R_PUNTEGGIO_DOM.ricorrenza
per il punteggio generico ( 4 ) o l’eventuale punteggio specifico ( 5 ) e sommare i risultati per ogni scuola.
Unica eccezione riguarda la condizione di punteggio che ha codice ‘CF_FRA_FRE’.
Se per questa condizione il valore nel campo ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 1 ( FREQ ) allora il punteggio di questa condizione deve essere
preso in considerazione solo per la scuola di prima scelta ( ISCRITTO_R_SCUOLA_PRE.POSIZIONE=1 ).
7.	Eseguire l’update del campo ISCRITTO_R_SCUOLA_PRE.punteggio  ISCRITTO_T_GRADUATORIA.punteggio con il valore calcolato al punto precedente
per ogni singola scuola della domanda.
*/
CREATE OR REPLACE
FUNCTION CalcolaPunteggio ( pIdStepGraCon INTEGER
                          ) RETURNS SMALLINT AS
$BODY$
DECLARE
  vDataUltimoCalcoloPunteggio iscritto_t_parametro.dt_ult_calcolo_pun%TYPE;
  grad                        RECORD;
  vRetCode                    SMALLINT;
BEGIN
  vDataUltimoCalcoloPunteggio = GetDataUltimoCalcoloPunteggio();
  -- Elaborare tutte le domande d’iscrizione in graduatoria ( ISCRITTO_T_GRADUATORIA.id_step_gra_con uguale a quello passato come parametro )
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
  vRetCode = SetDataUltimoCalcoloPunteggio(LOCALTIMESTAMP);
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



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



/*
ID_CONDIZIONE_PUNTEGGIO = 19
16.	Ogni permanenza in lista d’attesa al termine dei precedenti anni educativi (LA_PER).
  Accedere alla tabella ISCRITTO_T_LISTA_ATTESA tramite il codice fiscale del soggetto della domanda che ha ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto=1 (MIN)
    •	Attribuire il punteggio se sono stati trovati record.
    •	Valorizzare il campo ricorrenza con il numero di record trovati.
*/
CREATE OR REPLACE
FUNCTION Punteggio_LA_PER ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
  nRicorrenza INTEGER;
  rec   RECORD;
BEGIN
  nRicorrenza = 0;
  SELECT  *
    INTO STRICT rec
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
  IF rec.fl_anno1 = 'S' THEN
    nRicorrenza = nRicorrenza + 1;
  END IF;
  IF rec.fl_anno2 = 'S' THEN
    nRicorrenza = nRicorrenza + 1;
  END IF;
  -------
  RETURN nRicorrenza;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



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
    pFlagValida = 'S';
  ELSIF pCodCondizione = 'TR_TRA_NID' THEN
    pRicorrenza = Punteggio_TR_TRA_NID(pIdDomandaIscrizione);
  ELSIF pCodCondizione = 'PAR_ISEE' THEN
    pRicorrenza = Punteggio_PAR_ISEE(pIdDomandaIscrizione);
  END IF;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdOrdineScuola  ( IN  pCodOrdineScuola  VARCHAR(20)
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
  nIdOrdineScuola   iscritto_d_ordine_scuola.id_ordine_scuola%TYPE;
BEGIN
  SELECT  id_ordine_scuola
    INTO  nIdOrdineScuola
    FROM  iscritto_d_ordine_scuola
    WHERE cod_ordine_scuola = pCodOrdineScuola;
  RETURN nIdOrdineScuola;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
Procedura batch eseguita giornalmente alle 00:15 che attribuisce alle domande d’iscrizione processate le corrette condizioni di punteggio in base ai dati presenti sulla domanda stessa o al tipo di allegato.
La procedura viene eseguita con il parametro id_ordine scuola
La procedura elabora tutte le domande d’iscrizione o solo la documentazione allegata inviate/i nei giorni compresi tra la data ultima elaborazione ( ISCRITTO_T_PARAMETRO.dt_ult_attribuzione_pun) e la sysdate-1  delle domande presentate per l’ordine di scuola passato come parametro.
Al termine dell’esecuzione la procedura deve aggiornare la data di ultima elaborazione.
Elaborazione domande pervenute
Attività demandata ad un batch notturno giornaliero che prende in considerazione tutte le domande arrivate ( stato INVIATA ) nel giorno oppure in un range di date:
ISCRITTO_T_DOMANDA_ISC.data_consegna= sysdate  se il range di date è NULL altrimenti
Data_da <= ISCRITTO_T_DOMANDA_ISC.data_consegna <= data_a
La domanda selezionata non deve avere già dei record inseriti nella tabella ISCRITTO_R_PUNTEGGIO_DOM.
Il batch deve attribuire le condizioni di punteggio cioè inserire uno o più record nella tabella ISCRITTO_R_PUNTEGGIO_DOM con:
id_domanda_iscrizione= id_domanda
dt_inizio_validita = sysdate
dt_fine_validita= NULL
id_utente=NULL
note=NULL
ricorrenza= 1 o maggiore di 1 in base al numero di volte che ricorre la condizione di punteggio 
id_condizione_punteggio= uno degli id_condizione_punteggio delle condizioni punteggio elencati successivamente
fl_valida = NULL o ‘S’ in base a:
•	ISCRITTO_D_CONDIZIONE_PUN.fl_istruttoria=’N’  fl_valida =’S’
•	ISCRITTO_D_CONDIZIONE_PUN.fl_istruttoria <>’N’  fl_valida =NULL
Di seguito l’elenco delle condizioni di punteggio.
1.	RESIDENZA ( 3 4 Possibilità in alternativa )
Occorre individuare i due valore di id_anagrafica_sog dalla tabella ISCRITTO_R_SOGGETTO_REL accedendo per id_domanda_iscrizione e per id_tipo_soggetto=1 (MIN) e 2 (SOG1) e 3 (SOG2) se presente.
A.	Famiglie residenti a Torino ( RES_TO ). Il minore e il soggetto1 o soggetto2 devono essere residenti a Torino.
•	E’ soddisfatta questa condizione se accedendo alla tabella ISCRITTO_T_INDIRIZZO_RES con i valori di id_anagrafica_sog il campo ISCRITTO_T_INDIRIZZO_RES.id_comune= 8207 ( TORINO ) per entrambi per il MIN e almeno uno tra il SOG1 e il SOG2.
Se per questo soggetti il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ allora il flag fl_valida dovrà essere impostato a ‘S’.
•	Oppure se esiste un record nella tabella ISCRITTO_T_CAMBIO_RES per la domanda presa in considerazione.
B.	Famiglie prossimamente residenti a Torino ( RES_TO_FUT ).
E’ soddisfatta questa condizione se la condizione A non è verificata ed  esiste un record nella tabella ISCRITTO_T_CAMBIO_RES per la domanda presa in considerazione.
C.	Famiglie non residenti a Torino in cui almeno un genitore presta attività lavorativa in città ( RES_NOTO_LAV). 
La condizione A e la condizione B non è verificata e il soggetto 1 o il soggetto 2 o entrambi lavorano a Torino. 
•	Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC tramite gli id_anagrafica_sog dei soggetti con id_tipo_soggetto SOG1 e se esiste con SOG2 per individuare la tipologia di condizione occupazionale.
•	Se id_tip_condizione_occ corrisponde ‘DIP’ o ‘AUT’ di almeno uno dei due verificare che nel campo comune_lavoro della tabella ISCRITTO_T_DIPENDENTE o ISCRITTO_T_AUTONOMO in base alla tipologia di occupazione sia valorizzato a ‘TORINO’ (no case sensitive).
D.	Famiglie non residenti a Torino ( RES_NOTO ). 
E’ soddisfatta questa condizione se la A la B e la C non sono vere.
2.	Minore con disabilità certificata ( PA_DIS ). Assegnazione solo se presente l’allegato.
Se per il soggetto con ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto=1 (MIN)  ISCRITTO_T_CONDIZIONE_SAN.fl_disabilita=’S’ ed esiste un record con ISCRITTO_T_ALLEGATO.id_tipo_allegato=3 (DIS) per lo stesso id_anagrafica_sog.
3.	Gravi problemi di salute del minore o uno dei componenti il nucleo ( PA_PRB_SAL ). Assegnazione solo se presente l’allegato. 
Per ogni id_anagrafica_soggetto della domanda verificare se esiste almeno un record con  ISCRITTO_T_CONDIZIONE_SAN.fl_problemi_salute=’S’ e con ISCRITTO_T_ALLEGATO.id_tipo_allegato=2 (SAL) a parità di id_anagrafica_sog.
4.	Minore in situazione di disagio sociale ( PA_SOC ).  
Assegnazione se ISCRITTO_T_DOMANDA_ISC.fl_servizi_sociali=’S’ esiste un record nella tabella ISCRITTO_T_SERVIZI_SOC
5.	GENITORE SOLO ( 2 possibilità in alternativa )
A.	Minore con unico genitore ( GEN_SOLO ).
Attribuzione se per la domanda esiste un record nella tabella con ISCRITTO_T_GENITORE_SOLO.id_tipo_genitore_solo=’ GEN_DEC’ o ‘NUB_CEL_NO_RIC’ o ‘NO_RES_GEN’
B.	Minore con genitori separati ( GEN_SEP ). 
Attribuzione se per la domanda esiste un record nella tabella ISCRITTO_T_GENITORE_SOLO.id_tipo_genitore_solo=’ NUB_CEL_RIC’ o ‘DIV’ o ‘IST_SEP’ o ‘SEP’.
6.	Ogni figlio/a fino a 10 anni di età ( CF_INF_11 ). 
In questo caso si intende che il bambino/a deve avere un’età inferiore a 11 anni al 31/12 dell’anno scolastico di riferimento.
L’anno scolastico di riferimento si ricava selezionando il record dalla tabella ISCRITTO_T_ANAGRAFICA_GRA in cui la data di sistema è compresa tra la data dt_inizio_iscrizioni e la data dt_fine_iscr per recuperare l’id_anno_scolastico.
Con l’id_anno_scolastico si accede alla tabella ISCRITTO_T_ANNO_SCO per recuperare l’anno della data data_da. Esempio: se la data_da= ‘01/09/2018’  il bambino deve avere un’età inferiore a 11 anni alla data del 31/12/2018.
I soggetti a cui occorre effettuare il controllo dell’età sono:
•	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 4 (CMP_NUC) o 7 (ALT_CMP) che hanno ISCRITTO_T_ANAGRAFICA_SOG.id_rel_parentela in 1 (FGL_RICH FGL) o 2 (FGL_GEN) o 3 (FGL_COA) o 4 (MIN_AFF).
•	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
•	Se il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ per tutti i soggetti trovati allora il flag fl_valida dovrà essere impostato a ‘S’. 
•	Se i soggetti hanno tutti una residenza fuori Torino ( ISCRITTO_T_INDIRIZZO_RES.id_comune <> 8207 ( TORINO ) allora il flag fl_valida dovrà essere impostato a ‘S’.
7.	Ogni figlio/a fino a 10 anni di età di cui un genitore coabitante abbia l’affidamento condiviso (CF_INF_11_AFF_CON). 
In questo caso si intende che il bambino/a deve avere un’età inferiore a 11 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
I soggetti a cui occorre effettuare il controllo dell’età sono:
•	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 6 (AFF) 
•	Valorizzare il campo ricorrenza con il numero di soggetti trovati.

8.	Ogni figlio/a di età  tra 11 e 17 anni (CF_TRA_11_17). 
In questo caso si intende che il bambino/a deve avere un’età compresa tra gli 11 e i 17 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
I soggetti a cui occorre effettuare il controllo dell’età sono:
•	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 4 (CMP_NUC) o 7 (ALT_CMP) che hanno ISCRITTO_T_ANAGRAFICA_SOG.id_rel_parentela in 1 (FGL_RICH FGL) o 2 (FGL_GEN) o 3 (FGL_COA) o 4 (MIN_AFF).
•	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
•	Se il flag fl_residenza_NAO in tabella ISCRITTO_T_ANAGRAFICA_SOG è ‘S’ per tutti i soggetti trovati allora il flag fl_valida dovrà essere impostato a ‘S’. 
•	Se i soggetti hanno tutti una residenza fuori Torino ( ISCRITTO_T_INDIRIZZO_RES.id_comune <> 8207 ( TORINO ) allora il flag fl_valida dovrà essere impostato a ‘S’.
9.	Ogni figlio/a di età  tra 11 e 17 anni di cui un genitore coabitante abbia l’affidamento condiviso (CF_TRA_11_17_AFF_CON). 
In questo caso si intende che il bambino/a deve avere un’età compresa tra gli 11 e i 17 anni al 31/12 dell’anno scolastico di riferimento ( vedi punto 6 ).
I soggetti a cui occorre effettuare il controllo dell’età sono:
•	ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto= 6 (AFF) 
•	Valorizzare il campo ricorrenza con il numero di soggetti trovati.
10.	Presenza di fratelli/sorelle frequentanti lo stesso nido di prima scelta (CF_FRA_FRE).
Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_fratello_freq=’S’ e 
ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 1 ( FREQ ).
11.	Presenza di fratelli/sorelle iscrivendi gli stessi nidi (CF_FRA_ISC).
Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_fratello_freq=’S’ e 
ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 2 ( ISCR ).
12.	Stato di gravidanza della madre (CF_GRA).
Attribuzione della condizione di punteggio se esiste un soggetto della domanda che ha ISCRITTO_T_CONDIZIONE_SAN.fl_stato_gravidanza=’S’ e se c’è l’allegato cioè esiste un record con ISCRITTO_T_ALLEGATO.id_tipo_allegato=1 (GRA) per lo stesso id_anagrafica_sog.
13.	Genitore lavoratore (CL_LAV)
Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=1 (DIP) o 2 (AUT).
•	Attribuire il punteggio se sono stati trovati record.
•	Valorizzare il campo ricorrenza con il numero di record trovati.
14.	Genitore non occupato che alla scadenza iscrizioni ha lavorato almeno 6 mesi nei precedenti 12 (CL_NON_OCC).
Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=4 (DIS_LAV).
•	Attribuire il punteggio se sono stati trovati record.
•	Valorizzare il campo ricorrenza con il numero di record trovati.
15.	Genitore disoccupato da almeno tre mesi (CL_DIS).
Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=3 (DIS) e per i record trovati verificare che la data ISCRITTO_T_DISOCCUPATO.dt_dichiarazione_disponibili sia più vecchia di 3 mesi rispetto alla data ISCRITTO_T_DOMANDA_ISC.data_consegna. 
•	Attribuire il punteggio se sono stati trovati record.
•	Valorizzare il campo ricorrenza con il numero di record trovati che soddisfano anche il controllo della data.
16.	Genitore studente (CL_STU).
Accedere alla tabella ISCRITTO_T_CONDIZIONE_OCC filtrando per id_anagrafica_sog della domanda e per ISCRITTO_T_CONDIZIONE_OCC.id_tipo_cond_occupazionale=5 (STU).
•	Attribuire il punteggio se sono stati trovati record.
•	Valorizzare il campo ricorrenza con il numero di record trovati.
17.	Ogni permanenza in lista d’attesa al termine dei precedenti anni educativi (LA_PER).
Accedere alla tabella ISCRITTO_T_LISTA_ATTESA tramite il codice fiscale del soggetto della domanda che ha ISCRITTO_R_SOGGETTO_REL.id_tipo_soggetto=1 (MIN)
•	Attribuire il punteggio se sono stati trovati record.
•	Valorizzare il campo ricorrenza con il numero di record trovati.
18.	Trasferimento da nido della città (TR_TRA_NID).
Attribuzione della condizione di punteggio se ISCRITTO_T_DOMANDA_ISC.fl_trasferimento=’S’
19.	Condizione di precedenza ( PAR_ISEE )
Attribuzione della condizione di precedenza se ISCRITTO_T_DOMANDA_ISC.fl_isee=’S’

Elaborazione allegati pervenuti
Per questa seconda fase le operazioni da eseguire sono le seguenti:
1.	Verificare se la sysdate è minore della alla data limite per la considerazione degli allegati
•	Eseguire una query sulla tabella ISCRITTO_T_STEP_GRA filtrando per dt_step_gra <= sysdate e id_anagrafica_gra corrispondente alle graduatorie appartenenti all’ordine scolastico passato come parametro e ordinare per dt_step_gra discendente.
•	Se dt_allegati del primo record della query è >= sysdate si procede al punto 2, altrimenti la procedura termina.
2.	Selezionare tutti gli allegati arrivati nel giorno o nel range di date preso in considerazione raggruppandoli per id_tipo_allegato.
•	Selezionare gli allegati da processare filtrando ISCRITTO_T_ALLEGATO.data_inserimento= sysdate  se il range di date è NULL altrimenti Data_da<=ISCRITTO_T_ALLEGATO.data_inserimento <= data_a
3.	La domanda d’iscrizione degli allegati selezionati al punto 2 non deve avere la data di consegna uguale alla data di inserimento dell’allegato ( perché già presi in considerazione nell’elaborazione delle domande ).
•	ISCRITTO_T_DOMANDA_ISC.data_consegna <> ISCRITTO_T_ALLEGATO.data_inserimento
4.	Per tutti gli allegati rimasti dopo il punto 3 verificare il tipo di allegato e associare la condizione di punteggio appropriata alla domanda dell’allegato.
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
o	Se fl_valida = N inserire nel campo d_fine_validita il valore sysdate-1 secondo nel record valido e poi inserire il nuovo record.
*/
CREATE OR REPLACE
FUNCTION AttribuisciCondizioni  ( pCodOrdineScuola  VARCHAR(20)
                                , pDataDa           DATE
                                , pDataA            DATE
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
  vFound                  BOOLEAN;
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
                      AND id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
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
                      WHERE cod_condizione <> 'LA_PER'
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
  /*
      1.	Verificare se la sysdate è minore della alla data limite per la considerazione degli allegati
    •	Eseguire una query sulla tabella ISCRITTO_T_STEP_GRA filtrando per dt_step_gra <= sysdate e id_anagrafica_gra corrispondente alle graduatorie
        appartenenti all’ordine scolastico passato come parametro e ordinare per dt_step_gra discendente.
    •	Se dt_allegati del primo record della query è >= sysdate si procede al punto 2, altrimenti la procedura termina.
  */
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  vFound
    FROM  ( SELECT  dt_allegati
              FROM  ( SELECT  stepGra.dt_allegati   dt_allegati
                        FROM  iscritto_t_step_gra         stepGra
                            , iscritto_t_anagrafica_gra   anagGra
                        WHERE stepGra.id_anagrafica_gra = anagGra.id_anagrafica_gra
                          AND stepGra.dt_step_gra <= CURRENT_DATE
                          AND anagGra.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
                        ORDER BY  stepGra.dt_step_gra DESC
                    )       a
              LIMIT 1
          )                 b
    WHERE dt_allegati >= CURRENT_DATE;
  IF vFound THEN
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
  END IF;
  -------
  nRetCode = SetDataUltimaAttribuzione(dDataA);
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION DuplicaGraduatoria ( pIdStepOrigine      INTEGER
                            , pIdStepDestinazione INTEGER
                            ) RETURNS INTEGER AS
$BODY$
DECLARE
BEGIN
  INSERT INTO iscritto_t_graduatoria
              ( id_graduatoria
              , id_scuola
              , id_domanda_iscrizione
              , punteggio
              , fl_fuori_termine
              , id_tipo_frequenza
              , isee
              , ordine_preferenza
              , id_fascia_eta
              , ordinamento
              , id_stato_scu
              , id_step_gra_con
              )
    SELECT  nextval('iscritto_t_graduatoria_id_graduatoria_seq')
          , id_scuola
          , id_domanda_iscrizione
          , punteggio
          , fl_fuori_termine
          , id_tipo_frequenza
          , isee
          , ordine_preferenza
          , id_fascia_eta
          , ordinamento
          , id_stato_scu
          , pIdStepDestinazione
      FROM  iscritto_t_graduatoria
      WHERE id_step_gra_con = pIdStepOrigine;
  --------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdCondizionePunteggio ( IN  pCodCondizionePunteggio VARCHAR(20)
                                  ) RETURNS INTEGER AS
$BODY$
DECLARE
  nIdCondizionePunteggio  iscritto_d_condizione_pun.id_condizione_punteggio%TYPE;
BEGIN
  SELECT  id_condizione_punteggio
    INTO  nIdCondizionePunteggio
    FROM  iscritto_d_condizione_pun
    WHERE cod_condizione = pCodCondizionePunteggio;
  RETURN nIdCondizionePunteggio;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION DomandaDaElaborare ( pIdDomandaIscrizione  INTEGER
                            ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  vFound  BOOLEAN;
BEGIN
  -- Verifico se la domanda è ancora da elaborare per l'attribuzione dei posti
  SELECT  CASE WHEN COUNT(1) = 0 THEN TRUE ELSE FALSE END
    INTO  vFound
    FROM  iscritto_tmp_domanda
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione;
  RETURN vFound;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;

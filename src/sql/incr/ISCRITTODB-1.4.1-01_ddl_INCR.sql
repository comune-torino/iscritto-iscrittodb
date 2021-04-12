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



CREATE OR REPLACE
FUNCTION GetIdAnnoScolastico  ( IN  pIdStepGraduatoriaCon INTEGER
                              ) RETURNS INTEGER AS
$BODY$
DECLARE
  vIdAnnoScolastico iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
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
  -----
  RETURN vIdAnnoScolastico;
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
              , CURRENT_TIMESTAMP + interval '1 second'
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
    vIdStepGraConNew = vIdStepGraCon;
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
                  AND gr.id_step_gra_con = vIdStepGraConNew
  LOOP
    IF COALESCE(grad.id_stato_scuola_graduatoria,-1) <> COALESCE(grad.id_stato_scuola_pre,-1)
        OR COALESCE(grad.punteggio_graduatoria,-1) <> COALESCE(grad.punteggio_scuola_pre,-1) THEN
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
              , GetTestoSmsAmmissione(grad.id_domanda_iscrizione)
              , grad.id_domanda_iscrizione
              , CURRENT_TIMESTAMP
              , GetTelefonoSms(grad.id_domanda_iscrizione)
              );
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
•	Selezionare i record ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente ad AMMESSO, ISCRITTO_T_GRADUATORIA.id_step_gra_con=ISCRITTO_T_PARAMETRO.step_in_corso
•	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu con lo stato corrispondente a RINUNCIA AUTOMATICA  
•	Impostare lo stato di RINUNCIA AUTOMATICA anche su ISCRITTO_R_SCUOLA_PRE selezionando il record con id_scuola, id_domanda_iscrizione e id_tipo_frequenza.    
2.	Per ogni record selezionato al punto 1 verificare se la scuola è quella di prima scelta:
•	ISCRITTO_T_GRADUATORIA.ordine_preferenza=1
3.	Se la condizione al punto 2 è verificata occorre inserire lo stato CANCELLAZIONE PER RINUNCIA PRIMA SCELTA per le altre scuole della domanda che sono ancora nello stato di PENDENTE:
•	Selezione delle altre scuole della domanda:
•	ISCRITTO_T_GRADUATORIA.id_domanda_iscrizione= id_iscrizione della domanda  posta a RINUNCIA AUTOMATICA e ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a PENDENTE e sempre ISCRITTO_T_GRADUATORIA.id_step_gra dello step in corso.
•	Impostare per le scuole trovate lo stato di CANCELLATO PER RINUNCIA PRIMA SCELTA
•	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu con lo stato corrispondente a CANCELLATO PER RINUNCIA PRIMA SCELTA e ISCRITTO_T_GRADUATORIA.dt_stato con la sysdate. 
•	Impostare lo stato della domanda a RINUNCIATO
•	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN
4.	Se la condizione 2 non è verificata occorre verificare se per la domanda sono state già operate 2 rinunce sulle altre scuole di preferenza:
•	Selezione delle eventuali altre scuole RINUNCIATE della domanda :
•	ISCRITTO_T_GRADUATORIA.id_domanda_iscrizione= id_iscrizione della domanda posta a RINUNCIA AUTOMATICA escludendo la scuola stessa e ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a RINUNCIATO o RINUNCIA AUTOMATICA e sempre ISCRITTO_T_GRADUATORIA.id_step_gra dello step in corso.
5.	Se sono stati trovati due record impostare lo stato di CANCELLATO PER RINUNCIA alle eventuali altre scuole di preferenza della domanda ancora in stato PENDENTE:
•	Selezione delle altre scuole della domanda ISCRITTO_T_GRADUATORIA.id_domanda_iscrizione= id_iscrizione della domanda  posta a RINUNCIA AUTOMATICA e ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a PENDENTE e sempre ISCRITTO_T_GRADUATORIA.id_step_gra dello step in corso.
•	Impostare ISCRITTO_T_GRADUATORIA.id_stato_scu corrispondente a CANCELLATO PER RINUNCIA.
•	Impostare ISCRITTO_R_SCUOLA_PRE e ISCRITTO_T_GRADUATORIA.dt_stato con la sysdate.
•	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato RIN

6.	Se le condizioni al punto 2 e 4 non sono verificate occorre portare lo stato della domanda ‘IN GRADUATORIA’.
•	Impostare ISCRITTO_T_DOMANDA_ISC.id_stato_dom con lo stato ‘IN GRADUATORIA’

7.	Eliminare i posti ammessi nelle classi ( uguale all’operazione che viene eseguita dalla function ‘attribuisciposti’ )
•	Individuare l’anno scolastico e le scuole attraverso le tabelle messe in join: ISCRITTO_T_STEP_GRA_CON, ISCRITTO_T_STEP_GRA, ISCRITTO_T_ANAGRAFICA_GRA, ISCRITTO_T_SCUOLA filtrando per lo step in corso.
•	Selezionare i record dalla tabella ISCRITTO_T_CLASSE filtrando per id_anno_scolastico, id__scuola individuati al passo precedente e per posti_ammessi<>0
•	Per ogni record di ISCRITTO_T_CLASSE individuato impostare posti_liberi= posti_liberi+posti_ammessi e posti ammessi=0.


8.	Impostare il flag fl_ammissioni=’S’ nel record di tabella ISCRITTO_T_STEP_GRA per la graduatoria in corso
*/
CREATE OR REPLACE
FUNCTION Rinuncia ( pCodOrdineScuola  VARCHAR(20)
                  ) RETURNS SMALLINT AS
$BODY$
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
          AND id_graduatoria <> grad.id_graduatoria
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
    -------
    /*
      7.	Eliminare i posti ammessi nelle classi ( uguale all’operazione che viene eseguita dalla function ‘attribuisciposti’ )
        •	Individuare l’anno scolastico e le scuole attraverso le tabelle messe in join: ISCRITTO_T_STEP_GRA_CON, ISCRITTO_T_STEP_GRA, ISCRITTO_T_ANAGRAFICA_GRA, ISCRITTO_T_SCUOLA filtrando per lo step in corso.
        •	Selezionare i record dalla tabella ISCRITTO_T_CLASSE filtrando per id_anno_scolastico, id__scuola individuati al passo precedente e per posti_ammessi<>0
        •	Per ogni record di ISCRITTO_T_CLASSE individuato impostare posti_liberi= posti_liberi+posti_ammessi e posti ammessi=0.
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


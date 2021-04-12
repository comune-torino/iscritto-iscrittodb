/*
 modifiche di struttura base dati
 */
ALTER TABLE iscritto_r_scuola_pre ADD COLUMN dt_ins_scu TIMESTAMP WITHOUT TIME ZONE;
ALTER TABLE iscritto_t_parametro ADD COLUMN testo_mail_eco CHARACTER VARYING(500);
CREATE TABLE  iscritto_tmp_flusso
              ( id_tmp_fusso  INTEGER
              , record        VARCHAR(1000)
              );

/*
aggiornamenti/nuove procedure 
*/
CREATE OR REPLACE
FUNCTION FratelloIscrivendo ( pIdDomandaIscrizione  INTEGER
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
      AND tipFra.cod_tipo_fratello = 'ISCR';
  RETURN vFound;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION EsistePreferenzaScuola ( IN  pIdDomandaIscrizione  INTEGER
                                , IN  pIdScuola             INTEGER
                                ) RETURNS BOOLEAN AS
$BODY$
DECLARE
  bFound  BOOLEAN;
BEGIN
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  bFound
    FROM  iscritto_r_scuola_pre
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
      AND id_scuola = pIdScuola;
  --------
  RETURN bFound;
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
  vPunteggio                    iscritto_t_graduatoria.punteggio%TYPE;
  vPunteggioSpecifico           iscritto_r_punteggio_scu.punti_scuola%TYPE;
  vValoreIsee                   iscritto_t_isee.valore_isee%TYPE;
  nIdDomandaIscrizioneFratello  iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
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
              •	Domanda 1 quella sottoposta al calcolo del punteggio
              •	Domanda 2 quella in cui ISCRITTO_T_FRATELLO_FRE.cf_fratello della domanda 1 è uguale a ISCRITTO_T_ANAGRAFICA_SOG.codice_fiscale
                del minore della domanda 2.
              Esempio:
                1° scelta 	2° scelta	3° scelta
                      Domanda 1	Scuola 1	Scuola 2	
                      Domanda 2	Scuola 2	Scuola 3	Scuola 1
                Nell’esempio riportato la Scuola 1 e la scuola 2 avranno i punti per la condizione di punteggio CF_FRA_ISC per entrambe
                le domande mentre non ce l’avrà la scuola 3.
        */
        IF FratelloIscrivendo(pIdDomandaIscrizione) THEN
          nIdDomandaIscrizioneFratello = GetIdDomandaIscrizioneFratello(pIdDomandaIscrizione);
          IF EsistePreferenzaScuola(nIdDomandaIscrizioneFratello, scuola.id_scuola) THEN
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
CALCOLO PUNTEGGIO

Procedura batch eseguita giornalmente a seguire l’esecuzione della procedura di attribuzione condizioni di punteggio.
La procedura vuole come parametro di input id_step_gra_con che identifica i record in graduatoria.
La procedura elabora tutte le domande d’iscrizione in graduatoria che hanno avuto una modifica delle condizioni di punteggio compresi nei giorni tra la data ultima elaborazione ( ISCRITTO_T_PARAMETRO.dt_ult_calcolo_pun) e la sysdate -1. e quelle che non hanno ancora il punteggio 
In alternativa la procedura deve poter accettare come parametri un range di date: data_da a data_a.
Al termine dell’esecuzione la procedura deve aggiornare la data di ultima elaborazione.

Verifica delle domande istruite
Elaborare tutte le domande d’iscrizione che hanno avuto una modifica delle condizioni di punteggio all’interno del range di date:
•	Tutte le domande che hanno almeno un record con
Sysdate -1 > = ISCRITTO_R_PUNTEGGIO_DOM.dt_inizio_validita => ISCRITTO_T_PARAMETRO.dt_ult_calcolo_pun
Tra tutte le domande selezionate, per ogni domanda verificare che se tutte le condizioni di punteggio cha hanno un’istruttoria di tipo ‘P’ ( preventiva ) sono state istruite ( validate o invalidate ) la domanda diventi ‘Istruita’ altrimenti se anche solo una condizione non è stata ancora istruita allora la domanda deve essere ‘non istruita’.
•	Selezionare tutte le condizioni di punteggio della domanda valide e con tipologia di istruttoria ‘P’
o	ISCRITTO_R_PUNTEGGIO_DOM.dt_fine_validita is null
o	ISCRITTO_D_CONDIZIONE_PUN.fl_istruttoria=’P’
•	Se almeno una condizione di punteggio selezionata precedentemente ha ISCRITTO_R_PUNTEGGIO_DOM.fl_valida=NULL allora valorizzare ISCRITTO_T_DOMANDA_ISC.fl_istruita=’N’ altrimenti se ‘S’.

Calcolo punteggio
La procedura calcola il punteggio in base alle condizioni di punteggio legate alla domanda e alla singola scuola della domanda ed esegue un update sul campo ISCRITTO_R_PUNTEGGIO_SCU.punteggio ISCRITTO_T_GRADUATORIA.punteggio con il valore calcolato.

Parametri di in put:  l’id_domanda_isc

1.	Se il flag ISCRITTO_T_DOMANDA_ISC.fl_istruita = N allora la procedura termina con un errore .
Elaborare tutte le domande d’iscrizione in graduatoria ( ISCRITTO_T_GRADUATORIA.id_step_gra_con uguale a quello passato come parametro ) che hanno avuto una modifica delle condizioni di punteggio uguale o superiore alla data di calcolo e che sono istruite ISCRITTO_T_DOMANDA_ISC.fl_istruita=’S’. oppure che hanno ISCRITTO_T_GRADUATORIA.punteggio=NULL
2.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM filtrando per id_domanda_isc, per d_fine_validita= NULL e per fl_valida <> N
3.	Eseguire una query sulla tabella ISCRITTO_R_SCUOLA_PRE filtrando per id_domanda_isc per ricavare tutti gli id_scuola legati alla domanda.
4.	Per ogni record selezionato al punto 2 eseguire una query sulla tabella ISCRITTO_T_PUNTEGGIO filtrando per id_condizione_punteggio e sysdate tra dt_inizio_validita e dt_fine_validita per ricavare il valore di punteggio generico per la condizione di punteggio.
5.	Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_SCU con id_punteggio dalla query precedente e per tutti gli id_scuola trovati al punto 3 e sysdate tra dt_inizio_validita e dt_fine_validita . Questo per ricavare gli eventuali punteggi specifici per ogni scuola della condizione di punteggio presa in considerazione.
6.	Moltiplicare per tutte le condizioni di punteggio valide della domanda ( 2 ) il valore contenuto nel campo ISCRITTO_R_PUNTEGGIO_DOM.ricorrenza per il punteggio generico ( 4 ) o l’eventuale punteggio specifico ( 5 ) e sommare i risultati per ogni scuola.
Unica eccezione riguarda la condizione di punteggio che ha codice ‘CF_FRA_FRE’ e ‘CF_FRA_ISC’.
‘CF_FRA_FRE’:
Se per questa condizione il valore nel campo ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 1 ( FREQ ) allora il punteggio di questa condizione deve essere preso in considerazione solo per la scuola di prima scelta ( ISCRITTO_R_SCUOLA_PRE.POSIZIONE=1 ).
‘CF_FRA_ISC’:
Se per questa condizione il valore nel campo ISCRITTO_T_FRATELLO_FRE.id_tipo_fratello = 2 ( ISCR ) allora il punteggio di questa condizione deve essere preso in considerazione solo per le scuole di preferenza scelte da entrambe le domande:
•	Domanda 1 quella sottoposta al calcolo del punteggio
•	Domanda 2 quella in cui ISCRITTO_T_FRATELLO_FRE.cf_fratello della domanda 1 è uguale a ISCRITTO_T_ANAGRAFICA_SOG.codice_fiscale del minore della domanda 2.
Esempio:
	1° scelta 	2° scelta	3° scelta
Domanda 1	Scuola 1	Scuola 2	
Domanda 2	Scuola 2	Scuola 3	Scuola 1

Nell’esempio riportato la Scuola 1 e la scuola 2 avranno i punti per la condizione di punteggio CF_FRA_ISC per entrambe le domande mentre non ce l’avrà la scuola 3.
7.	Eseguire l’update del campo ISCRITTO_R_SCUOLA_PRE.punteggio  ISCRITTO_T_GRADUATORIA.punteggio con il valore calcolato al punto precedente per ogni singola scuola della domanda.
8.	Eseguire una query nella tabella ISCRITTO_R_PUNTEGGIO DOM con id_condizione_punteggio corrispondente a PAR_ISEE prendendo l’ultimo record valido.
Se fl_valida <> ‘N’ inserire il valore ISCRITTO_T_ISEE.valore_isee in ISCRITTO_T_GRADUATORIA.isee altrimenti inserire NULL.
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
•	Attribuire il punteggio se è stato trovato il record e solo se nella tabella ISCRITTO_R_PUNTEGGIO_DOM non ci sono record con id_condizione_punteggio corrispondente a LA_PER per la domanda .
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
o	Per ogni record  trovato impostare il campo id_stato_scu con  il corrispondente stato con codice PEN, punteggio con ISCRITTO_T_GRADUATORIA.punteggio e dt_stato con la sysdate nella tabella ISCRITTO_R_SCUOLA_PRE 
o	Per ogni id_domanda_iscr individuato nel primo step  impostare id_stato_dom con il corrispondente codice stato ‘IN GRAD’

FLAG S
Copia dei record dal precedente id_step
•	Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l’id_step_graduatoria_con precedente nella stessa tabella con l’id_step_graduatoria_con da calcolare.
Inserimento in graduatoria scuole fuori termine
•	Per tutte le domande copiate nella nuova graduatoria occorre verificare se nella data dello step sono state aggiunte scuole di preferenza: ISCRITTO_R_SCUOLA_PRE.dt_ins_scu compresa tra ISCRITTO_T_STEP_GRA.dt_dom_inv_da  e ISCRITTO_T_STEP_GRA.dt_dom_inv_a
•	Per ogni record di ISCRITTO_R_SCUOLA_PRE trovato nel passo precedente:
o	Eseguire lo step 5 del caso con il FLAG P.
Inserimento nuove domande in graduatoria
•	Ripetere tutti gli step dal 3 al 8 del caso con il FLAG P.
Update valore ordinamento
•	Ripetere tutti gli step dal 9 al 11 del caso con il FLAG P.
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
    nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare);
    nRetCode = AttribuisciCondizione(pIdStepGradDaCalcolare, 'LA_PER');
    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);
    nRetCode = DuplicaGraduatoria(pIdStepGradPrecedente, pIdStepGradDaCalcolare);
    /* Inserimento in graduatoria scuole fuori termine
          •	Per tutte le domande copiate nella nuova graduatoria occorre verificare se nella data dello step sono state aggiunte
            scuole di preferenza: ISCRITTO_R_SCUOLA_PRE.dt_ins_scu compresa tra ISCRITTO_T_STEP_GRA.dt_dom_inv_da
            e ISCRITTO_T_STEP_GRA.dt_dom_inv_a
          •	Per ogni record di ISCRITTO_R_SCUOLA_PRE trovato nel passo precedente:
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
    nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
  END IF;
  -------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetIdDomandaIscrizioneFratello ( IN  pIdDomandaIscrizione  INTEGER
                                        ) RETURNS INTEGER AS
$BODY$
DECLARE
  nIdDomandaIscrizioneFratello  iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
BEGIN
  SELECT  DISTINCT
            anagSog2.id_domanda_iscrizione
    INTO  nIdDomandaIscrizioneFratello
    FROM  iscritto_t_anagrafica_sog   anagSog1
        , iscritto_t_fratello_fre     fraFre
        , iscritto_t_anagrafica_sog   anagSog2
        , iscritto_r_soggetto_rel     relSog2
        , iscritto_d_tipo_sog         tipSog2
    WHERE anagSog1.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND UPPER(fraFre.cf_fratello) = UPPER(anagSog2.codice_fiscale)
      AND anagSog2.id_anagrafica_soggetto = relSog2.id_anagrafica_soggetto
      AND relSog2.id_tipo_soggetto = tipSog2.id_tipo_soggetto
      AND tipSog2.cod_tipo_soggetto = 'MIN'
      AND anagSog1.id_domanda_iscrizione = pIdDomandaIscrizione;
  --------
  RETURN nIdDomandaIscrizioneFratello;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetCodFasciaEta  ( IN  pIdDomandaIscrizione  INTEGER
                          ) RETURNS VARCHAR AS
$BODY$
DECLARE
  sCodFasciaEta   iscritto_d_fascia_eta.cod_fascia_eta%TYPE;
BEGIN
  SELECT  cod_fascia_eta
    INTO  sCodFasciaEta
    FROM  iscritto_d_fascia_eta
    WHERE id_fascia_eta = GetIdFasciaEta(pIdDomandaIscrizione);
  RETURN sCodFasciaEta;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



/*
TRASFERIMENTO DATI ISCRITTO/SISE

La procedura trasferisce i dati del minore e richiedente che hanno accettato il posto ( ISCRITTO ) nel gestionale che si occupa di gestire il servizio del nido e refezione scolastica ( SISE ).
La procedura verrà eseguita giornalmente ed è suddivisa logicamente in due parti: procedura di export dati da ISCRITTO e procedura di import dati su SISE.

Procedura di export dati da ISCRITTO.
La procedura preleva tutti i dati necessari del minore e del richiedente delle domande accettate che non sono ancora stati trasferiti in SISE.
•	Selezionare tutti i record in cui ISCRITTO_T_INVIO_ACC.dt_invio_sise è NULL
•	Creare un file csv con separatore il carattere ‘;’, contenente un item per ogni record selezionato formattato  nel tracciato record definito ( vedi paragrafo dedicato ).
•	I valori di Codice fiscale, cognome, nome vanno presi dalla tabella ISCRITTO_T_ANAGRAFICA_SOG nel record indicato con il codice tipo soggetto ‘MIN’ per il minore e ‘RIC’ per il richiedente nella tabella ISCRITTO_R_SOGGETTO_REL. Alla tabella ISCRITTO_T_ANAGRAFICA_SOG si accede con l’id_domanda_isc preso dalla tabella ISCRITTO_T_ACC_RIN
•	Il numero di telefono dalla tabella ISCRITTO_T_INVIO_ACC.telefono
•	La data di nascita del minore dalla tabella ISCRITTO_T_ANAGRAFICA_SOG.data_nascita
•	L’indirizzo di residenza e CAP e il comune dalla tabella ISCRITTO_T_INDIRIZZO_RES. Per il comune occorre recuperare il codice istat dalla tabella ISCRITTO_T_COMUNE.
•	Il codice del nido dalla tabella ISCRITTO_T_SCUOLA accedendo con l’id_scuola
•	Il codice della fascia d’età recuperato accedendo alla tabella ISCRITTO_T_DOMANDA_ISC con l’id_domanda_iscrizione e recuperando l’id_anno_scolastico e id_ordine_scuola e poi accedendo alla tabella ISCRITTO_T_ANAGRAFICA_GRA per recuperare l’id_anagrafica_graduatoria. Infine con l’id_anagrafica_graduatoria accedere alla tabella ISCRITTO_T_ETA e recuperare il record in cui data_nascita del minore è compresa tra data_da e data_a.  Accedere poi alla tabella ISCRITTO_D_FASCIA con l’id_fascia_eta per recuperare il codice fascia.
•	Il codice del tempo di frequenza accedendo alla tabella ISCRITTO_D_TIPO_FRE con l’id_tipo_frequenza della tabella ISCRITTO_T_ACC_RIN.
•	La data di inizio e fine anno scolastico dalla tabella ISCRITTO_T_ANNO_SCO in data_da e data_a.
•	La data di accettazione ISCRITTO_T_ACC_RIN.dt_operazione.
•	Esito trasferimento e Dettaglio errore verranno valorizzati dalla procedura di import.

Tracciato record del file
Il tracciato record del file deve essere così composto:
•	Codice fiscale minore
•	Cognome minore
•	Nome minore
•	Codice fiscale richiedente
•	Cognome richiedente
•	Nome richiedente
•	Telefono
•	Data nascita minore
•	Indirizzo residenza
•	CAP
•	Codice istat comune di residenza
•	Codice nido accettazione
•	Codice fascia d’età
•	Tempo di frequenza
•	Data inizio anno scolastico
•	Data fine anno scolastico
•	Data accettazione
•	Esito trasferimento
•	Dettaglio errore
*/
CREATE OR REPLACE
FUNCTION PreparaDatiSise() RETURNS SMALLINT AS
$BODY$
DECLARE
  rec RECORD;
  sCodiceFiscaleRichiedente   iscritto_t_anagrafica_sog.codice_fiscale%TYPE;
  sCognomeRichiedente         iscritto_t_anagrafica_sog.cognome%TYPE;
  sNomeRichiedente            iscritto_t_anagrafica_sog.nome%TYPE;
  nIdTmpFlusso                iscritto_tmp_flusso.id_tmp_fusso%TYPE;
  sRecord                     iscritto_tmp_flusso.record%TYPE;
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
                    , indRes.indirizzo              indirizzo_residenza
                    , indRes.cap                    cap_residenza
                    , com.istat_comune              istat_comune_residenza
                    , scu.cod_scuola                cod_nido_accettazione
                    , tipFre.cod_tipo_frequenza     cod_tipo_frequenza
                    , annoSco.data_da               inizio_anno_scolastico
                    , annoSco.data_a                fine_anno_scolastico
                    , accRin.dt_operazione          data_accettazione
                    , isee.valore_isee              valore_isee
                FROM  iscritto_t_invio_acc        invAcc
                    , iscritto_t_acc_rin          accRin
                    , iscritto_t_domanda_isc      domIsc
                    , iscritto_t_anagrafica_sog   anagSog
                    , iscritto_r_soggetto_rel     sogRel
                    , iscritto_d_tipo_sog         tipSog
                    , iscritto_t_indirizzo_res    indRes
                    , iscritto_t_comune           com
                    , iscritto_t_scuola           scu
                    , iscritto_d_tipo_fre         tipFre
                    , iscritto_t_anno_sco         annoSco
                    , iscritto_t_isee             isee
                WHERE invAcc.id_accettazione_rin = accRin.id_accettazione_rin
                  AND accRin.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                  AND domIsc.id_domanda_iscrizione = anagSog.id_domanda_iscrizione
                  AND anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
                  AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
                  AND tipSog.cod_tipo_soggetto = 'MIN'
                  AND anagSog.id_anagrafica_soggetto = indRes.id_anagrafica_soggetto
                  AND indRes.id_comune = com.id_comune
                  AND accRin.id_scuola = scu.id_scuola
                  AND accRin.id_tipo_frequenza = tipFre.id_tipo_frequenza
                  AND domIsc.id_anno_scolastico = annoSco.id_anno_scolastico
                  AND domIsc.id_domanda_iscrizione = isee.id_domanda_iscrizione
                  AND invAcc.dt_invio_sise IS NULL
  LOOP
    SELECT  anagSog.codice_fiscale
          , anagSog.cognome
          , anagSog.nome
      INTO  sCodiceFiscaleRichiedente
          , sCognomeRichiedente
          , sNomeRichiedente
      FROM  iscritto_t_anagrafica_sog   anagSog
          , iscritto_r_soggetto_rel     sogRel
          , iscritto_d_tipo_sog         tipSog
      WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
        AND sogRel.id_tipo_soggetto = tipSog.id_tipo_soggetto
        AND anagSog.id_domanda_iscrizione = rec.id_domanda_iscrizione
        AND tipSog.cod_tipo_soggetto = 'RIC';
    nIdTmpFlusso = nIdTmpFlusso + 1;
    ---------
    sRecord = rec.codice_fiscale_minore;                                            -- •	Codice fiscale minore
    sRecord = sRecord || ';' || rec.cognome_minore;                                 -- •	Cognome minore
    sRecord = sRecord || ';' || rec.nome_minore;                                    -- •	Nome minore
    sRecord = sRecord || ';' || sCodiceFiscaleRichiedente;                          -- •	Codice fiscale richiedente
    sRecord = sRecord || ';' || sCognomeRichiedente;                                -- •	Cognome richiedente
    sRecord = sRecord || ';' || sNomeRichiedente;                                   -- •	Nome richiedente
    sRecord = sRecord || ';' || rec.telefono;                                       -- •	Telefono
    sRecord = sRecord || ';' || TO_CHAR(rec.data_nascita_minore,'DD/MM/YYYY');      -- •	Data nascita minore
    sRecord = sRecord || ';' || rec.indirizzo_residenza;                            -- •	Indirizzo residenza
    sRecord = sRecord || ';' || rec.cap_residenza;                                  -- •	CAP
    sRecord = sRecord || ';' || rec.istat_comune_residenza;                         -- •	Codice istat comune di residenza
    sRecord = sRecord || ';' || rec.valore_isee;                                    -- •	Valore ISEE
    sRecord = sRecord || ';' || rec.cod_nido_accettazione;                          -- •	Codice nido accettazione
    sRecord = sRecord || ';' || GetCodFasciaEta(rec.id_domanda_iscrizione);         -- •	Codice fascia d’età
    sRecord = sRecord || ';' || rec.cod_tipo_frequenza;                             -- •	Tempo di frequenza
    sRecord = sRecord || ';' || TO_CHAR(rec.inizio_anno_scolastico,'DD/MM/YYYY');   -- •	Data inizio anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.fine_anno_scolastico,'DD/MM/YYYY');     -- •	Data fine anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.data_accettazione,'DD/MM/YYYY');        -- •	Data accettazione
    sRecord = sRecord || ';';                                                       -- •	Esito trasferimento
    sRecord = sRecord || ';';                                                       -- •	Dettaglio errore
    --------
    INSERT INTO iscritto_tmp_flusso ( id_tmp_fusso, record )
      VALUES ( nIdTmpFlusso, sRecord );
  END LOOP;
  --------
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetEmailInvioAcc ( pIdAccettazioneRin  IN  INTEGER
                          ) RETURNS VARCHAR AS
$BODY$
DECLARE
  sEmail  iscritto_t_scuola.email%TYPE;
BEGIN
  SELECT  scuola.email
    INTO  sEmail
    FROM  iscritto_t_acc_rin    accRin
        , iscritto_t_scuola     scuola
    WHERE accRin.id_scuola = scuola.id_scuola
      AND accRin.id_accettazione_rin = pIdAccettazioneRin;
  ----
  RETURN sEmail;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION SetDataInvioAcc  ( pIdAccettazioneRin  IN  INTEGER
                          ) RETURNS INTEGER AS
$BODY$
DECLARE
BEGIN
  UPDATE  iscritto_t_invio_acc
    SET dt_invio_scuola = CURRENT_TIMESTAMP
    WHERE id_accettazione_rin = pIdAccettazioneRin;
  RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetNextInvioAcc() RETURNS INTEGER AS
$BODY$
DECLARE
  nIdAccettazioneRin  iscritto_t_acc_rin.id_accettazione_rin%TYPE;
BEGIN
  SELECT  invAcc.id_accettazione_rin
    INTO STRICT nIdAccettazioneRin
    FROM  iscritto_t_invio_acc  invAcc
        , iscritto_t_acc_rin    accRin
    WHERE invAcc.id_accettazione_rin = accRin.id_accettazione_rin
      AND invAcc.dt_invio_scuola IS NULL
    LIMIT 1;
  ---------
  RETURN nIdAccettazioneRin;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
END;
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;



CREATE OR REPLACE
FUNCTION GetTestoEmail  ( pIdAccettazioneRin  IN  INTEGER
                        ) RETURNS VARCHAR(500) AS
$BODY$
DECLARE
  sTestoEmail           iscritto_t_parametro.testo_mail_eco%TYPE;
  sTestoEmailFinale     iscritto_t_parametro.testo_mail_eco%TYPE;
  nIdDomandaIscrizione  iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
  sProtocollo           iscritto_t_domanda_isc.protocollo%TYPE;
  nIdAnnoScolastico     iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
  nIdOrdineScuola       iscritto_t_domanda_isc.id_ordine_scuola%TYPE;
  sCognomeNome          VARCHAR(101);
  dDataNascita          iscritto_t_anagrafica_sog.data_nascita%TYPE;
  sDescFasciaEta        iscritto_d_fascia_eta.descrizione%TYPE;
  sDescTipoFrequenza    iscritto_d_tipo_fre.descrizione%TYPE;
  dDataOperazione       iscritto_t_acc_rin.dt_operazione%TYPE;
  sTelefono             iscritto_t_invio_acc.telefono%TYPE;
BEGIN
  -- Recupero il modello del testo della email
  SELECT  testo_mail_eco
    INTO  sTestoEmail
    FROM  iscritto_t_parametro;
  -------
  -- Recupero l'ID della domanda di iscrizione, il Tipo frequenza, la Data operazione e il telefono
  SELECT  accRin.id_domanda_iscrizione
        , tipoFre.descrizione
        , TRUNC(accRin.dt_operazione)
        , telefono
    INTO  nIdDomandaIscrizione
        , sDescTipoFrequenza
        , dDataOperazione
        , sTelefono
    FROM  iscritto_t_acc_rin    accRin
        , iscritto_d_tipo_fre   tipoFre
        , iscritto_t_invio_acc  invAcc
    WHERE accRin.id_tipo_frequenza = tipoFre.id_tipo_frequenza
      AND accRin.id_accettazione_rin = invAcc.id_accettazione_rin
      AND accRin.id_accettazione_rin = pIdAccettazioneRin;
  -------
  -- Recupero il numero della domanda
  SELECT  protocollo
        , id_anno_scolastico
        , id_ordine_scuola
    INTO  sProtocollo
        , nIdAnnoScolastico
        , nIdOrdineScuola
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = nIdDomandaIscrizione;
  -------
  -- Recupero cognome e nome del minore e la data di nascita
  SELECT  anagSog.cognome || ' ' || anagSog.nome
        , anagSog.data_nascita
    INTO  sCognomeNome
        , dDataNascita
    FROM  iscritto_t_anagrafica_sog   anagSog
        , iscritto_r_soggetto_rel     sogRel
        , iscritto_d_tipo_sog         tipoSog
    WHERE anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
      AND sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
      AND anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
      AND tipoSog.cod_tipo_soggetto = 'MIN';
  -------
  -- Recupero la fascia d'età
  SELECT  fasciaEta.descrizione
    INTO  sDescFasciaEta
    FROM  iscritto_t_anagrafica_gra   anagGra
        , iscritto_t_eta              eta
        , iscritto_d_fascia_eta       fasciaEta
    WHERE anagGra.id_anagrafica_gra = eta.id_anagrafica_gra
      AND eta.id_fascia_eta = fasciaEta.id_fascia_eta
      AND anagGra.id_anno_scolastico = nIdAnnoScolastico
      AND anagGra.id_ordine_scuola = nIdOrdineScuola
      AND dDataNascita BETWEEN eta.data_da AND eta.data_a;
  -------
  sTestoEmailFinale = ' ';
  FOR i IN 1..LENGTH(sTestoEmail)
  LOOP
    IF SUBSTR(sTestoEmail,i,1) = '1' THEN
      sTestoEmailFinale = sTestoEmailFinale || TO_CHAR(dDataOperazione,'DD/MM/YYYY');
    ELSIF SUBSTR(sTestoEmail,i,1) = '2' THEN
      sTestoEmailFinale = sTestoEmailFinale || sProtocollo;
    ELSIF SUBSTR(sTestoEmail,i,1) = '3' THEN
      sTestoEmailFinale = sTestoEmailFinale || sCognomeNome;
    ELSIF SUBSTR(sTestoEmail,i,1) = '4' THEN
      sTestoEmailFinale = sTestoEmailFinale || sDescFasciaEta;
    ELSIF SUBSTR(sTestoEmail,i,1) = '5' THEN
      sTestoEmailFinale = sTestoEmailFinale || sDescTipoFrequenza;
    ELSIF SUBSTR(sTestoEmail,i,1) = '6' THEN
      sTestoEmailFinale = sTestoEmailFinale || sTelefono;
    ELSE
      IF ASCII(SUBSTR(sTestoEmail,i,1)) <> 13 THEN
        sTestoEmailFinale = sTestoEmailFinale || SUBSTR(sTestoEmail,i,1);
      END IF;
    END IF;
  END LOOP;
  -------
  RETURN sTestoEmailFinale;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
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

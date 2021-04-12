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
 --                         and cod_condizione <> 'LA_PER_MAT'			-- U.M.23/09/2020
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
* Impostare ISCRITTO_T_DOMANDA_ISC.fl_istruita='N'
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

----------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION inseriscidomandeingraduatoria(pidstepgraddacalcolare integer);
--
CREATE OR REPLACE FUNCTION inseriscidomandeingraduatoria(pidstepgraddacalcolare integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
  -- UM-20201202 modificata completamente la query di estrazione delle domande utilizzando
  --            il parametro pidstepgraddacalcolare per far si' che prenda solo le domande
  --			legate alla graduatoria	in fase di calcolo (nidi oppure materne)
  FOR domanda IN  select
					dom.id_domanda_iscrizione id_domanda_iscrizione ,
					dom.fl_fratello_freq fl_fratello_freq 
				from
					iscritto_t_domanda_isc dom
				join iscritto_t_anagrafica_gra ag on
					ag.id_anno_scolastico = dom.id_anno_scolastico
					and ag.id_ordine_scuola = dom.id_ordine_scuola
				join iscritto_t_step_gra sg on
					sg.id_anagrafica_gra = ag.id_anagrafica_gra
				left join iscritto_t_step_gra_con sgc on
					sgc.id_step_gra = sg.id_step_gra
				where
					dom.id_stato_dom = 2		-- 'INV'
					and dom.fl_istruita = 'S'
					and sgc.id_step_gra_con = pidstepgraddacalcolare
					and DATE_TRUNC('day', dom.data_consegna) between DATE_TRUNC('day', param.pDataDomandaInvioDa) and DATE_TRUNC('day', param.pDataDomandaInvioA)
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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION ordinagraduatoriamaterne(pidstepgraduatoria integer);
--
CREATE OR REPLACE FUNCTION ordinagraduatoriamaterne(pidstepgraduatoria integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  grad  RECORD;
  -----
  nOrdinamento  iscritto_t_graduatoria.ordinamento%TYPE;
  record      iscritto_d_fascia_eta.cod_fascia_eta%TYPE;
BEGIN
  
  -- eseguo la query di ordinamento per ogni fascia d'eta' delle materne
  ----------
  FOR record IN SELECT cod_fascia_eta 
						from iscritto_d_fascia_eta 
						where id_ordine_scuola = 2
  LOOP
	  
      -- eseguo la query di ordinamento per la data fascia d'eta' nel record
  	  ----------
  	  nOrdinamento = 0;
	 
	  FOR grad IN SELECT gr.id_graduatoria
					FROM iscritto_t_graduatoria gr
					join iscritto_d_fascia_eta fascEta on
						fascEta.id_fascia_eta = gr.id_fascia_eta
					join iscritto_t_domanda_isc domIsc on
						domIsc.id_domanda_iscrizione = gr.id_domanda_iscrizione
					join iscritto_t_anagrafica_sog anagSog on
						anagSog.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
					join iscritto_r_soggetto_rel sogRel on
					 	sogRel.id_anagrafica_soggetto = anagSog.id_anagrafica_soggetto
					join iscritto_d_tipo_sog tipoSog on
					 	tipoSog.id_tipo_soggetto = sogRel.id_tipo_soggetto
					join (
						(select
							d.id_domanda_iscrizione dom,
							(case
								when p.fl_valida = 'S' then 'A'
								when p.fl_valida = 'N' then 'B'
							end) as valida
						from iscritto_t_domanda_isc d
						join iscritto_r_punteggio_dom p on
							p.id_domanda_iscrizione = d.id_domanda_iscrizione
						where d.id_ordine_scuola = 2
							and p.id_condizione_punteggio = 29
							and p.dt_fine_validita is null)
						union
						(select dd.id_domanda_iscrizione dom, 'B' as valida
						from iscritto_t_domanda_isc dd
						where dd.id_ordine_scuola = 2
						  and not exists ( select pp.id_condizione_punteggio
								     from iscritto_r_punteggio_dom pp
								    where pp.id_domanda_iscrizione = dd.id_domanda_iscrizione
								    and pp.id_condizione_punteggio = 29))
					    ) puntDom on
						puntDom.dom = domIsc.id_domanda_iscrizione
					join iscritto_r_scuola_pre scuPre on
					 	scuPre.id_domanda_iscrizione = domIsc.id_domanda_iscrizione		
					WHERE tipoSog.cod_tipo_soggetto = 'MIN'
						and	fascEta.cod_fascia_eta = record		-- fascia eta' del record
						and gr.id_step_gra_con = pidstepgraduatoria			-- parametro di input
					ORDER BY  gr.fl_fuori_termine
							, scuPre.id_tipo_grad       -- gestione scuole europee
							, gr.punteggio desc
						    , puntDom.valida
						    , anagSog.data_nascita
						    , domIsc.data_consegna
						    , gr.ordine_preferenza
	
	  LOOP
	    nOrdinamento = nOrdinamento + 1;
	    UPDATE  iscritto_t_graduatoria
	      SET ordinamento = nOrdinamento
	      WHERE id_graduatoria = grad.id_graduatoria;
	  END LOOP;
	 
 END LOOP;
  ----------
  RETURN 0;
END;
$function$
;

--------------------------------------------------------------------------------------------------------------------------------------------------------
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
  -- ATTRIBUZIONE POSTI LIBERI
  FOR fascia IN SELECT  id_fascia_eta
                  FROM  iscritto_d_fascia_eta
                  WHERE id_ordine_scuola=getidordinescuola_dastep(pIdStepGraduatoriaCon)
                  order by cod_fascia_eta
 --                 ORDER BY CASE WHEN cod_fascia_eta = 'L' THEN 1
 --                               WHEN cod_fascia_eta = 'P' THEN 2
 --                               WHEN cod_fascia_eta = 'G' THEN 3
 --                          END
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


--------------------------------------------------------------------------------------------------------------------------------------------------------
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
          *	Per tutte le domande copiate nella nuova graduatoria occorre verificare se nella data dello step sono state aggiunte
            scuole di preferenza: ISCRITTO_R_SCUOLA_PRE.dt_ins_scu compresa tra ISCRITTO_T_STEP_GRA.dt_dom_inv_da
            e ISCRITTO_T_STEP_GRA.dt_dom_inv_a
          *	Per ogni record di ISCRITTO_R_SCUOLA_PRE trovato nel passo precedente:
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
                    AND domIsc.id_stato_dom = 4
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

--------------------------------------------------------------------------------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------------------------------------------------------------------------------
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
                                      AND fl_valida = 'S'
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
                                  AND fl_valida = 'S'
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

---------------------------------------------------------------------------------------------------------------------------------------------------------
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
        WHERE codice_fiscale = vCodiceFisc;

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


---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getannoscolastico(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION getannoscolastico(piddomandaiscrizione integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  nAnno NUMERIC(4);
BEGIN
  SELECT  EXTRACT(YEAR FROM annoSco.data_da)
      INTO  nAnno
    FROM  iscritto_t_anno_sco         annoSco
        , iscritto_t_domanda_isc      domIsc
    WHERE domIsc.id_anno_scolastico = annoSco.id_anno_scolastico
      and domIsc.id_domanda_iscrizione = piddomandaiscrizione;
  RETURN nAnno;
END;
$function$
;

---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getdatanascitabycodicefiscale(pcodicefiscale character varying);
--
CREATE OR REPLACE FUNCTION getdatanascitabycodicefiscale(pcodicefiscale character varying)
 RETURNS character
 LANGUAGE plpgsql
AS $function$
DECLARE
    
  dDataNascita  iscritto_t_anagrafica_sog.data_nascita%TYPE;
  dataN VARCHAR(20);
  anno VARCHAR(4);
  mese VARCHAR(2);
  giorno VARCHAR(2);
 
  n numeric;   

BEGIN



 anno = '20' || SUBSTRING(pcodicefiscale,7,2);


 if (SUBSTRING(pcodicefiscale,9,1) = 'A') THEN
   mese = '01';
 end if;
 if (SUBSTRING(pcodicefiscale,9,1) = 'E') THEN
    mese = '05';
 end if;
 if (SUBSTRING(pcodicefiscale,9,1)  = 'P') THEN
     mese = '09';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'B') THEN
     mese = '02';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'H') THEN
     mese = '06';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'R') THEN
     mese = '10';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'C') THEN
     mese = '03';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'L') THEN
     mese = '07';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'S') THEN
     mese = '11';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'D') THEN
     mese = '04';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'M') THEN
    mese = '08';
 end if;
 if(SUBSTRING(pcodicefiscale,9,1) = 'T') THEN
    mese = '12';
 end if;
 
 
 n = CAST (SUBSTRING(pcodicefiscale,10,2) AS INTEGER); 
 if (n<35)then
     giorno = SUBSTRING(pcodicefiscale,10,2);
 else
     giorno = CAST((n-40) AS VARCHAR(2));
 end if;

 if(length(giorno)<2)then
         giorno = '0' || giorno;
 end if;
 

 return anno || '-' || mese || '-' || giorno;

 return dataN = anno || '-' || mese || '-' || giorno;
 return dDataNascita = CAST ( dataN AS timestamp);
 


END;
$function$
;


---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getdesccomuneautonomo(pidcondizioneoccupazionale integer);
--
CREATE OR REPLACE FUNCTION getdesccomuneautonomo(pidcondizioneoccupazionale integer)
  RETURNS character varying
  LANGUAGE plpgsql
AS
$body$
DECLARE
  sComuneLavoro   iscritto_t_autonomo.comune_lavoro%TYPE;
BEGIN
  -- Verifico se il minore esiste ed e' residente a Torino
  SELECT  UPPER(TRIM(comune_lavoro))
    INTO  sComuneLavoro
    FROM  iscritto_t_autonomo
    WHERE id_condizione_occupazionale = pIdCondizioneOccupazionale;
  RETURN sComuneLavoro;
END;
$body$
  VOLATILE
  COST 100;
---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getdesccomunedipendente(pidcondizioneoccupazionale integer);
--
CREATE OR REPLACE FUNCTION getdesccomunedipendente(pidcondizioneoccupazionale integer)
  RETURNS character varying
  LANGUAGE plpgsql
AS
$body$
DECLARE
  sComuneLavoro   iscritto_t_dipendente.comune_lavoro%TYPE;
BEGIN
  -- Verifico se il minore esiste ed e' residente a Torino
  SELECT  UPPER(TRIM(comune_lavoro))
    INTO  sComuneLavoro
    FROM  iscritto_t_dipendente
    WHERE id_condizione_occupazionale = pIdCondizioneOccupazionale;
  RETURN sComuneLavoro;
END;
$body$
  VOLATILE
  COST 100;
---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getfasciaetaff(pdatanascitafrq timestamp without time zone, pidanagraficagra integer);
--
CREATE OR REPLACE FUNCTION getfasciaetaff(pdatanascitafrq timestamp without time zone, pidanagraficagra integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  -- Verifico se esiste un id
  SELECT  COUNT(1)
    INTO  nRicorrenza
    from iscritto_t_eta
   where pdatanascitafrq BETWEEN data_da AND data_a
     and id_anagrafica_gra = pidanagraficagra
     and id_fascia_eta <> 7;
  -------

  RETURN nRicorrenza;
END;
$function$
;

---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getflagistruita(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION getflagistruita(piddomandaiscrizione integer)
  RETURNS character varying
  LANGUAGE plpgsql
AS
$body$
DECLARE
  sFlagIstruita   iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
BEGIN
  SELECT  fl_istruita
    INTO  sFlagIstruita
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione;
  RETURN sFlagIstruita;
END;
$body$
  VOLATILE
  COST 100;
---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getflagresidenzanao(piddomandaiscrizione integer, pcodtiposoggetto character varying);
--
CREATE OR REPLACE FUNCTION getflagresidenzanao(piddomandaiscrizione integer, pcodtiposoggetto character varying)
  RETURNS character varying
  LANGUAGE plpgsql
AS
$body$
DECLARE
  sFlagResidenzaNAO iscritto_t_anagrafica_sog.fl_residenza_nao%TYPE;
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
$body$
  VOLATILE
  COST 100;
---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getidcondizioneoccupazionale(piddomandaiscrizione integer, pcodtiposoggetto character varying, pcodtipcondoccupazionale character varying);
--
CREATE OR REPLACE FUNCTION getidcondizioneoccupazionale(piddomandaiscrizione integer, pcodtiposoggetto character varying, pcodtipcondoccupazionale character varying)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
DECLARE
  nIdCondizioneOccupazionale  iscritto_t_condizione_occ.id_condizione_occupazionale%TYPE;
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
$body$
  VOLATILE
  COST 100;

---------------------------------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION gettestoemail(pidaccettazionerin integer);
--
CREATE OR REPLACE FUNCTION gettestoemail(pidaccettazionerin integer)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
    sTestoEmail                    iscritto_t_parametro.testo_mail_eco%TYPE;
    sTestoEmailFinale              iscritto_t_parametro.testo_mail_eco%TYPE;
    nIdDomandaIscrizione           iscritto_t_domanda_isc.id_domanda_iscrizione%TYPE;
    sProtocollo                    iscritto_t_domanda_isc.protocollo%TYPE;
    nIdAnnoScolastico              iscritto_t_domanda_isc.id_anno_scolastico%TYPE;
    nIdOrdineScuola                iscritto_t_domanda_isc.id_ordine_scuola%TYPE;
    sCognomeNome                   VARCHAR(101);
    dDataNascita                   iscritto_t_anagrafica_sog.data_nascita%TYPE;
    sDescFasciaEta                 iscritto_d_fascia_eta.descrizione%TYPE;
    sDescTipoFrequenza             iscritto_d_tipo_fre.descrizione%TYPE;
    dDataOperazione                iscritto_t_acc_rin.dt_operazione%TYPE;
    sTelefono                      iscritto_t_invio_acc.telefono%TYPE;
    sCognomeNomeCodFiscRichiedente VARCHAR(117);
    sCodiceFiscaleMinore           iscritto_t_anagrafica_sog.codice_fiscale%TYPE;
    sCittadinanzaMinore            iscritto_t_stato.cittadinanza%TYPE;
    nIdComuneMinore                iscritto_t_comune.id_comune%TYPE;
    sComuneDiResidenzaMinore       iscritto_t_comune.desc_comune%TYPE;
    sIndirizzoMinore               iscritto_t_indirizzo_res.indirizzo%TYPE;
    sTipologiaPasto                iscritto_d_tipo_pasto.descrizione%TYPE;
    nOrdineScuola                  iscritto_t_domanda_isc.id_ordine_scuola%TYPE;
    dDataFasciaEtaDa               iscritto_t_eta.data_da%TYPE;
    dDataFasciaEtaA                iscritto_t_eta.data_a%TYPE;
    sNomeNido                      iscritto_t_scuola.descrizione%TYPE;
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
                 JOIN iscritto_d_tipo_fre tipoFre ON accRin.id_tipo_frequenza = tipoFre.id_tipo_frequenza
                 JOIN iscritto_t_invio_acc invAcc ON accRin.id_accettazione_rin = invAcc.id_accettazione_rin
                 JOIN iscritto_t_scuola scu ON accRin.id_scuola = scu.id_scuola
                 LEFT JOIN iscritto_d_tipo_pasto tipoPasto on invAcc.id_tipo_pasto = tipoPasto.id_tipo_pasto
        WHERE accRin.id_accettazione_rin = pIdAccettazioneRin;
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
        -- + aggiunta 29/06/2020 codice fiscale, cittadinanza, id comune di residenza, indirizzo del minore

        SELECT anagSog.cognome || ' ' || anagSog.nome
             , anagSog.data_nascita
             , anagSog.codice_fiscale
             , statoSog.cittadinanza
             , comuneSog.id_comune
             , indiRes.indirizzo
        INTO sCognomeNome
            , dDataNascita
            , sCodiceFiscaleMinore
            , sCittadinanzaMinore
            , nIdComuneMinore
            , sIndirizzoMinore
        FROM iscritto_t_anagrafica_sog anagSog
        join iscritto_r_soggetto_rel sogRel on anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
        join iscritto_d_tipo_sog tipoSog on sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
        join iscritto_t_indirizzo_res indiRes on anagSog.id_anagrafica_soggetto = indiRes.id_anagrafica_soggetto
        left join iscritto_t_stato statoSog on statoSog.id_stato = anagSog.id_stato_citt
        left join iscritto_t_comune comuneSog on indiRes.id_comune = comuneSog.id_comune
        WHERE anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
          AND tipoSog.cod_tipo_soggetto = 'MIN';

        -- Recupero la fascia d'eta'
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
        
        IF nIdComuneMinore IS NULL THEN
         sComuneDiResidenzaMinore = 'non dichiarato';
        else
            SELECT comuneSog.desc_comune
            INTO  sComuneDiResidenzaMinore
            FROM iscritto_t_comune comuneSog
            WHERE comuneSog.id_comune = nIdComuneMinore
              AND comuneSog.rel_status = '1';

            if  sComuneDiResidenzaMinore IS NULL THEN
                sComuneDiResidenzaMinore = 'Comune non valido ';
            end if;

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
           join iscritto_t_invio_acc invAcc on accRin.id_accettazione_rin = invAcc.id_accettazione_rin
           left join iscritto_d_tipo_pasto tipoPasto on invAcc.id_tipo_pasto = tipoPasto.id_tipo_pasto
        WHERE accRin.id_accettazione_rin = pIdAccettazioneRin;
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
             , comuneSog.id_comune
             , indiRes.indirizzo
        INTO sCognomeNome
            , dDataNascita
            , sCodiceFiscaleMinore
            , sCittadinanzaMinore
            , nIdComuneMinore
            , sIndirizzoMinore
        FROM iscritto_t_anagrafica_sog anagSog
        join iscritto_r_soggetto_rel sogRel on anagSog.id_anagrafica_soggetto = sogRel.id_anagrafica_soggetto
        join iscritto_d_tipo_sog tipoSog on sogRel.id_tipo_soggetto = tipoSog.id_tipo_soggetto
        join iscritto_t_indirizzo_res indiRes on anagSog.id_anagrafica_soggetto = indiRes.id_anagrafica_soggetto
        left join iscritto_t_stato statoSog on statoSog.id_stato = anagSog.id_stato_citt
        left join iscritto_t_comune comuneSog on indiRes.id_comune = comuneSog.id_comune
        WHERE anagSog.id_domanda_iscrizione = nIdDomandaIscrizione
          AND tipoSog.cod_tipo_soggetto = 'MIN';
        -------
        -- +Recupero la fascia d'eta'
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

        IF nIdComuneMinore IS NULL THEN
         sComuneDiResidenzaMinore = 'non dichiarato';
        else
            SELECT comuneSog.desc_comune
            INTO  sComuneDiResidenzaMinore
            FROM iscritto_t_comune comuneSog
            WHERE comuneSog.id_comune = nIdComuneMinore
              AND comuneSog.rel_status = '1';

            if  sComuneDiResidenzaMinore IS NULL THEN
                sComuneDiResidenzaMinore = 'Comune non valido ';
            end if;

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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION load_csv_freq_sise();
--
CREATE OR REPLACE FUNCTION load_csv_freq_sise()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
declare
    r_freq         RECORD;
    conta_presenza INTEGER;
    err_context    text;
    iter           integer; -- dummy integer to iterate columns with
    col            text; -- variable to keep the column name at each iteration
    col_first      text; -- first column name, e.g., top left corner on a csv file or spreadsheet
    lv_file        text;
    lv_id_anno     iscritto_t_anno_sco.id_anno_scolastico%TYPE;
    lv_id_scuola   iscritto_t_scuola.id_scuola%type;
    ordineS        iscritto_t_scuola.id_ordine_scuola%type;
    dataNascitaFrq iscritto_t_anagrafica_sog.data_nascita%type;
    idAnagGra      iscritto_t_anagrafica_gra.id_anagrafica_gra%type;
    idFasciaEta    iscritto_t_eta.id_fascia_eta%type;
    codFasciaeta   iscritto_d_fascia_eta.cod_fascia_eta%type;
    sdata          varchar(10);
    idEtaPresente  integer;
    inizioElaborazione timestamp;
    nota           varchar;

BEGIN
    --   execute format('copy ISCRITTO_TMP_FREQ_SISE from %L with delimiter '';'' quote ''"'' csv ', csv_path);
--   commit;
--    iter := 1;
--    col_first := (select col_1 from ISCRITTO_TMP_FREQ_SISE limit 1);

    -- update the column names based on the first row which has the column names
    --   for col in execute format('select unnest(string_to_array(trim(temp_table::text, ''()''), '','')) from temp_table where col_1 = %L', col_first)
--  raise notice 'Value: %', csv_path;
    
    
    --pulisco tabella del log
    DELETE FROM iscritto_t_log_ff;
    inizioElaborazione = current_timestamp;
    for r_freq in select *
                  from iscritto_tmp_freq_sise
        loop
            conta_presenza := 0;
            lv_id_anno := null;
            lv_id_scuola := null;

            select id_anno_scolastico
            into lv_id_anno
            from iscritto_t_anno_sco
            where cod_anno_scolastico = r_freq.codice_anno_scolastico;
            -- prelevo l ordine scolastico
            select id_scuola, id_ordine_scuola
            into lv_id_scuola , ordineS
            from iscritto_t_scuola
            where cod_scuola = r_freq.cod_scuola;

            select count(1)
            into conta_presenza
            from iscritto_t_freq_nido_sise a
            where a.codice_fiscale = r_freq.codice_fiscale
              and a.id_anno_scolastico = lv_id_anno
              and a.id_scuola = lv_id_scuola
              and a.fl_attivo_sospeso = r_freq.id_stato_freq;

            if conta_presenza = 0 then
                -- NIDI
                if (ordineS = 1) then
                    insert into iscritto_t_freq_nido_sise (codice_fiscale, id_anno_scolastico, id_scuola, cod_fascia,
                                                           dt_variazione, fl_attivo_sospeso)
                    values (r_freq.codice_fiscale, lv_id_anno, lv_id_scuola, r_freq.classe, CURRENT_TIMESTAMP,
                            r_freq.id_stato_freq);

                end if;
                -- MATERNE
                if (ordineS = 2) then
                    sdata = getdatanascitabycodicefiscale(r_freq.codice_fiscale);

                    dataNascitaFrq = to_timestamp(sdata, 'YYYY-MM-DD HH24:MI:SS');

                    select id_anagrafica_gra
                    into idAnagGra
                    from iscritto_t_anagrafica_gra
                    where id_ordine_scuola = ordineS
                      and id_anno_scolastico = lv_id_anno;

                    idEtaPresente = getfasciaetaFF(dataNascitaFrq, idAnagGra);

                    if (idEtaPresente > 0) then


                        select id_fascia_eta
                        into idFasciaEta
                        from iscritto_t_eta
                        where dataNascitaFrq BETWEEN data_da AND data_a
                          and id_anagrafica_gra = idAnagGra
                          and id_fascia_eta <> 7;

                        select cod_fascia_eta
                        into codFasciaeta
                        from iscritto_d_fascia_eta
                        where id_fascia_eta = idFasciaEta;

                        insert into iscritto_t_freq_nido_sise (codice_fiscale, id_anno_scolastico, id_scuola,
                                                               cod_fascia,
                                                               dt_variazione, fl_attivo_sospeso)
                        values (r_freq.codice_fiscale, lv_id_anno, lv_id_scuola, codFasciaeta, CURRENT_TIMESTAMP,
                                r_freq.id_stato_freq);

                    else
                        nota = r_freq.codice_fiscale || ' - Id eta non presente';
                        insert into iscritto_t_log_ff (d_inizio_elab, d_fine_elab,proc_log,nota_log)
                        values (inizioElaborazione, CURRENT_TIMESTAMP, 'load_csv_freq_sise', nota);

                    end if;

                end if;
            end if;

        end loop;

    return (0);
exception
    when others then
        GET STACKED DIAGNOSTICS err_context = PG_EXCEPTION_CONTEXT;
        RAISE INFO 'Error Name:%',SQLERRM;
        RAISE INFO 'Error State:%', SQLSTATE;
        RAISE INFO 'Error Context:%', err_context;
        return (1);
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION ordinagraduatoria(pidstepgraduatoria integer);
--
CREATE OR REPLACE FUNCTION ordinagraduatoria(pidstepgraduatoria integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  nOrdineScuola  iscritto_t_anagrafica_gra.id_ordine_scuola%TYPE;
  pRisultato smallint;
BEGIN
  pRisultato = 0;
 
	Select ag.id_ordine_scuola
	into	nOrdineScuola
	from	iscritto_t_anagrafica_gra ag
	join iscritto_t_step_gra sg on sg.id_anagrafica_gra = ag.id_anagrafica_gra
	join iscritto_t_step_gra_con sgc on sgc.id_step_gra = sg.id_step_gra
    where sgc.id_step_gra_con = pidstepgraduatoria;
   
   if nOrdineScuola = 1 then
       pRisultato = ordinagraduatorianidi(pidstepgraduatoria);
   elseif nOrdineScuola = 2 then
       pRisultato = ordinagraduatoriamaterne(pidstepgraduatoria);
   end if;
  
  RETURN pRisultato;
END;
$function$
;

--------------------------------------------------------------------------------------------------------------
DROP FUNCTION ordinagraduatorianidi(pidstepgraduatoria integer);
--
CREATE OR REPLACE FUNCTION ordinagraduatorianidi(pidstepgraduatoria integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  grad  RECORD;
  -----
  nOrdinamento  iscritto_t_graduatoria.ordinamento%TYPE;
BEGIN
  -- Valorizzo il campo ordinamento per i record appena inseriti divisi per blocchi d'eta'
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
$function$
;
----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION preparadatisise();
--
CREATE OR REPLACE FUNCTION preparadatisise()
  RETURNS smallint
  LANGUAGE plpgsql
AS
$body$
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
--    sRecord = sRecord || ';' || rec.valore_isee;                                    -- *	Valore ISEE
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
$body$
  VOLATILE
  COST 100;
----------------------------------------------------------------------------------------------------------------------------------
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
--    sRecord = sRecord || ';' || rec.valore_isee;                                    -- *	Valore ISEE
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

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio(pcodcondizione character varying, piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio(pcodcondizione character varying, piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
  RETURNS record
  LANGUAGE plpgsql
AS
$body$
DECLARE
    rec RECORD;
BEGIN
    pRicorrenza = 0;
    -------
    SELECT CASE WHEN fl_istruttoria = 'N' THEN 'S' ELSE NULL END
    INTO pFlagValida
    FROM iscritto_d_condizione_pun
    WHERE cod_condizione = pCodCondizione;
    -------
    IF pCodCondizione = 'RES_TO' THEN
        SELECT *
        INTO rec
        FROM Punteggio_RES_TO(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        IF rec.pFlagResidenzaNAO = 'S' THEN
            pFlagValida = 'S';
        END IF;
    ELSIF pCodCondizione = 'RES_TO_FUT' THEN
        pRicorrenza = Punteggio_RES_TO_FUT(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'RES_TO_FUT_NOTE' THEN -- E.F. 13/11/2019
        pRicorrenza = Punteggio_RES_TO_FUT_NOTE(pIdDomandaIscrizione); -- E.F. 13/11/2019
    ELSIF pCodCondizione = 'RES_NOTO_LAV' THEN
        pRicorrenza = Punteggio_RES_NOTO_LAV(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'RES_NOTO' THEN
        pRicorrenza = Punteggio_RES_NOTO(pIdDomandaIscrizione);
    ELSEIF pCodCondizione = 'RES_TO_EXTRA' then
        SELECT *
        INTO rec
        FROM Punteggio_RES_TO_EXTRA(pIdDomandaiscrizione);
        pRicorrenza = rec.pRicorrenza;
        pFlagValida = rec.pFlagvalida; -- M.F. 12/10/2020
    ELSIF pCodCondizione = 'PA_DIS' THEN
        pRicorrenza = Punteggio_PA_DIS(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'PA_SOC' THEN
        pRicorrenza = Punteggio_PA_SOC(pIdDomandaIscrizione);
        --  ELSIF pCodCondizione =  'PA_PRB_SAL' THEN                       E.F. 13/11/2019
--    pRicorrenza = Punteggio_PA_PRB_SAL(pIdDomandaIscrizione);     E.F. 13/11/2019
    ELSIF pCodCondizione = 'PA_PRB_SAL_MIN' then -- E.F. 13/11/2019   
        pRicorrenza = Punteggio_PA_PRB_SAL_MIN(pIdDomandaIscrizione);-- E.F. 13/11/2019
    ELSIF pCodCondizione = 'PA_PRB_SAL_ALT' then -- E.F. 13/11/2019
        pRicorrenza = Punteggio_PA_PRB_SAL_ALT(pIdDomandaIscrizione);-- E.F. 13/11/2019
    ELSIF pCodCondizione = 'GEN_SOLO' THEN
        pRicorrenza = Punteggio_GEN_SOLO(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'GEN_SEP' THEN
        pRicorrenza = Punteggio_GEN_SEP(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'CF_INF_11' THEN
        SELECT *
        INTO rec
        FROM Punteggio_CF_INF_11(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        IF rec.pFlagResidenzaNAO = 'S' OR rec.pResidentiFuoriTorino THEN
            pFlagValida = 'S';
        END IF;
    ELSIF pCodCondizione = 'CF_TRA_11_17' THEN
        SELECT *
        INTO rec
        FROM Punteggio_CF_TRA_11_17(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        IF rec.pFlagResidenzaNAO = 'S' OR rec.pResidentiFuoriTorino THEN
            pFlagValida = 'S';
        END IF;
    ELSIF pCodCondizione = 'CF_FRA_FRE' THEN
        SELECT *
        INTO rec
        FROM Punteggio_CF_FRA_FRE(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        pFlagValida = rec.pFlagvalida;
    ELSIF pCodCondizione = 'CF_FRA_FRE_MAT' THEN
        SELECT *
        INTO rec
        FROM punteggio_cf_fra_fre_mat(pIdDomandaIscrizione);
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
    ELSIF pCodCondizione = 'PP_FR_CONT' THEN
        pRicorrenza = punteggio_pp_fr_cont(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'PAR_ISEE' THEN
        pRicorrenza = Punteggio_PAR_ISEE(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'PA_5_ANNI' THEN
        pRicorrenza = Punteggio_pa_5_anni(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'LA_PER_MAT' THEN
        pRicorrenza = Punteggio_la_per_mat(pIdDomandaIscrizione);
    ELSIF pCodCondizione = 'CF_FRA_ISC_MAT' then --- DA MODIFICARE come FRE_MAT
        SELECT *
        INTO rec
        FROM Punteggio_CF_FRA_ISC_MAT(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        pFlagValida = rec.pFlagvalida;
    ELSIF pCodCondizione = 'CF_FRA_ISC_MAT_EXTRA' then
        SELECT *
        INTO rec
        FROM Punteggio_CF_FRA_ISC_MAT_EXTRA(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        pFlagValida = rec.pFlagvalida;
    ELSIF pCodCondizione = 'CF_FRA_ISC_MAT_AGG' then
        SELECT *
        INTO rec
        FROM Punteggio_CF_FRA_ISC_MAT_AGG(pIdDomandaIscrizione);
        pRicorrenza = rec.pRicorrenza;
        pFlagValida = rec.pFlagvalida;
    ELSIF pCodCondizione = 'TR_TRA_MAT' THEN
        pRicorrenza = punteggio_tr_tra_mat(pIdDomandaIscrizione);
    ELSEIF pCodCondizione = 'XT_PT_AGG' THEN
        pRicorrenza = punteggio_xt_pt_agg(pIdDomandaIscrizione);
        pFlagValida = 'S'; -- U.M.23/09/2020
    ELSIF pCodCondizione = 'CF_FRA_FRE_MAT_EXTRA' THEN
        pRicorrenza = punteggio_cf_fra_fre_mat_extra(pIdDomandaIscrizione);
        pFlagValida = null;
    ELSIF pCodCondizione = 'CF_FRA_FRE_MAT_AGG' THEN
        pRicorrenza = punteggio_cf_fra_fre_mat_agg(pIdDomandaIscrizione);
        pFlagValida = null;
    END IF;

END;
$body$
  VOLATILE
  COST 100;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_fre_mat_agg(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_fre_mat_agg(piddomandaiscrizione integer)
  RETURNS integer
  LANGUAGE plpgsql
AS
$body$
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
      AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL
      and iscritto_r_punteggio_scu.id_punteggio =
          (select p.id_punteggio
           from iscritto_d_condizione_pun c,
                iscritto_t_punteggio p
           where cod_condizione = 'CF_FRA_FRE_MAT_AGG'
             and p.id_condizione_punteggio = c.id_condizione_punteggio);


    if (nRicorrenza > 0) then
        SELECT COUNT(1)
        INTO nRicorrenza
        FROM iscritto_t_fratello_fre
        WHERE id_domanda_iscrizione = piddomandaiscrizione
          and id_tipo_fratello = 1; --frequentante
    end if;


    RETURN nRicorrenza;
END;
$body$
  VOLATILE
  COST 100;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_isc_mat_agg(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_isc_mat_agg(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
  RETURNS record
  LANGUAGE plpgsql
AS
$body$
DECLARE
    vCodiceFisc          char(16);
    vDataNascitaFratello date;
    vData                date;
    nRicorrenza          INTEGER;
    nIdScuola            INTEGER;
BEGIN
    pRicorrenza = 0;
    pFlagvalida = NULL;

    SELECT id_scuola
    INTO nIdScuola
    FROM iscritto_r_scuola_pre
    WHERE iscritto_r_scuola_pre.id_domanda_iscrizione = piddomandaiscrizione
      AND iscritto_r_scuola_pre.posizione = 1;

    SELECT COUNT(1)
    INTO nRicorrenza
    FROM iscritto_r_punteggio_scu
    WHERE iscritto_r_punteggio_scu.id_scuola = nIdScuola
      AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL
      and iscritto_r_punteggio_scu.id_punteggio =
          (select p.id_punteggio
           from iscritto_d_condizione_pun c,
                iscritto_t_punteggio p
           where cod_condizione = 'CF_FRA_ISC_MAT_AGG'
             and p.id_condizione_punteggio = c.id_condizione_punteggio);


    if (nRicorrenza > 0) then


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
            --se il fratello e' presente attivo la condizione
            pricorrenza = 1;

            --recupero data di nascita del fratello dal cf
            SELECT data_nascita
            INTO vDataNascitaFratello
            FROM iscritto_t_anagrafica_sog
            WHERE codice_fiscale = vCodiceFisc;

            --verifico e' nello stesso ordinamento
            select min(e.data_da)
            into vData
            from iscritto_t_eta e
                     join iscritto_t_anagrafica_gra ag on ag.id_anagrafica_gra = e.id_anagrafica_gra
                     join iscritto_t_domanda_isc d on d.id_anno_scolastico = ag.id_anno_scolastico
                and d.id_ordine_scuola = ag.id_ordine_scuola
            where d.id_domanda_iscrizione = piddomandaiscrizione;

            IF (vDataNascitaFratello > vData) THEN
                pFlagvalida = 'S';
            END IF;

        end if;

    end if;
END;
$body$
  VOLATILE
  COST 100;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_isc_mat_extra(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_isc_mat_extra(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
  RETURNS record
  LANGUAGE plpgsql
AS
$body$
DECLARE
    vCodiceFisc          char(16);
    vDataNascitaFratello date;
    vData                date;
    nRicorrenza          INTEGER;
    nIdScuola            INTEGER;
BEGIN
    pRicorrenza = 0;
    pFlagvalida = NULL;

    SELECT id_scuola
    INTO nIdScuola
    FROM iscritto_r_scuola_pre
    WHERE iscritto_r_scuola_pre.id_domanda_iscrizione = piddomandaiscrizione
      AND iscritto_r_scuola_pre.posizione = 1;

    SELECT COUNT(1)
    INTO nRicorrenza
    FROM iscritto_r_punteggio_scu
    WHERE iscritto_r_punteggio_scu.id_scuola = nIdScuola
      AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL
      and iscritto_r_punteggio_scu.id_punteggio =
          (select p.id_punteggio
           from iscritto_d_condizione_pun c,
                iscritto_t_punteggio p
           where cod_condizione = 'CF_FRA_ISC_MAT_EXTRA'
             and p.id_condizione_punteggio = c.id_condizione_punteggio);


    if (nRicorrenza > 0) then
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
            --se il fratello e' presente attivo la condizione
            pricorrenza = 1;

            --recupero data di nascita del fratello dal cf
            SELECT data_nascita
            INTO vDataNascitaFratello
            FROM iscritto_t_anagrafica_sog
            WHERE codice_fiscale = vCodiceFisc;

            --verifico e' nello stesso ordinamento
            select min(e.data_da)
            into vData
            from iscritto_t_eta e
                     join iscritto_t_anagrafica_gra ag on ag.id_anagrafica_gra = e.id_anagrafica_gra
                     join iscritto_t_domanda_isc d on d.id_anno_scolastico = ag.id_anno_scolastico
                and d.id_ordine_scuola = ag.id_ordine_scuola
            where d.id_domanda_iscrizione = piddomandaiscrizione;

            IF (vDataNascitaFratello > vData) THEN
                pFlagvalida = 'S';
            END IF;

        end if;
    end if;
END;
$body$
  VOLATILE
  COST 100;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_fre_mat(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_fre_mat(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
DECLARE
  vFound  BOOLEAN;
  vFvalida BOOLEAN;
  vMonth smallint;
  vId_anno integer;
  vId_scuola integer;
  vCodiceFisc char(16);
  vFl_attivo_sospeso integer;

BEGIN
  pRicorrenza = 0;
  pFlagvalida = NULL;
  vFl_attivo_sospeso= null;
-- Verifico se il minore esiste
  SELECT fraFre.cf_fratello
  into vCodiceFisc
    FROM  iscritto_t_domanda_isc    domIsc
        , iscritto_t_fratello_fre   fraFre
        , iscritto_d_tipo_fra       tipFra
    WHERE domIsc.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND domIsc.id_domanda_iscrizione = pIdDomandaIscrizione
      AND fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
      AND domIsc.fl_fratello_freq = 'S'
      AND tipFra.cod_tipo_fratello = 'FREQ'
      group by fraFre.cf_fratello;


  if (vCodiceFisc is not null)  then
  	pRicorrenza = 1;

  	select extract(month from current_timestamp)
  	into vMonth;

 	-- Selezione dell'anno scolastico
 	  select id_anno_scolastico
		  into vId_anno
		  from iscritto_t_domanda_isc
		  where id_domanda_iscrizione=piddomandaiscrizione;

 	if(vMonth>2 and vMonth<9) then
	-- se siamo prima di settembre si prende l'anno scolastico in corso che quello precedente a quello della domanda
		select id_anno_scolastico
		into vId_anno
		from iscritto_t_anno_sco
		where data_da < (select data_da
					from iscritto_t_anno_sco
					where id_anno_scolastico= vId_anno)
		order by data_da desc
		limit 1;
 	end if;

    -- Selezione dell'id_scuola
		select id_scuola
		into vId_scuola
		from iscritto_r_scuola_pre
		where id_domanda_iscrizione= piddomandaiscrizione
		and posizione=1;

    	SELECT fl_attivo_sospeso
    	INTO  vFl_attivo_sospeso
    	FROM  iscritto_t_freq_nido_sise
    	WHERE codice_fiscale=vCodiceFisc
    	and id_anno_scolastico=vId_anno
    	and id_scuola=vId_scuola
    	and (cod_fascia not in ('III','E') or vMonth >= 9)  
    	order by dt_variazione desc
		limit 1;

    	if vFl_attivo_sospeso=1 then
       	pFlagvalida='S';
    	end if;
    end if;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_isc_mat(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_isc_mat(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
DECLARE
    vCodiceFisc          char(16);
    vDataNascitaFratello date;
    vData                date;
BEGIN
    pRicorrenza = 0;
    pFlagvalida = NULL;
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
        --se il fratello e' presente attivo la condizione
        pricorrenza = 1;

        --recupero data di nascita del fratello dal cf
        SELECT data_nascita
        INTO vDataNascitaFratello
        FROM iscritto_t_anagrafica_sog
        WHERE codice_fiscale = vCodiceFisc;

        --verifico e' nello stesso ordinamento
        select min(e.data_da)
        into vData
        from iscritto_t_eta e
        join iscritto_t_anagrafica_gra ag on ag.id_anagrafica_gra = e.id_anagrafica_gra
        join iscritto_t_domanda_isc d on d.id_anno_scolastico = ag.id_anno_scolastico
        and d.id_ordine_scuola = ag.id_ordine_scuola
        where d.id_domanda_iscrizione = piddomandaiscrizione;

        IF (vDataNascitaFratello > vData) THEN
            pFlagvalida = 'S';
        END IF;

    end if;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_inf_11(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagresidenzanao character varying, OUT presidentifuoritorino boolean);
--
CREATE OR REPLACE FUNCTION punteggio_cf_inf_11(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagresidenzanao character varying, OUT presidentifuoritorino boolean)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
DECLARE
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = NULL;
  pResidentiFuoriTorino = TRUE;
  nAnnoScolastico = GetAnnoScolastico(piddomandaiscrizione);
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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_inf_11_aff_con(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_cf_inf_11_aff_con(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza     INTEGER;
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  nRicorrenza = 0;
  nAnnoScolastico = GetAnnoScolastico(piddomandaiscrizione);
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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_tra_11_17(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagresidenzanao character varying, OUT presidentifuoritorino boolean);
--
CREATE OR REPLACE FUNCTION punteggio_cf_tra_11_17(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagresidenzanao character varying, OUT presidentifuoritorino boolean)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
DECLARE
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  pRicorrenza = 0;
  pFlagResidenzaNAO = NULL;
  pResidentiFuoriTorino = TRUE;
  nAnnoScolastico = GetAnnoScolastico(piddomandaiscrizione);
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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_tra_11_17_aff_con(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_cf_tra_11_17_aff_con(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza     INTEGER;
  nAnnoScolastico NUMERIC(4);
  soggetto        RECORD;
  nEta            NUMERIC(4);
BEGIN
  nRicorrenza = 0;
  nAnnoScolastico = GetAnnoScolastico(piddomandaiscrizione);
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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_la_per_mat(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_la_per_mat(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  -- Verifico se esistono dei record per la lista d'attesa
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_r_lista_attesa
    WHERE id_domanda_isc = pIdDomandaIscrizione;
  -------

  RETURN nRicorrenza;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_pa_5_anni(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_pa_5_anni(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_domanda_isc
    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
      AND fl_cinque_anni = 'S';
  -------
  RETURN nRicorrenza;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_pp_fr_cont(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_pp_fr_cont(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
BEGIN
  -- Verifico se esistono dei record per il fratello contiguo
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_r_nido_contiguo
    WHERE id_domanda_isc = pIdDomandaIscrizione;
  -------
  
   if nRicorrenza>1 then
	   nRicorrenza=1;
	end if;	  
   
  RETURN nRicorrenza;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_res_to_extra(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio_res_to_extra(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
  RETURNS record
  LANGUAGE plpgsql
AS
$body$
DECLARE
    quartiere_scuola iscritto_t_scuola.quartiere%type;
    comune           iscritto_t_indirizzo_res.id_comune%type;
    civico           iscritto_t_indirizzo_res.id_civico%type;
    fl_valida        iscritto_r_punteggio_dom.fl_valida%type;
    nIdScuola        INTEGER;
    control          INTEGER;
begin

    pRicorrenza = 0;
    pFlagvalida = NULL;

    
    SELECT id_scuola
    INTO nIdScuola
    FROM iscritto_r_scuola_pre
    WHERE iscritto_r_scuola_pre.id_domanda_iscrizione = piddomandaiscrizione
      AND iscritto_r_scuola_pre.posizione = 1;

    SELECT COUNT(1)
    INTO pRicorrenza
    FROM iscritto_r_punteggio_scu
    WHERE iscritto_r_punteggio_scu.id_scuola = nIdScuola
      AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL
      and iscritto_r_punteggio_scu.id_punteggio =
          (select p.id_punteggio
           from iscritto_d_condizione_pun c,
                iscritto_t_punteggio p
           where cod_condizione = 'RES_TO_EXTRA'
             and p.id_condizione_punteggio = c.id_condizione_punteggio);

    if pRicorrenza = 0 then
        return;
    else
        control = 0;

        select count(1)
        into control
        from iscritto_t_cambio_res
        where id_domanda_iscrizione = piddomandaiscrizione;

        if (control = 1) then
            return;
        else

            -- Verifico che la residenza del minore iscrivendo sia in Torino
            select i.id_comune, i.id_civico
            into comune,civico
            from iscritto_t_indirizzo_res i,
                 iscritto_t_anagrafica_sog a,
                 iscritto_t_domanda_isc d,
                 iscritto_r_soggetto_rel r
            where r.id_tipo_soggetto = 1
              and d.id_domanda_iscrizione = piddomandaiscrizione
              and i.id_anagrafica_soggetto = a.id_anagrafica_soggetto
              and r.id_anagrafica_soggetto = a.id_anagrafica_soggetto
              and a.id_domanda_iscrizione = d.id_domanda_iscrizione;

            if comune is null or comune != 8207 then
                pricorrenza = 0;
                return;

            else

                SELECT s.quartiere
                INTO quartiere_scuola
                FROM iscritto_t_scuola s,
                     iscritto_t_domanda_isc d,
                     iscritto_r_scuola_pre p
                WHERE p.id_domanda_iscrizione = piddomandaiscrizione
                  AND p.posizione = 1
                  AND d.id_domanda_iscrizione = p.id_domanda_iscrizione
                  AND p.id_scuola = s.id_scuola;

                if civico is not null then
                    if (quartiere_scuola = (select id_quartiere
                                            from iscritto_t_azzonamento
                                            where id_civico = civico)) then
                        pFlagvalida = 'S';
                    else
                        pFlagvalida = 'N';
                    end if;
                end if;
            end if;


        end if;


    end if;
END;
$body$
  VOLATILE
  COST 100;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_tr_tra_mat(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_tr_tra_mat(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
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
    AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL
    and iscritto_r_punteggio_scu.id_punteggio =
          (select p.id_punteggio 
	           from iscritto_d_condizione_pun c, iscritto_t_punteggio p
	           where cod_condizione = 'XT_PT_AGG'
	           and p.id_condizione_punteggio = c.id_condizione_punteggio);
     

  RETURN nRicorrenza;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
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
  -- 6.	Impostare il flag fl_ammissioni='S' nel record di tabella ISCRITTO_T_STEP_GRA per la graduatoria in corso
  UPDATE  iscritto_t_step_gra_con
    SET fl_ammissioni = 'S'
    WHERE id_step_gra_con = vIdStepInCorso;
  -------
  RETURN 0;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION statodomanda(piddomandaiscrizione integer, pidscuola integer);
--
CREATE OR REPLACE FUNCTION statodomanda(piddomandaiscrizione integer, pidscuola integer)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
  stato1 VARCHAR= 7;
  stato2 VARCHAR=(2,4,5,6,7,8);
  posiz  INTEGER;
BEGIN
    SELECT count(1)
    INTO  posiz
    FROM  iscritto_r_scuola_pre irsp
    WHERE irsp.posizione = 1
    AND irsp.id_domanda_iscrizione = piddomandaiscrizione
    AND irsp.id_scuola = pidscuola;
  -------
    if(posiz = 0 ) then
      return stato1;
    else
      return stato2;
    end if;

END;
$function$
;


DROP FUNCTION inviasms(pcodordinescuola character varying);
--
CREATE OR REPLACE FUNCTION inviasms(pcodordinescuola character varying)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
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
                AND anagGra.id_ordine_scuola= getidordinescuola(pcodordinescuola)
              ORDER BY  stepGraCon.dt_step_con  DESC
          ) t
    LIMIT 1;
  IF vCodStatoGra = 'DEF' THEN
    /*
      2.	Se il record piu' recente ha come id_stato_grad  che corrisponde a DEF nella tabella ISCRITTO_T_STEP_GRA_CON:
      *	cambiare lo stato in DEF_CON e la data dt_step_con con la sysdate
      *	inserire un nuovo record: 
      *	id_step_gra_con sequenziale
      *	id_step_gra id_step_gra precedente
      *	id_stato_grad corrispondente al codie stato 'PUB'
      *	fl_ammissioni 'N'
      *	dt_step_con sysdate
      3.	Copia dei record dal precedente id_step
      *	Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l'id_step_graduatoria_con precedente ( quelli con stato graduatoria
          DEF_CON nella stessa tabella con l'id_step_graduatoria_con nuovo ( PUB).
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
      *	Impostare il flag fl_ammissioni='N'
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
         *	Se c'e' un nido della domanda in stato AMM stato_domanda AMM
         *	Se c'e' un nido della domanda in stato PEN stato domanda GRA
         *	Se c'e' un nido della domanda in stato CAN_R_1SC o CAN_RIN stato_domanda RIN
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
$function$
;

DROP FUNCTION getidordinescuola_dastep(pidstepgracon integer);
--
CREATE OR REPLACE FUNCTION getidordinescuola_dastep(pidstepgracon integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nIdOrdineScuola   iscritto_d_ordine_scuola.id_ordine_scuola%TYPE;
BEGIN
    	             select id_ordine_scuola
    	             into nIdOrdineScuola
	    	             from iscritto_t_step_gra_con sgc,iscritto_t_step_gra sg,iscritto_t_anagrafica_gra ana
	    	             where sgc.id_step_gra_con=pidstepgracon
	    	             and sgc.id_step_gra=sg.id_step_gra
	    	             and sg.id_anagrafica_gra=ana.id_anagrafica_gra;  
	    	            RETURN nIdOrdineScuola;
END;
$function$
;


DROP FUNCTION getpunteggio(pidscuola integer, pidcondizionepunteggio integer);
--
CREATE OR REPLACE FUNCTION getpunteggio(pidscuola integer, pidcondizionepunteggio integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  vPunteggio    iscritto_t_punteggio.punti%TYPE;
  vIdPunteggio  iscritto_t_punteggio.id_punteggio%TYPE;
BEGIN
  SELECT  id_punteggio
        , punti
    INTO  vIdPunteggio
        , vPunteggio
    FROM  iscritto_t_punteggio, iscritto_t_scuola
    WHERE id_condizione_punteggio = pIdCondizionePunteggio
      and iscritto_t_punteggio.id_ordine_scuola= iscritto_t_scuola.id_ordine_scuola
      and iscritto_t_scuola.id_scuola= pidscuola
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
$function$
;
----------------------------------------------------------------------------------------------
drop FUNCTION punteggio_cf_fra_fre_mat_extra(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_fre_mat_extra(piddomandaiscrizione integer)
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
      AND iscritto_r_punteggio_scu.dt_fine_validita IS NULL
      and iscritto_r_punteggio_scu.id_punteggio =
          (select p.id_punteggio
           from iscritto_d_condizione_pun c,
                iscritto_t_punteggio p
           where cod_condizione = 'CF_FRA_FRE_MAT_EXTRA'
             and p.id_condizione_punteggio = c.id_condizione_punteggio);


    if (nRicorrenza > 0) then
        SELECT COUNT(1)
        INTO nRicorrenza
        FROM iscritto_t_fratello_fre
        WHERE id_domanda_iscrizione = piddomandaiscrizione
          and id_tipo_fratello = 1; --frequentante
    end if;


    RETURN nRicorrenza;
END;
$function$
;
----------------------------------------------------------------------------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_fre_mat(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);
--
CREATE OR REPLACE FUNCTION punteggio_cf_fra_fre_mat(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
DECLARE
  vFound  BOOLEAN;
  vFvalida BOOLEAN;
  vMonth smallint;
  vId_anno integer;
  vId_scuola integer;
  vCodiceFisc char(16);
  vFl_attivo_sospeso integer;

BEGIN
  pRicorrenza = 0;
  pFlagvalida = NULL;
  vFl_attivo_sospeso= null;
-- Verifico se il minore esiste
  SELECT fraFre.cf_fratello
  into vCodiceFisc
    FROM  iscritto_t_domanda_isc    domIsc
        , iscritto_t_fratello_fre   fraFre
        , iscritto_d_tipo_fra       tipFra
    WHERE domIsc.id_domanda_iscrizione = fraFre.id_domanda_iscrizione
      AND domIsc.id_domanda_iscrizione = pIdDomandaIscrizione
      AND fraFre.id_tipo_fratello = tipFra.id_tipo_fratello
      AND domIsc.fl_fratello_freq = 'S'
      AND tipFra.cod_tipo_fratello = 'FREQ'
      group by fraFre.cf_fratello;


  if (vCodiceFisc is not null)  then
  	pRicorrenza = 1;

  	select extract(month from current_timestamp)
  	into vMonth;

 	-- Selezione dell'anno scolastico
 	  select id_anno_scolastico
		  into vId_anno
		  from iscritto_t_domanda_isc
		  where id_domanda_iscrizione=piddomandaiscrizione;

 	if(vMonth>0 and vMonth<9) then
	-- se siamo prima di settembre si prende l'anno scolastico in corso che quello precedente a quello della domanda
		select id_anno_scolastico
		into vId_anno
		from iscritto_t_anno_sco
		where data_da < (select data_da
					from iscritto_t_anno_sco
					where id_anno_scolastico= vId_anno)
		order by data_da desc
		limit 1;
 	end if;

    -- Selezione dell'id_scuola
		select id_scuola
		into vId_scuola
		from iscritto_r_scuola_pre
		where id_domanda_iscrizione= piddomandaiscrizione
		and posizione=1;

    	SELECT fl_attivo_sospeso
    	INTO  vFl_attivo_sospeso
    	FROM  iscritto_t_freq_nido_sise
    	WHERE codice_fiscale=vCodiceFisc
    	and id_anno_scolastico=vId_anno
    	and id_scuola=vId_scuola
    	and (cod_fascia not in ('III','E') or vMonth >= 9)  
    	order by dt_variazione desc
		limit 1;

    	if vFl_attivo_sospeso=1 then
       	pFlagvalida='S';
    	end if;
    end if;
END;
$function$
;


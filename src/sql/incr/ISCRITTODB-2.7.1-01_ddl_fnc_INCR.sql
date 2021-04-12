------------------------------------------------------------------------------------------------------------------
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
  
  UPDATE  iscritto_t_graduatoria 
    SET id_stato_scu = GetIdStatoScuola('PEN')
    where id_step_gra_con = pIdStepGraduatoriaCon
--    AND ordine_preferenza <> 1
    AND id_stato_scu IN ( GetIdStatoScuola('AMM'), GetIdStatoScuola('CAN_1SC'))
    and id_domanda_iscrizione IN(select B.id_domanda_iscrizione  
                                     from iscritto_t_graduatoria B
                                  WHERE B.id_step_gra_con = pIdStepGraduatoriaCon
                                    AND B.ordine_preferenza = 1
                                    AND B.id_stato_scu IN ( GetIdStatoScuola('AMM')));
  
  --iscritto-35 Borazio
--  UPDATE  iscritto_t_graduatoria
--    SET id_stato_scu = GetIdStatoScuola('PEN')
--    WHERE id_step_gra_con = pIdStepGraduatoriaCon
--    AND ordine_preferenza = 1
--    AND id_stato_scu IN ( GetIdStatoScuola('AMM'), GetIdStatoScuola('CAN_1SC'));

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
$function$
;

------------------------------------------------------------------------------------------------------------------
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
  --EA record      iscritto_d_fascia_eta.cod_fascia_eta%TYPE;
BEGIN
  
  -- eseguo la query di ordinamento per ogni fascia d'eta' delle materne
  ----------
--EA  FOR record IN SELECT cod_fascia_eta 
--EA 						from iscritto_d_fascia_eta 
--EA 						where id_ordine_scuola = 2
--EA   LOOP
	  
      -- eseguo la query di ordinamento per la data fascia d'eta' nel record
  	  ----------
  	  nOrdinamento = 0;
	 
	  FOR grad IN SELECT gr.id_graduatoria
					FROM iscritto_t_graduatoria gr
--EA 					join iscritto_d_fascia_eta fascEta on
--EA 						fascEta.id_fascia_eta = gr.id_fascia_eta
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
					    and scuPre.id_scuola=gr.id_scuola
--EA 						and	fascEta.cod_fascia_eta = record		-- fascia eta' del record
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
	 
--EA  END LOOP;
  ----------
  RETURN 0;
END;
$function$
;


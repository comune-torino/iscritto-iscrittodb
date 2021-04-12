----------------------------------------------------------------------------------------------------------------------
-- Già rilasciata il 28.01.2021
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

----------------------------------------------------------------------------------------------------------------------
DROP FUNCTION calcolapunteggio(pidstepgracon integer);
--
CREATE OR REPLACE FUNCTION calcolapunteggio(pidstepgracon integer)
  RETURNS smallint
  LANGUAGE plpgsql
AS
$body$
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
$body$
  VOLATILE
  COST 100;

----------------------------------------------------------------------------------------------------------------------
DROP FUNCTION inseriscidomandeingraduatoria(pidstepgraddacalcolare integer, vordinescuola integer);
--
CREATE OR REPLACE FUNCTION inseriscidomandeingraduatoria(pidstepgraddacalcolare integer, vordinescuola integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    param    RECORD;
    domanda  RECORD;
    scuola   RECORD;
    -------
    nRetCode INTEGER;
    bRetCode BOOLEAN;
BEGIN
    -- Leggo i parametro generali relativi allo step da calcolare
    SELECT *
    INTO param
    FROM GetInfoStepGraduatoria(pIdStepGradDaCalcolare);
    -------
    -- UM-20201202 modificata completamente la query di estrazione delle domande utilizzando
    --            il parametro pidstepgraddacalcolare per far si' che prenda solo le domande
    --			legate alla graduatoria	in fase di calcolo (nidi oppure materne)
    FOR domanda IN select dom.id_domanda_iscrizione id_domanda_iscrizione,
                          dom.fl_fratello_freq      fl_fratello_freq
                   from iscritto_t_domanda_isc dom
                            join iscritto_t_anagrafica_gra ag on
                           ag.id_anno_scolastico = dom.id_anno_scolastico
                           and ag.id_ordine_scuola = dom.id_ordine_scuola
                            join iscritto_t_step_gra sg on
                       sg.id_anagrafica_gra = ag.id_anagrafica_gra
                            left join iscritto_t_step_gra_con sgc on
                       sgc.id_step_gra = sg.id_step_gra
                   where dom.id_stato_dom = 2 -- 'INV'
                     and dom.fl_istruita = 'S'
                     and sgc.id_step_gra_con = pidstepgraddacalcolare
                     and DATE_TRUNC('day', dom.data_consegna) between DATE_TRUNC('day', param.pDataDomandaInvioDa) and DATE_TRUNC('day', param.pDataDomandaInvioA)
        LOOP
            bRetCode = ValidaCondizioneCfFraIsc(domanda.id_domanda_iscrizione);
            -- Per questa domanda leggo tutte le scuole collegate
            FOR scuola IN SELECT id_scuola
                               , fl_fuori_termine
                               , id_tipo_frequenza
                               , posizione
                          FROM iscritto_r_scuola_pre
                          WHERE id_domanda_iscrizione = domanda.id_domanda_iscrizione
                LOOP
                    -- Per ogni scuola della domanda inserisco in record
                    if (vordinescuola = 1) then
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
                        , id_fascia_eta)
                        VALUES ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
                               , pIdStepGradDaCalcolare
                               , scuola.id_scuola
                               , domanda.id_domanda_iscrizione
                               , scuola.fl_fuori_termine
                               , scuola.id_tipo_frequenza
                               , GetIdStatoScuola('PEN')
                               , GetValoreIsee(domanda.id_domanda_iscrizione)
                               , scuola.posizione
                               , GetIdFasciaEta(domanda.id_domanda_iscrizione));
                    end if;
                    if (vordinescuola = 2) then
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
                        , id_fascia_eta)
                        VALUES ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
                               , pIdStepGradDaCalcolare
                               , scuola.id_scuola
                               , domanda.id_domanda_iscrizione
                               , scuola.fl_fuori_termine
                               , scuola.id_tipo_frequenza
                               , GetIdStatoScuola('PEN')
                               , GetValoreIsee(domanda.id_domanda_iscrizione)
                               , scuola.posizione
                               , GetIdFasciaEtaMat(domanda.id_domanda_iscrizione, scuola.id_scuola));
                    end if;
                END LOOP;
        END LOOP;
    --------
    RETURN 0;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------
DROP FUNCTION calcolagraduatoria(pidstepgraddacalcolare integer, pidstepgradprecedente integer, pflag character varying);
--
CREATE OR REPLACE FUNCTION calcolagraduatoria(pidstepgraddacalcolare integer, pidstepgradprecedente integer, pflag character varying)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
    nRetCode      INTEGER;
    nOrdinamento  iscritto_t_graduatoria.ordinamento%TYPE;
    vOrdineScuola iscritto_t_anagrafica_gra.id_ordine_scuola%TYPE;
    -------
    grad          RECORD;
BEGIN

    select iscritto_t_anagrafica_gra.id_ordine_scuola
    into vOrdineScuola
    from iscritto_t_anagrafica_gra
             join iscritto_t_step_gra
                  on iscritto_t_anagrafica_gra.id_anagrafica_gra = iscritto_t_step_gra.id_anagrafica_gra
             join iscritto_t_step_gra_con on iscritto_t_step_gra.id_step_gra = iscritto_t_step_gra_con.id_step_gra
    where iscritto_t_step_gra_con.id_step_gra_con = pidstepgraddacalcolare;


    IF pFlag = 'P' THEN
        -- FLAG 'P'
        IF pIdStepGradPrecedente IS NOT NULL THEN
            -- Se esiste uno step precedente pulisco la tabella di tutti i record relativi allo step attuale
            DELETE
            FROM iscritto_t_graduatoria
            WHERE id_step_gra_con = pIdStepGradPrecedente;
        END IF;
        -------
        nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare, vOrdineScuola);
        if (vOrdineScuola = 1) then
            nRetCode = AttribuisciCondizione(pIdStepGradDaCalcolare, 'LA_PER');
        end if;
        nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);
        nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare);-- Ordino la graduatoria
    ELSIF pFlag = 'D' THEN
        -- FLAG 'D'
        --  3. Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l'id_step_graduatoria_con precedente
        --      nella stessa tabella con l'id_step_graduatoria_con da calcolare.
        nRetCode = DuplicaGraduatoria(pIdStepGradPrecedente, pIdStepGradDaCalcolare);
        FOR grad IN SELECT id_domanda_iscrizione id_domanda_iscrizione
                         , id_scuola             id_scuola
                         , id_tipo_frequenza     id_tipo_frequenza
                         , punteggio             punteggio
                    FROM iscritto_t_graduatoria
                    WHERE id_step_gra_con = pIdStepGradPrecedente
            LOOP
                UPDATE iscritto_r_scuola_pre
                SET id_stato_scu = GetIdStatoScuola('PEN')
                  , punteggio    = grad.punteggio
                  , dt_stato     = CURRENT_TIMESTAMP
                WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione
                  AND id_scuola = grad.id_scuola
                  AND id_tipo_frequenza = grad.id_tipo_frequenza;
                UPDATE iscritto_t_domanda_isc
                SET id_stato_dom = GetIdStatoDomanda('GRA')
                WHERE id_domanda_iscrizione = grad.id_domanda_iscrizione;
            END LOOP;
    ELSIF pFlag = 'S' THEN
        -- FLAG 'S'
        -- 1. Copiare tutti i record della tabella ISCRITTO_T_GRADUATORIA identificati con l'id_step_graduatoria_con precedente nella
        --    stessa tabella con l'id_step_graduatoria_con da calcolare.
         nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare, vOrdineScuola);
        if (vOrdineScuola = 1) then
            nRetCode = AttribuisciCondizione(pIdStepGradDaCalcolare, 'LA_PER');
        end if;
--    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);   FE 16/09/2019
        nRetCode = DuplicaGraduatoria(pIdStepGradPrecedente, pIdStepGradDaCalcolare);
        /* Inserimento in graduatoria scuole fuori termine
              *	Per tutte le domande copiate nella nuova graduatoria occorre verificare se nella data dello step sono state aggiunte
                scuole di preferenza: ISCRITTO_R_SCUOLA_PRE.dt_ins_scu compresa tra ISCRITTO_T_STEP_GRA.dt_dom_inv_da
                e ISCRITTO_T_STEP_GRA.dt_dom_inv_a
              *	Per ogni record di ISCRITTO_R_SCUOLA_PRE trovato nel passo precedente:
              *	Eseguire lo step 5 del caso con il FLAG P.
        */
        FOR grad IN SELECT DISTINCT scuPre.id_scuola             id_scuola
                                  , scuPre.id_domanda_iscrizione id_domanda_iscrizione
                                  , scuPre.fl_fuori_termine      fl_fuori_termine
                                  , scuPre.id_tipo_frequenza     id_tipo_frequenza
                                  , scuPre.posizione             posizione
                    FROM iscritto_t_graduatoria gr
                       , iscritto_t_domanda_isc domIsc
                       , iscritto_r_scuola_pre scuPre
                       , iscritto_t_step_gra_con stepGraCon
                       , iscritto_t_step_gra stepGra
                    WHERE gr.id_domanda_iscrizione = domIsc.id_domanda_iscrizione
                      AND domIsc.id_domanda_iscrizione = scuPre.id_domanda_iscrizione
                      AND gr.id_step_gra_con = stepGraCon.id_step_gra_con
                      AND stepGraCon.id_step_gra = stepGra.id_step_gra
                      AND gr.id_step_gra_con = pIdStepGradDaCalcolare
                      AND domIsc.id_stato_dom = 4
                      AND scuPre.dt_ins_scu BETWEEN stepGra.dt_dom_inv_da AND stepGra.dt_dom_inv_a
            LOOP
                if (vOrdineScuola = 1) then
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
                    , id_fascia_eta)
                    VALUES ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
                           , pIdStepGradDaCalcolare
                           , grad.id_scuola
                           , grad.id_domanda_iscrizione
                           , grad.fl_fuori_termine
                           , grad.id_tipo_frequenza
                           , GetIdStatoScuola('PEN')
                           , GetValoreIsee(grad.id_domanda_iscrizione)
                           , grad.posizione
                           , GetIdFasciaEta(grad.id_domanda_iscrizione));
                end if;
                if (vOrdineScuola = 2) then
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
                    , id_fascia_eta)
                    VALUES ( nextval('iscritto_t_graduatoria_id_graduatoria_seq')
                           , pIdStepGradDaCalcolare
                           , grad.id_scuola
                           , grad.id_domanda_iscrizione
                           , grad.fl_fuori_termine
                           , grad.id_tipo_frequenza
                           , GetIdStatoScuola('PEN')
                           , GetValoreIsee(grad.id_domanda_iscrizione)
                           , grad.posizione
                           , GetIdFasciaEtaMat(grad.id_domanda_iscrizione, grad.id_scuola));
                end if;

            END LOOP;
        ------
        nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare); -- FE 16/09/2019
        nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
    END IF;
    -------
    RETURN 0;
END;
$function$
;

----------------------------------------------------------------------------------------------------------------------
DROP FUNCTION getidfasciaetamat(piddomandaiscrizione integer, pidscuola integer);
--
CREATE OR REPLACE FUNCTION getidfasciaetamat(piddomandaiscrizione integer, pidscuola integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    nIdFasciaEta iscritto_t_eta.id_fascia_eta%TYPE;
BEGIN
    SELECT eta.id_fascia_eta
    INTO nIdFasciaEta
    FROM iscritto_t_domanda_isc domIsc
       , iscritto_t_anno_sco annoSco
       , iscritto_d_ordine_scuola ordScu
       , iscritto_t_anagrafica_gra anagGra
       , iscritto_t_eta eta
       , iscritto_t_anagrafica_sog anagSog
       , iscritto_r_soggetto_rel sogRel
       , iscritto_d_tipo_sog tipoSog
       , iscritto_t_classe classe
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
      AND anagSog.data_nascita BETWEEN eta.data_da AND eta.data_a
      and classe.id_anno_scolastico = anagGra.id_anno_scolastico
      and classe.id_eta = eta.id_eta
      and classe.id_Scuola = pIdScuola;
    RETURN nIdFasciaEta;
END;
$function$
;
  
----------------------------------------------------------------------------------------------------------------------

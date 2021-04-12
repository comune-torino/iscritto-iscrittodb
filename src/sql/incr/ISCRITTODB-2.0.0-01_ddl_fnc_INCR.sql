CREATE OR REPLACE FUNCTION cancelladomande(pcodordinescuola character varying)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  nIdOrdineScuola   iscritto_d_ordine_scuola.id_ordine_scuola%TYPE;
  nIdStatoDomanda   iscritto_d_stato_dom.id_stato_dom%TYPE;
  rAnagGra          RECORD;
  rec               RECORD;
  recSog               RECORD;
  recAll               RECORD;
  recOcc               RECORD;
nRetCode          SMALLINT;
BEGIN
  nIdOrdineScuola = GetIdOrdineScuola(pCodOrdineScuola);
--  SELECT  *                                      E.F. 14/11/2019
--    INTO strict rAnagGra                         E.F. 14/11/2019
--    FROM  iscritto_t_anagrafica_gra              E.F. 14/11/2019
--    WHERE id_ordine_scuola = nIdOrdineScuola     E.F. 14/11/2019
--      AND dt_inizio_iscr = CURRENT_DATE+1;       E.F. 14/11/2019   
  -------
  
 	select *
	INTO strict rAnagGra
	from iscritto_t_anagrafica_gra
	where dt_inizio_iscr= 
		(select max(dt_inizio_iscr)
		from iscritto_t_anagrafica_gra
		where exists ( select 1 from iscritto_t_anagrafica_gra where trunc(dt_inizio_iscr)= CURRENT_DATE+1 and id_ordine_scuola=nIdOrdineScuola )
		and dt_inizio_iscr < CURRENT_DATE+1
		and id_ordine_scuola=nIdOrdineScuola)
		and id_ordine_scuola=nIdOrdineScuola;

  nIdStatoDomanda = GetIdStatoDomanda('BOZ');
  -------
  nRetCode = 2;
  -------
  FOR rec IN  SELECT  id_domanda_iscrizione
                FROM  iscritto_t_domanda_isc
                WHERE id_anno_scolastico = rAnagGra.id_anno_scolastico
                  AND id_ordine_scuola = rAnagGra.id_ordine_scuola
                  AND id_stato_dom = nIdStatoDomanda
  LOOP
    nRetCode = 0;
    -- Cancello i record nelle tabelle figlie
    DELETE FROM iscritto_t_trasferimento WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_servizi_soc WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_isee WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_genitore_solo WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_fratello_fre WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_cambio_res WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
--    DELETE FROM iscritto_t_anagrafica_sog WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_r_scuola_pre WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
 
   FOR recSog IN  SELECT  id_anagrafica_soggetto
                FROM  iscritto_t_anagrafica_sog
                WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione
   LOOP
    nRetCode = 0;
  
 	DELETE FROM iscritto_r_soggetto_rel WHERE id_anagrafica_soggetto=recSog.id_anagrafica_soggetto;
 	DELETE FROM iscritto_t_indirizzo_res WHERE id_anagrafica_soggetto=recSog.id_anagrafica_soggetto;
	DELETE FROM iscritto_t_affido WHERE id_anagrafica_soggetto=recSog.id_anagrafica_soggetto;

   		   FOR recAll IN  SELECT  id_allegato
                FROM  iscritto_t_allegato
                WHERE id_anagrafica_soggetto = recSog.id_anagrafica_soggetto
   			LOOP
    			nRetCode = 0;
				DELETE FROM iscritto_t_allegato_red WHERE id_allegato=recAll.id_allegato;
			end loop;
		
	   	   FOR recOcc IN  SELECT  id_condizione_occupazionale
                FROM  iscritto_t_condizione_occ
                WHERE id_anagrafica_soggetto = recSog.id_anagrafica_soggetto
   			LOOP
    			nRetCode = 0;
				DELETE FROM iscritto_t_disoccupato WHERE id_condizione_occupazionale=recOcc.id_condizione_occupazionale;
				DELETE FROM iscritto_t_dipendente WHERE id_condizione_occupazionale=recOcc.id_condizione_occupazionale;
				DELETE FROM iscritto_t_autonomo WHERE id_condizione_occupazionale=recOcc.id_condizione_occupazionale;
				DELETE FROM iscritto_t_studente WHERE id_condizione_occupazionale=recOcc.id_condizione_occupazionale;
				DELETE FROM iscritto_t_disoccupato_ex WHERE id_condizione_occupazionale=recOcc.id_condizione_occupazionale;
			end loop;
	
   	DELETE FROM iscritto_t_allegato WHERE id_anagrafica_soggetto=recSog.id_anagrafica_soggetto;
    DELETE FROM iscritto_t_condizione_san WHERE id_anagrafica_soggetto=recSog.id_anagrafica_soggetto;
 	DELETE FROM iscritto_t_condizione_occ WHERE id_anagrafica_soggetto=recSog.id_anagrafica_soggetto;
end loop;
   
    DELETE FROM iscritto_t_anagrafica_sog WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
END LOOP;

  -------
  IF nRetCode = 0 THEN
    -- Cancello le domande
    DELETE
      FROM  iscritto_t_domanda_isc
      WHERE id_anno_scolastico = rAnagGra.id_anno_scolastico
        AND id_ordine_scuola = rAnagGra.id_ordine_scuola
        AND id_stato_dom = nIdStatoDomanda;
  END IF;
  -------
  RETURN nRetCode;
EXCEPTION
--  WHEN NO_DATA_FOUND THEN
--    RETURN 1;
  WHEN OTHERS THEN
    RETURN 1;
END;
$function$
;

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
$function$
;

CREATE OR REPLACE FUNCTION punteggio_pa_prb_sal_alt(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
--  soggetto    RECORD;
  nFound      NUMERIC(1);
BEGIN
  nRicorrenza = 0;
  -- Per ogni soggetto della domanda...
--  FOR soggetto IN SELECT  id_anagrafica_soggetto
--                    FROM  iscritto_t_anagrafica_sog
--                    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
--  LOOP
    -- Verifico se esiste almeno un record con allegato di tipo SAL
    SELECT  nRicorrenza + COUNT(1)
      INTO  nRicorrenza
      FROM  iscritto_t_condizione_san   condSan
          , iscritto_t_allegato         alleg
          , iscritto_d_tipo_all         tipAlleg
          , iscritto_t_anagrafica_sog   soggetto
          , iscritto_r_soggetto_rel     sog_rel
          , iscritto_d_tipo_sog         tip_sog
      WHERE condSan.id_anagrafica_soggetto = soggetto.id_anagrafica_soggetto
        AND condSan.id_anagrafica_soggetto = alleg.id_anagrafica_soggetto
        AND alleg.id_tipo_allegato = tipAlleg.id_tipo_allegato
        AND tipAlleg.cod_tipo_allegato = 'SAL'
        AND soggetto.id_anagrafica_soggetto=sog_rel.id_anagrafica_soggetto
        AND sog_rel.id_tipo_soggetto=tip_sog.id_tipo_soggetto
        AND tip_sog.cod_tipo_soggetto <> 'MIN'
        AND soggetto.id_domanda_iscrizione= pIdDomandaIscrizione;
--  END LOOP;
  -------
  IF nRicorrenza > 1 THEN
    nRicorrenza = 1;
  END IF;
  -------
  RETURN nRicorrenza;
END;
$function$
;

CREATE OR REPLACE FUNCTION punteggio_pa_prb_sal_min(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
--  soggetto    RECORD;
  nFound      NUMERIC(1);
BEGIN
  nRicorrenza = 0;
  -- Per ogni soggetto della domanda...
--  FOR soggetto IN SELECT  id_anagrafica_soggetto
--                    FROM  iscritto_t_anagrafica_sog
--                    WHERE id_domanda_iscrizione = pIdDomandaIscrizione
--  LOOP
    -- Verifico se esiste almeno un record con allegato di tipo SAL
    SELECT  nRicorrenza + COUNT(1)
      INTO  nRicorrenza
      FROM  iscritto_t_condizione_san   condSan
          , iscritto_t_allegato         alleg
          , iscritto_d_tipo_all         tipAlleg
          , iscritto_t_anagrafica_sog   soggetto
          , iscritto_r_soggetto_rel     sog_rel
          , iscritto_d_tipo_sog         tip_sog
      WHERE condSan.id_anagrafica_soggetto = soggetto.id_anagrafica_soggetto
        AND condSan.id_anagrafica_soggetto = alleg.id_anagrafica_soggetto
        AND alleg.id_tipo_allegato = tipAlleg.id_tipo_allegato
        AND tipAlleg.cod_tipo_allegato = 'SAL'
        AND soggetto.id_anagrafica_soggetto=sog_rel.id_anagrafica_soggetto
        AND sog_rel.id_tipo_soggetto=tip_sog.id_tipo_soggetto
        AND tip_sog.cod_tipo_soggetto='MIN'
        AND soggetto.id_domanda_iscrizione= pIdDomandaIscrizione;
--  END LOOP;
  -------
  IF nRicorrenza > 1 THEN
    nRicorrenza = 1;
  END IF;
  -------
  RETURN nRicorrenza;
END;
$function$
;

CREATE OR REPLACE FUNCTION punteggio_res_noto(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  rec RECORD;
BEGIN
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    RETURN 0;
  END IF;
  -------
  IF Punteggio_RES_TO_FUT(pIdDomandaIscrizione) > 0 THEN
    RETURN 0;
  END IF;
  -------
  IF Punteggio_RES_TO_FUT_NOTE(pIdDomandaIscrizione) > 0 THEN
    RETURN 0;
  END IF;
  -------
IF Punteggio_RES_NOTO_LAV(pIdDomandaIscrizione) > 0 THEN
    RETURN 0;
  END IF;
  -------
  RETURN 1;
END;
$function$
;

CREATE OR REPLACE FUNCTION punteggio_res_noto_lav(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  rec                         RECORD;
  nRicorrenza                 INTEGER;
  sCodTipCondOccupazionale    iscritto_d_tip_con_occ.cod_tip_cond_occupazionale%TYPE;
  nIdCondizioneOccupazionale  iscritto_t_condizione_occ.id_condizione_occupazionale%TYPE;
  bTentareSoggetto2           BOOLEAN;
BEGIN
  -- La condizione RES_TO non deve essere verificata
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    RETURN 0;
  END IF;
  ---------
  IF (Punteggio_RES_TO_FUT(pIdDomandaIscrizione) > 0 ) or (Punteggio_RES_TO_FUT_NOTE(pIdDomandaIscrizione) > 0 ) THEN
    RETURN 0;
  END IF;
  ---------
  bTentareSoggetto2 = FALSE;
  -- Per Soggetto 1
  sCodTipCondOccupazionale = 'DIP';
  nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG1', sCodTipCondOccupazionale);
  IF nIdCondizioneOccupazionale IS NULL THEN
    sCodTipCondOccupazionale = 'AUT';
    nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG1', sCodTipCondOccupazionale);
    IF nIdCondizioneOccupazionale IS NULL THEN
      bTentareSoggetto2 = TRUE;
    ELSE
      -- Soggetto 1 - Lavoratore autonomo
      IF GetDescComuneAutonomo(nIdCondizioneOccupazionale) = 'TORINO' THEN
        -- Condizione verificata
        nRicorrenza = 1;
        RETURN nRicorrenza;
      ELSE
        bTentareSoggetto2 = TRUE;
      END IF;
    END IF;
  ELSE
    -- Soggetto 1 - Dipendente
    IF GetDescComuneDipendente(nIdCondizioneOccupazionale) = 'TORINO' THEN
      -- Condizione verificata
      nRicorrenza = 1;
      RETURN nRicorrenza;
    ELSE
      bTentareSoggetto2 = TRUE;
    END IF;
  END IF;
  --------
  IF bTentareSoggetto2 THEN
    sCodTipCondOccupazionale = 'DIP';
    nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG2', sCodTipCondOccupazionale);
    IF nIdCondizioneOccupazionale IS NULL THEN
      sCodTipCondOccupazionale = 'AUT';
      nIdCondizioneOccupazionale = GetIdCondizioneOccupazionale(pIdDomandaIscrizione, 'SOG2', sCodTipCondOccupazionale);
      IF nIdCondizioneOccupazionale IS NOT NULL THEN
        -- Soggetto 2 - Lavoratore autonomo
        IF GetDescComuneAutonomo(nIdCondizioneOccupazionale) = 'TORINO' THEN
          -- Condizione verificata
          nRicorrenza = 1;
          RETURN nRicorrenza;
        END IF;
      END IF;
    ELSE
      -- Soggetto 2 - Dipendente
      IF GetDescComuneDipendente(nIdCondizioneOccupazionale) = 'TORINO' THEN
        -- Condizione verificata
        nRicorrenza = 1;
        RETURN nRicorrenza;
      END IF;
    END IF;
  END IF;
  -------
  nRicorrenza = 0;
  RETURN nRicorrenza;
END;
$function$
;

CREATE OR REPLACE FUNCTION punteggio_res_to_fut(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
  rec         RECORD;
BEGIN
  -- La condizione RES_TO non deve essere verificata
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    nRicorrenza = 0;
    RETURN nRicorrenza;
  END IF;
  ---------
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_cambio_res cr, iscritto_d_tipo_cambio_res trc
    WHERE cr.id_tipo_cambio_res=trc.id_tipo_cambio_res
    and   trc.cod_tipo_cambio_res <> 'RES_FUT'
	AND   cr.id_domanda_iscrizione = pIdDomandaIscrizione;
  -------
  RETURN nRicorrenza;
END;
$function$
;

CREATE OR REPLACE FUNCTION punteggio_res_to_fut_note(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  nRicorrenza INTEGER;
  rec         RECORD;
BEGIN
  -- La condizione RES_TO non deve essere verificata
  SELECT  *
    INTO  rec
    FROM  Punteggio_RES_TO(pIdDomandaIscrizione);
  IF rec.pRicorrenza > 0 THEN
    nRicorrenza = 0;
    RETURN nRicorrenza;
  END IF;
  ---------
  SELECT  COUNT(1)
    INTO  nRicorrenza
    FROM  iscritto_t_cambio_res cr, iscritto_d_tipo_cambio_res tcr 
    WHERE cr.id_tipo_cambio_res=tcr.id_tipo_cambio_res
    and   tcr.cod_tipo_cambio_res = 'RES_FUT'
	AND   cr.id_domanda_iscrizione = pIdDomandaIscrizione;
  -------
  RETURN nRicorrenza;
END;
$function$
;

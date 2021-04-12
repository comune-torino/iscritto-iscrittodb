----------------------------------------------------------------------
-- 2020-01-15 -- Stored
----------------------------------------------------------------------

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
      SELECT  *
      INTO  rec
      FROM  Punteggio_CF_FRA_FRE(pIdDomandaIscrizione);
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
  ELSIF pCodCondizione = 'PAR_ISEE' THEN
    pRicorrenza = Punteggio_PAR_ISEE(pIdDomandaIscrizione);
  END IF;
END;
$function$
;

-- ---------------------------------------------------------------
DROP FUNCTION punteggio_cf_fra_fre(piddomandaiscrizione integer);

DROP FUNCTION punteggio_cf_fra_fre(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying);

CREATE OR REPLACE FUNCTION punteggio_cf_fra_fre(piddomandaiscrizione integer, OUT pricorrenza integer, OUT pflagvalida character varying)
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
-- Verifico se il minore esiste ed è residente a Torino
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
	-- se siamo prima di settembre si prende l'anno scolastico in corso che è quello precedente a quello della domanda
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
    	and (cod_fascia <> 'G' or vMonth >= 9)
    	order by dt_variazione desc
		limit 1;

    	if vFl_attivo_sospeso=1 then
       	pFlagvalida='S';
    	end if;  
    end if;   
END;
$function$
;

-- --------------------------------------------------------------

CREATE OR REPLACE FUNCTION load_csv_freq_sise()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
declare
r_freq RECORD;
conta_presenza INTEGER;  
err_context text;
iter integer; -- dummy integer to iterate columns with
col text; -- variable to keep the column name at each iteration
col_first text; -- first column name, e.g., top left corner on a csv file or spreadsheet
lv_file text;
lv_id_anno iscritto_t_anno_sco.id_anno_scolastico%TYPE;
lv_id_scuola iscritto_t_scuola.id_scuola%type;

BEGIN
--   execute format('copy ISCRITTO_TMP_FREQ_SISE from %L with delimiter '';'' quote ''"'' csv ', csv_path);
--   commit;
--    iter := 1;
--    col_first := (select col_1 from ISCRITTO_TMP_FREQ_SISE limit 1);

    -- update the column names based on the first row which has the column names
 --   for col in execute format('select unnest(string_to_array(trim(temp_table::text, ''()''), '','')) from temp_table where col_1 = %L', col_first)
--  raise notice 'Value: %', csv_path;
   for r_freq in select *
     from iscritto_tmp_freq_sise
     loop
      conta_presenza := 0;
      lv_id_anno := null;
      lv_id_scuola := null;
     
     select id_anno_scolastico 
     into lv_id_anno
     from iscritto.iscritto_t_anno_sco 
      where cod_anno_scolastico = r_freq.codice_anno_scolastico;

      select id_scuola 
      into lv_id_scuola
      from iscritto.iscritto_t_scuola 
      where cod_scuola = r_freq.cod_scuola;


      select count(1) 
        into conta_presenza
        from iscritto_t_freq_nido_sise a
       where a.codice_fiscale     = r_freq.codice_fiscale
         and a.id_anno_scolastico = lv_id_anno
         and a.id_scuola          = lv_id_scuola
         and a.fl_attivo_sospeso  = r_freq.id_stato_freq;
        
      if conta_presenza = 0 then
         insert into iscritto_t_freq_nido_sise (codice_fiscale,id_anno_scolastico,id_scuola,cod_fascia,dt_variazione,fl_attivo_sospeso)
              values(r_freq.codice_fiscale,lv_id_anno,lv_id_scuola,r_freq.classe,CURRENT_TIMESTAMP,r_freq.id_stato_freq);
       end if;
   end loop;
  
   return(0);
exception
  when others then   
        GET STACKED DIAGNOSTICS err_context = PG_EXCEPTION_CONTEXT;
        RAISE INFO 'Error Name:%',SQLERRM;
        RAISE INFO 'Error State:%', SQLSTATE;
        RAISE INFO 'Error Context:%', err_context;
  return(1);   
END;
$function$
;

----------------------------------------------------------------------
-- 2020-02-17 - P.S. --> 
----------------------------------------------------------------------

CREATE OR REPLACE FUNCTION preparadatisise()
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
--    sRecord = sRecord || ';' || rec.valore_isee;                                    -- •	Valore ISEE
    sRecord = sRecord || ';' || rec.cod_nido_accettazione;                          -- •	Codice nido accettazione
    sRecord = sRecord || ';' || GetCodFasciaEta(rec.id_domanda_iscrizione);         -- •	Codice fascia d’età
    sRecord = sRecord || ';' || rec.cod_tipo_frequenza;                             -- •	Tempo di frequenza
    sRecord = sRecord || ';' || TO_CHAR(rec.inizio_anno_scolastico,'DD/MM/YYYY');   -- •	Data inizio anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.fine_anno_scolastico,'DD/MM/YYYY');     -- •	Data fine anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.data_accettazione,'DD/MM/YYYY');        -- •	Data accettazione
    sRecord = sRecord || ';';                                                       -- •	Esito trasferimento
    sRecord = sRecord || ';';                                                       -- •	Dettaglio errore
    sRecord = sRecord || ';' ||sCodiceParentela;                                    -- •	Tipo prichiedente
    sRecord = sRecord || ';' ||coalesce(rec.tipo_pasto,'');                                          -- •	Tipo pasto
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

----------------------------------------------------------------------
-- 2020-02-17 - P.S. --> 
----------------------------------------------------------------------

 CREATE OR REPLACE FUNCTION getiddomandaiscrizionefratello(piddomandaiscrizione integer)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
      and dom1.id_anno_scolastico=dom2.id_anno_scolastico;
  --------
  RETURN nIdDomandaIscrizioneFratello;
END;
$function$
;

CREATE OR REPLACE FUNCTION attribuiscicondizioni(pcodordinescuola character varying, pdatada date, pdataa date)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  domanda                 RECORD;
  alleg                   RECORD;
  condiz                  RECORD;
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
    FOR condiz IN SELECT  id_condizione_punteggio   id_condizione_punteggio
                        , cod_condizione            cod_condizione
                    FROM  iscritto_d_condizione_pun
                    WHERE cod_condizione <> 'LA_PER'
                    ORDER BY  id_condizione_punteggio
    LOOP
      sCodCondizione = condiz.cod_condizione;
      SELECT  *
        INTO  rec
        FROM  Punteggio(sCodCondizione, nIdDomandaIscrizione);
      IF rec.pRicorrenza > 0 THEN
        nRetCode = AggiungiCondizionePunteggio ( domanda.id_domanda_iscrizione, condiz.id_condizione_punteggio, rec.pRicorrenza, rec.pFlagValida );
      END IF;
    END LOOP;
    ---------
    /*
      Se tutte le condizioni di punteggio associate alla domanda che sono legate al tipo di istruttoria ‘Preventiva’ sono state tutte istruite occorre settare il flag di domanda istruita della domanda.
      1.	Selezionare tutte le condizioni di punteggio della domanda che hanno l’istruttoria preventiva. 
      Eseguire una query sulla tabella ISCRITTO_R_PUNTEGGIO_DOM con filtro: id_domanda_iscrizione, dt_fine_validita=NULL e fl_validita=NULL e id_condizione_punteggio che ha fl_istruttoria=’P’ nel record della tabella ISCRITTO_D_CONDIZIONE_PUNTEGGIO.
    */
    SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
      INTO  vFound
      FROM  iscritto_r_punteggio_dom    puntDom
          , iscritto_d_condizione_pun   condPunt
      WHERE puntDom.id_condizione_punteggio = condPunt.id_condizione_punteggio
        AND puntDom.id_domanda_iscrizione = nIdDomandaIscrizione
        AND puntDom.dt_fine_validita IS NULL
        AND puntDom.fl_valida IS NULL
        AND condPunt.fl_istruttoria = 'P';
    /*
      2.	Se sono non sono stati trovati record si imposta il flag ISCRITTO_T_DOMANDA_ISC.fl_istruita=’S’
    */
    IF NOT vFound THEN
      UPDATE  iscritto_t_domanda_isc
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
  SELECT  CASE WHEN COUNT(1) = 0 THEN FALSE ELSE TRUE END
    INTO  vFound
    FROM  ( SELECT  dt_allegati
              FROM  ( SELECT  stepGra.dt_allegati   dt_allegati
                        FROM  iscritto_t_step_gra         stepGra
                            , iscritto_t_anagrafica_gra   anagGra
                        WHERE stepGra.id_anagrafica_gra = anagGra.id_anagrafica_gra
                          AND stepGra.dt_step_gra > CURRENT_DATE
                          AND anagGra.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
                        ORDER BY  stepGra.dt_step_gra
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
        /*
          5.	Se è stato inserito un nuovo record nella tabella ISCRITTO_R_PUNTEGGIO_DOM allora occorre resettare il flag di domanda istruita della domanda:
          •	Impostare ISCRITTO_T_DOMANDA_ISC.fl_istruita=’N’
        */
        UPDATE  iscritto_t_domanda_isc
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

CREATE OR REPLACE FUNCTION cancelladomandeall(pid_anno_sco integer, pid_ordine_scu integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
DECLARE
  nIdOrdineScuola   iscritto_d_ordine_scuola.id_ordine_scuola%TYPE;
  rAnagGra          RECORD;
  rec               RECORD;
  recSog               RECORD;
  recAll               RECORD;
  recOcc               RECORD;
  recInvAcc            RECORD;
nRetCode          SMALLINT;
BEGIN
 nRetCode = 0;
  -------
  FOR rec IN  SELECT  id_domanda_iscrizione
                FROM  iscritto_t_domanda_isc
                WHERE id_anno_scolastico = pid_anno_sco
                  AND id_ordine_scuola = pid_ordine_scu
  --                and id_domanda_iscrizione= 997
  LOOP
    nRetCode = 0;
    -- Cancello i record nelle tabelle figlie
    DELETE FROM iscritto_t_trasferimento WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_servizi_soc WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_isee WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_genitore_solo WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_fratello_fre WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_t_cambio_res WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_r_scuola_pre WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_r_lista_attesa WHERE id_domanda_isc = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_r_punteggio_dom WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
    DELETE FROM iscritto_r_nido_contiguo WHERE id_domanda_isc = rec.id_domanda_iscrizione;

   FOR recInvAcc IN  SELECT  id_accettazione_rin
   FROM  iscritto_t_acc_rin
                WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione
   			LOOP
    			nRetCode = 0;
				DELETE FROM iscritto_t_invio_acc WHERE id_accettazione_rin=recInvAcc.id_accettazione_rin;
			end loop;

   delete FROM  iscritto_t_acc_rin WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
   
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
	delete from iscritto_t_graduatoria WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
	delete from iscritto_t_invio_sms WHERE id_domanda_iscrizione = rec.id_domanda_iscrizione;
END LOOP;

  -------
  IF nRetCode = 0 THEN
    -- Cancello le domande
    DELETE
      FROM  iscritto_t_domanda_isc
      WHERE id_anno_scolastico = pid_anno_sco
        AND id_ordine_scuola = pid_ordine_scu;
--        and id_domanda_iscrizione= 997;
  END IF; 
  -------
  RETURN nRetCode;
 
EXCEPTION
--  WHEN NO_DATA_FOUND THEN
--    RETURN 2;
WHEN OTHERS THEN
    RETURN 1; 
END;
$function$
;

CREATE OR REPLACE FUNCTION calcolapunteggiodomanda(piddomandaiscrizione integer, pidstepgracon integer)
 RETURNS smallint
 LANGUAGE plpgsql
AS $function$
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
                        , fl_fuori_termine    fl_fuori_termine
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
        , fl_fuori_termine = scuola.fl_fuori_termine
      WHERE id_domanda_iscrizione = pIdDomandaIscrizione
        AND id_scuola = scuola.id_scuola
        AND id_step_gra_con = pIdStepGraCon
        AND id_tipo_frequenza = scuola.id_tipo_frequenza;
  END LOOP;
  -------
  RETURN 0;
END;
$function$
;

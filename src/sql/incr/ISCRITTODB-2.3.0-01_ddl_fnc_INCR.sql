DROP FUNCTION calcolagraduatoria(pidstepgraddacalcolare integer, pidstepgradprecedente integer, pflag character varying);

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
--
-- debug
--  delete from iscritto_t_debug; 
--

--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'Inizio --> [pidstepgraddacalcolare='||coalesce(to_char(pidstepgraddacalcolare),'NULL')||'] [pidstepgradprecedente='||coalesce(to_char(pidstepgradprecedente),'NULL')||'][pFlag='||coalesce(pFlag,'NULL')||']');
--
  IF pFlag = 'P' THEN
    -- FLAG "P"
    IF pIdStepGradPrecedente IS NOT NULL THEN
      -- Se esiste uno step precedente pulisco la tabella di tutti i record relativi allo step attuale
      DELETE FROM iscritto_t_graduatoria
        WHERE id_step_gra_con = pIdStepGradPrecedente;
    END IF;
    -------
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'InserisciDomandeInGraduatoria');
--
    nRetCode = InserisciDomandeInGraduatoria(pIdStepGradDaCalcolare);
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'AttribuisciCondizione');
--
    nRetCode = AttribuisciCondizione(pIdStepGradDaCalcolare, 'LA_PER');
--
-- debug
--  insert into iscritto_t_debug(data, istruzione)
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'CalcolaPunteggio');
--
    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'OrdinaGraduatoria');
--
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
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'UPDATE iscritto_r_scuola_pre, iscritto_t_domanda_isc --> [id_domanda_iscrizione='||coalesce(to_char(grad.id_domanda_iscrizione),'NULL')||'] [id_scuola='||coalesce(to_char(grad.id_scuola),'NULL')||'][id_tipo_frequenza='||coalesce(to_char(grad.id_tipo_frequenza),'NULL')||']');
--
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
          #	Per tutte le domande copiate nella nuova graduatoria occorre verificare se nella data dello step sono state aggiunte
            scuole di preferenza: ISCRITTO_R_SCUOLA_PRE.dt_ins_scu compresa tra ISCRITTO_T_STEP_GRA.dt_dom_inv_da
            e ISCRITTO_T_STEP_GRA.dt_dom_inv_a
          #	Per ogni record di ISCRITTO_R_SCUOLA_PRE trovato nel passo precedente:
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
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'INSERT iscritto_t_graduatoria --> [id_domanda_iscrizione='||coalesce(to_char(grad.id_domanda_iscrizione),'NULL')||']');
--
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
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'CalcolaPunteggio 2');
--
    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);  -- FE 16/09/2019
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'OrdinaGraduatoria 2');
--
    nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
  END IF;
  -------
--
-- debug
--  insert into iscritto_t_debug(data, istruzione) 
--  values (to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS:US'),'Fine --> ');
--
  
  RETURN 0;
END;
$function$
;

DROP FUNCTION preparadatisise();
--
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
    sRecord = rec.codice_fiscale_minore;                                            -- #	Codice fiscale minore
    sRecord = sRecord || ';' || rec.cognome_minore;                                 -- #	Cognome minore
    sRecord = sRecord || ';' || rec.nome_minore;                                    -- #	Nome minore
    sRecord = sRecord || ';' || sCodiceFiscaleRichiedente;                          -- #	Codice fiscale richiedente
    sRecord = sRecord || ';' || sCognomeRichiedente;                                -- #	Cognome richiedente
    sRecord = sRecord || ';' || sNomeRichiedente;                                   -- #	Nome richiedente
    sRecord = sRecord || ';' || rec.telefono;                                       -- #	Telefono
    sRecord = sRecord || ';' || TO_CHAR(rec.data_nascita_minore,'DD/MM/YYYY');      -- #	Data nascita minore
    sRecord = sRecord || ';' || rec.indirizzo_residenza;                            -- #	Indirizzo residenza
    sRecord = sRecord || ';' || rec.cap_residenza;                                  -- #	CAP
    sRecord = sRecord || ';' || rec.istat_comune_residenza;                         -- #	Codice istat comune di residenza
--    sRecord = sRecord || ';' || rec.valore_isee;                                    -- #	Valore ISEE
    sRecord = sRecord || ';' || rec.cod_nido_accettazione;                          -- #	Codice nido accettazione
    sRecord = sRecord || ';' || GetCodFasciaEta(rec.id_domanda_iscrizione);         -- #	Codice fascia d'eta'
    sRecord = sRecord || ';' || rec.cod_tipo_frequenza;                             -- #	Tempo di frequenza
    sRecord = sRecord || ';' || TO_CHAR(rec.inizio_anno_scolastico,'DD/MM/YYYY');   -- #	Data inizio anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.fine_anno_scolastico,'DD/MM/YYYY');     -- #	Data fine anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.data_accettazione,'DD/MM/YYYY');        -- #	Data accettazione
    sRecord = sRecord || ';';                                                       -- #	Esito trasferimento
    sRecord = sRecord || ';';                                                       -- #	Dettaglio errore
    sRecord = sRecord || ';' ||sCodiceParentela;                                    -- #	Tipo prichiedente
    sRecord = sRecord || ';' ||coalesce(rec.tipo_pasto,'');                         -- #	Tipo pasto
    sRecord = sRecord || ';' || rec.protocollo;                                     -- #	Protocollo
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
                      , ordine_preferenza
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

DROP FUNCTION gettestosmsammissione(piddomandaiscrizione integer);
--
CREATE OR REPLACE FUNCTION gettestosmsammissione(piddomandaiscrizione integer)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
  vNome                 iscritto_t_anagrafica_sog.nome%TYPE;
  vTesto                VARCHAR(500);
  vLunghezzaMassimaNome INTEGER;
BEGIN
  select  TRIM(SCU.indirizzo), --anagSog.id_domanda_iscrizione,TRIM(anagSog.nome) , 
          REPLACE( par.testo_sms_amm , 'gg/mm/yyyy', TO_CHAR(NextSunday(CURRENT_DATE+1),'DD/MM/YYYY') )
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
      AND tipSog.cod_tipo_soggetto       = 'MIN';
     
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
$function$
;

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
$function$
;


----------------------------------------------------------------------
-- 2019-09-09 - gestione tipologia pasto
----------------------------------------------------------------------

ALTER TABLE iscritto_t_invio_acc ADD id_tipo_pasto int4 NULL;
ALTER TABLE iscritto_t_invio_acc ADD FOREIGN KEY (id_tipo_pasto) REFERENCES iscritto_d_tipo_pasto (id_tipo_pasto);

-----------------------------------------------------------------
-- 27/09/2019 - riciclo su alcune FUNCTION
-----------------------------------------------------------------

CREATE OR REPLACE FUNCTION iscritto.calcolagraduatoria(pidstepgraddacalcolare integer, pidstepgradprecedente integer, pflag character varying)
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
--    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);   FE 16/09/2019
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
    nRetCode = CalcolaPunteggio(pIdStepGradDaCalcolare);  -- FE 16/09/2019
    nRetCode = OrdinaGraduatoria(pIdStepGradDaCalcolare); -- Ordino la graduatoria
  END IF;
  -------
  RETURN 0;
END;
$function$
;

CREATE OR REPLACE FUNCTION iscritto.preparadatisise()
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
    sRecord = rec.codice_fiscale_minore;                                            -- Codice fiscale minore
    sRecord = sRecord || ';' || rec.cognome_minore;                                 -- Cognome minore
    sRecord = sRecord || ';' || rec.nome_minore;                                    -- Nome minore
    sRecord = sRecord || ';' || sCodiceFiscaleRichiedente;                          -- Codice fiscale richiedente
    sRecord = sRecord || ';' || sCognomeRichiedente;                                -- Cognome richiedente
    sRecord = sRecord || ';' || sNomeRichiedente;                                   -- Nome richiedente
    sRecord = sRecord || ';' || rec.telefono;                                       -- Telefono
    sRecord = sRecord || ';' || TO_CHAR(rec.data_nascita_minore,'DD/MM/YYYY');      -- Data nascita minore
    sRecord = sRecord || ';' || rec.indirizzo_residenza;                            -- Indirizzo residenza
    sRecord = sRecord || ';' || rec.cap_residenza;                                  -- CAP
    sRecord = sRecord || ';' || rec.istat_comune_residenza;                         -- Codice istat comune di residenza
--    sRecord = sRecord || ';' || rec.valore_isee;                                  -- Valore ISEE
    sRecord = sRecord || ';' || rec.cod_nido_accettazione;                          -- Codice nido accettazione
    sRecord = sRecord || ';' || GetCodFasciaEta(rec.id_domanda_iscrizione);         -- Codice fascia d’età
    sRecord = sRecord || ';' || rec.cod_tipo_frequenza;                             -- Tempo di frequenza
    sRecord = sRecord || ';' || TO_CHAR(rec.inizio_anno_scolastico,'DD/MM/YYYY');   -- Data inizio anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.fine_anno_scolastico,'DD/MM/YYYY');     -- Data fine anno scolastico
    sRecord = sRecord || ';' || TO_CHAR(rec.data_accettazione,'DD/MM/YYYY');        -- Data accettazione
    sRecord = sRecord || ';';                                                       -- Esito trasferimento
    sRecord = sRecord || ';';                                                       -- Dettaglio errore
    sRecord = sRecord || ';' ||sCodiceParentela;                                    -- Tipo prichiedente
    sRecord = sRecord || ';' ||coalesce(rec.tipo_pasto,'');                         -- Tipo pasto
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


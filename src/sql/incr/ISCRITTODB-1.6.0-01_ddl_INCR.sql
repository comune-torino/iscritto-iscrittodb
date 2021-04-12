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
                    , com.istat_comune              istat_comune_residenza
                    , scu.cod_scuola                cod_nido_accettazione
                    , tipFre.cod_tipo_frequenza     cod_tipo_frequenza
                    , annoSco.data_da               inizio_anno_scolastico
                    , annoSco.data_a                fine_anno_scolastico
                    , accRin.dt_operazione          data_accettazione
--                    , isee.valore_isee              valore_isee
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
--                    , iscritto_t_isee             isee
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
--                  AND domIsc.id_domanda_iscrizione = isee.id_domanda_iscrizione
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
    sRecord = sRecord || ';' ||sCodiceParentela;                               -- •	Tipo prichiedente
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
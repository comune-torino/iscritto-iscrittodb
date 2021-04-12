
----------------------------------------------------------------------
-- 2019-10-09 - ISBO-334
----------------------------------------------------------------------
-- per il prossimo rilascio
-- CREATE SEQUENCE iscritto_t_domanda_isc_protocollo_mat;

----------------------------------------------------------------------
-- 2019-10-09 - IS-406
----------------------------------------------------------------------
alter table iscritto_t_trasferimento alter column frequenza_al drop not null;

----------------------------------------------------------------------
-- 2019-10-11 - IS-417
----------------------------------------------------------------------
alter table iscritto_t_domanda_isc alter column fl_fratello_freq drop not null;

----------------------------------------------------------------------
-- 2019-10-15 - IS-347
----------------------------------------------------------------------
alter table iscritto_t_affido alter column num_sentenza drop not null;
alter table iscritto_t_affido alter column dt_sentenza drop not null;
alter table iscritto_t_affido alter column comune_tribunale drop not null;

----------------------------------------------------------------------
-- 2019-10-15
----------------------------------------------------------------------
drop function getinfostepgraduatoria(integer, OUT date, OUT date);

CREATE OR REPLACE FUNCTION getinfostepgraduatoria(pidstepgraduatoria integer, OUT pdatadomandainvioda timestamp, OUT pdatadomandainvioa timestamp)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
DECLARE
BEGIN
  SELECT  stepGrad.dt_dom_inv_da
        , stepGrad.dt_dom_inv_a
    INTO  pDataDomandaInvioDa
        , pDataDomandaInvioA
    FROM  iscritto_t_step_gra       stepGrad
        , iscritto_t_step_gra_con   stepGradCon
        , iscritto_d_stato_gra      statGrad
    WHERE stepGrad.id_step_gra = stepGradCon.id_step_gra
      AND stepGradCon.id_stato_gra = statGrad.id_stato_gra
      AND stepGradCon.id_step_gra_con = pIdStepGraduatoria;
END;
$function$
;

drop function getstepincorso(character varying);

CREATE OR REPLACE FUNCTION getstepincorso(pcodordinescuola character varying)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
  vIdStepInCorso  iscritto_t_step_gra_con.id_step_gra_con%TYPE;
BEGIN
  SELECT  stepGraCon.id_step_gra_con  id_step_graduatoria_con
    INTO  vIdStepInCorso
    FROM  iscritto_t_step_gra         stepGra
        , iscritto_t_anagrafica_gra   anagGra
        , iscritto_t_step_gra_con     stepGraCon
    WHERE stepGra.id_anagrafica_gra = anagGra.id_anagrafica_gra
      AND stepGra.id_step_gra = stepGraCon.id_step_gra
      AND anagGra.id_ordine_scuola = GetIdOrdineScuola(pCodOrdineScuola)
      AND stepGraCon.id_stato_gra = GetIdStatoGraduatoria('PUB')
      AND stepGra.dt_step_gra <= CURRENT_TIMESTAMP
      order by stepGra.dt_step_gra desc;
  RETURN vIdStepInCorso;
END;
$function$

----------------------------------------------------------------------
-- 2019-07-30 visualizzazione graduatoria DSE
----------------------------------------------------------------------
INSERT INTO iscritto_t_attivita
(id_attivita, cod_attivita, descrizione, link, id_funzione, ordinamento)
VALUES(14, 'GRA_RIC_DSE', 'Visualizzazione graduatoria DSE', '/graduatorie/ricerca/dse', 3, NULL);

INSERT INTO iscritto_t_privilegio
(id_privilegio, cod_privilegio, descrizione, id_attivita)
VALUES(19, 'P_GRA_RIC_DSE', 'Visualizzazione graduatoria DSE', 14);

-- superuser
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(1, 19, '1');

-- uffici centrali
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(2, 19, '1');

-- economa + bd
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(10, 19, '1');

----------------------------------------------------------------------
-- 2019-07-30 reportistica DSE
----------------------------------------------------------------------
INSERT INTO iscritto_t_attivita
(id_attivita, cod_attivita, descrizione, link, id_funzione, ordinamento)
VALUES(15, 'GRA_REP_DSE', 'Reportistica DSE', '/graduatorie/report', 3, NULL);

INSERT INTO iscritto_t_privilegio
(id_privilegio, cod_privilegio, descrizione, id_attivita)
VALUES(20, 'P_GRA_REP_DSE', 'Visualizzazione reportistica DSE', 15);

-- superuser
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(1, 20, '1');

-- uffici centrali
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(2, 20, '1');

----------------------------------------------------------------------
-- 2019-07-30 gestione classi
----------------------------------------------------------------------
DELETE FROM iscritto_r_profilo_pri WHERE id_privilegio = 5;

-- superuser
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(1, 5, '1');

-- uffici centrali
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(2, 5, '1');

-- nuovo profilo per pulsante elimina classe
INSERT INTO iscritto_t_privilegio
(id_privilegio, cod_privilegio, descrizione, id_attivita)
VALUES(21, 'P_GRA_DEL_CLS', 'Cancellazione classi', 5);

-- superuser
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(1, 21, '1');

-- uffici centrali
INSERT INTO iscritto_r_profilo_pri
(id_profilo, id_privilegio, fl_rw)
VALUES(2, 21, '1');


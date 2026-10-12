

USE readmissions;


-- PART A - EXPLORE
-- A1.data check
SELECT * FROM encounters_raw LIMIT 10;


-- A2. Missing values. 
SELECT
    COUNT(*) AS total_rows,
    SUM(race = '?') AS race_missing,
    SUM(weight = '?') AS weight_missing,
    SUM(payer_code = '?') AS payer_missing,
    SUM(medical_specialty = '?') AS specialty_missing,
    SUM(diag_1 = '?') AS diag1_missing,
    SUM(gender = 'Unknown/Invalid') AS gender_invalid,
    ROUND(100.0 * SUM(weight = '?') / COUNT(*), 1)  AS weight_missing_pct
FROM encounters_raw;



-- A3. Encounters vs. patients. One patient can have many hospital stays.
SELECT
    COUNT(*)  AS encounters,
    COUNT(DISTINCT patient_nbr) AS unique_patients
FROM encounters_raw;


-- A4. How many stays does each patient have?  
WITH stays_per_patient AS (
    SELECT patient_nbr, COUNT(*) AS n_stays
    FROM encounters_raw
    GROUP BY patient_nbr
)
SELECT
    CASE WHEN n_stays >= 5 THEN '5+' ELSE CAST(n_stays AS CHAR) END AS stays,
    COUNT(*) AS patients
FROM stays_per_patient
GROUP BY stays
ORDER BY MIN(n_stays);

-- A5. dropping patients that died and that were discharged  to hospice.
SELECT
    discharge_disposition_id,
    COUNT(*) AS encounters,
    ROUND(100.0 * AVG(readmitted = '<30'), 1) AS readmit_30_pct
FROM encounters_raw
GROUP BY discharge_disposition_id
ORDER BY encounters DESC;

-- A6. Check the coded text values we will need to clean.
SELECT a1c_result,    COUNT(*) AS n FROM encounters_raw GROUP BY a1c_result;
SELECT max_glu_serum, COUNT(*) AS n FROM encounters_raw GROUP BY max_glu_serum;
SELECT age,           COUNT(*) AS n FROM encounters_raw GROUP BY age ORDER BY age;

   -- PART B - BUILD THE CLEAN TABLE
 
DROP TABLE IF EXISTS encounters_clean;

CREATE TABLE encounters_clean AS
SELECT
    b.encounter_id,
    b.patient_nbr,
    ROW_NUMBER() OVER (PARTITION BY b.patient_nbr ORDER BY b.encounter_id) AS patient_stay_seq,
    COUNT(*)  OVER (PARTITION BY b.patient_nbr) AS patient_total_stays,
    CASE WHEN ROW_NUMBER() OVER (PARTITION BY b.patient_nbr ORDER BY b.encounter_id) = 1
         THEN 1 ELSE 0 END  AS is_first_stay,

    CASE WHEN b.race = '?' THEN 'Unknown' ELSE b.race END  AS race,
    b.gender,
    REPLACE(REPLACE(b.age, '[', ''), ')', '')  AS age_band,  
    CAST(SUBSTRING_INDEX(REPLACE(b.age, '[', ''), '-', 1) AS UNSIGNED)     AS age_start, 

    CASE b.admission_type_id
        WHEN 1 THEN 'Emergency'
        WHEN 2 THEN 'Urgent'
        WHEN 3 THEN 'Elective'
        WHEN 7 THEN 'Trauma Center'
        ELSE 'Other/Unknown'
    END  AS admission_type,

    CASE
        WHEN b.admission_source_id = 7  THEN 'Emergency Room'
        WHEN b.admission_source_id IN (1, 2, 3)  THEN 'Referral'
        WHEN b.admission_source_id IN (4, 5, 6, 10, 18, 22, 25, 26) THEN 'Transfer'
        ELSE 'Other/Unknown'
    END AS admission_source,

    CASE
        WHEN b.discharge_disposition_id = 1  THEN 'Home'
        WHEN b.discharge_disposition_id IN (6, 8)  THEN 'Home with health service'
        WHEN b.discharge_disposition_id IN (3, 4, 5, 15, 22, 23, 24, 27, 28, 29, 30)
                                                           THEN 'Care facility (SNF/rehab/LTC)'
        WHEN b.discharge_disposition_id IN (2, 9, 10)      THEN 'Another hospital'
        WHEN b.discharge_disposition_id = 7                THEN 'Left against medical advice'
        ELSE 'Other/Unknown'
    END     AS discharge_group,
    b.time_in_hospital  AS length_of_stay,
    CASE
        WHEN b.time_in_hospital <= 3 THEN '1-3 days'
        WHEN b.time_in_hospital <= 7 THEN '4-7 days'
        ELSE '8-14 days'
    END                                                                    AS los_group,
    CASE WHEN b.medical_specialty = '?' THEN 'Unknown' ELSE b.medical_specialty END AS medical_specialty,
    CASE WHEN b.payer_code = '?'        THEN 'Unknown' ELSE b.payer_code        END AS payer_code,
    b.num_lab_procedures,
    b.num_procedures,
    b.num_medications,
    b.number_diagnoses,
    
    b.number_outpatient,
    b.number_emergency,
    b.number_inpatient,
    b.number_outpatient + b.number_emergency + b.number_inpatient          AS total_prior_visits,
    CASE
        WHEN b.number_inpatient = 0 THEN '0'
        WHEN b.number_inpatient = 1 THEN '1'
        WHEN b.number_inpatient = 2 THEN '2'
        ELSE '3+'
    END    AS prior_inpatient_group,

    b.diag_1,
    CASE
        WHEN b.diag_1 = '?' OR b.diag_1 = ''    THEN 'Unknown'
        WHEN b.diag_1 LIKE '250%'     THEN 'Diabetes'
        WHEN b.diag_num BETWEEN 390 AND 459.99 OR FLOOR(b.diag_num) = 785 THEN 'Circulatory'
        WHEN b.diag_num BETWEEN 460 AND 519.99 OR FLOOR(b.diag_num) = 786 THEN 'Respiratory'
        WHEN b.diag_num BETWEEN 520 AND 579.99 OR FLOOR(b.diag_num) = 787 THEN 'Digestive'
        WHEN b.diag_num BETWEEN 800 AND 999.99    THEN 'Injury'
        WHEN b.diag_num BETWEEN 710 AND 739.99   THEN 'Musculoskeletal'
        WHEN b.diag_num BETWEEN 580 AND 629.99 OR FLOOR(b.diag_num) = 788 THEN 'Genitourinary'
        WHEN b.diag_num BETWEEN 140 AND 239.99    THEN 'Neoplasms'
        ELSE 'Other'                           
    END         AS primary_diagnosis_group,

    CASE WHEN b.a1c_result IN ('None', '')    THEN 'Not tested' ELSE b.a1c_result    END AS a1c_result,
    CASE WHEN b.a1c_result IN ('None', '')    THEN 0 ELSE 1 END  AS a1c_tested,
    CASE WHEN b.max_glu_serum IN ('None', '') THEN 'Not tested' ELSE b.max_glu_serum END AS glucose_result,
    b.insulin,
    CASE WHEN b.med_change = 'Ch' THEN 'Yes' ELSE 'No' END  AS med_changed,
    b.diabetes_med    AS on_diabetes_med,

    b.readmitted,
    CASE WHEN b.readmitted = '<30' THEN 1 ELSE 0 END    AS readmit_30
FROM (
    SELECT r.*,
           CASE WHEN r.diag_1 REGEXP '^[0-9.]+$'
                THEN CAST(r.diag_1 AS DECIMAL(6,2)) END AS diag_num
    FROM encounters_raw r
    WHERE r.discharge_disposition_id NOT IN (11, 13, 14, 19, 20, 21)
      AND r.gender <> 'Unknown/Invalid'
) AS b;

ALTER TABLE encounters_clean ADD PRIMARY KEY (encounter_id);

  -- PART C - CHECKS
-- C1. How many rows were removed, and the new 30-day readmission rate
SELECT
    (SELECT COUNT(*) FROM encounters_raw)     AS raw_rows,
    COUNT(*)     AS clean_rows,
    (SELECT COUNT(*) FROM encounters_raw) - COUNT(*)  AS rows_excluded,
    COUNT(DISTINCT patient_nbr)  AS patients,
    ROUND(100.0 * AVG(readmit_30), 1)   AS readmit_30_pct
FROM encounters_clean;

-- C2. No category should be missing or strange
SELECT primary_diagnosis_group, COUNT(*) AS n,
       ROUND(100.0 * AVG(readmit_30), 1) AS readmit_30_pct
FROM encounters_clean
GROUP BY primary_diagnosis_group
ORDER BY n DESC;

-- C3. The window functions worked
SELECT patient_nbr, encounter_id, patient_stay_seq, patient_total_stays, is_first_stay, readmitted
FROM encounters_clean
WHERE patient_total_stays >= 3
ORDER BY patient_nbr, patient_stay_seq
LIMIT 15;
select *
from readmissions.encounters_clean;

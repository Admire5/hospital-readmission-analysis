/* =====================================================================
   Project:  Hospital Readmission Analysis
   Script:   01_create_and_load.sql
   Purpose:  Create the database and raw table, then load the UCI
             "Diabetes 130-US Hospitals (1999-2008)" dataset.
   Source:   https://archive.ics.uci.edu/dataset/296/diabetes+130-us+hospitals+for+years+1999-2008
   Grain:    One row = one inpatient hospital stay (encounter)
   Author:   Siloyiso Admire Tshababa
   ===================================================================== */

-- 1. Creating and selecting the database
CREATE DATABASE IF NOT EXISTS readmissions;
USE readmissions;

-- 2. Raw table: mirrors the CSV exactly. Text columns stay as text so
--    nothing is lost; cleaning happens in the next script.
--    Notes: '?' marks missing values in this dataset.
--           Column "change" is renamed to med_change (since CHANGE is a reserved word).
--           Hyphenated drug-combination names use underscores.
DROP TABLE IF EXISTS encounters_raw;

CREATE TABLE encounters_raw (
    encounter_id              INT PRIMARY KEY,
    patient_nbr               INT,
    race                      VARCHAR(30),
    gender                    VARCHAR(20),
    age                       VARCHAR(10),      -- 10-year bands, e.g. '[70-80)'
    weight                    VARCHAR(15),
    admission_type_id         INT,
    discharge_disposition_id  INT,
    admission_source_id       INT,
    time_in_hospital          INT,              -- length of stay in days (1-14)
    payer_code                VARCHAR(5),
    medical_specialty         VARCHAR(60),
    num_lab_procedures        INT,
    num_procedures            INT,
    num_medications           INT,
    number_outpatient         INT,              -- visits in the year before this stay
    number_emergency          INT,
    number_inpatient          INT,
    diag_1                    VARCHAR(10),      -- ICD-9 codes
    diag_2                    VARCHAR(10),
    diag_3                    VARCHAR(10),
    number_diagnoses          INT,
    max_glu_serum             VARCHAR(10),
    a1c_result                VARCHAR(10),
    metformin                 VARCHAR(10),
    repaglinide               VARCHAR(10),
    nateglinide               VARCHAR(10),
    chlorpropamide            VARCHAR(10),
    glimepiride               VARCHAR(10),
    acetohexamide             VARCHAR(10),
    glipizide                 VARCHAR(10),
    glyburide                 VARCHAR(10),
    tolbutamide               VARCHAR(10),
    pioglitazone              VARCHAR(10),
    rosiglitazone             VARCHAR(10),
    acarbose                  VARCHAR(10),
    miglitol                  VARCHAR(10),
    troglitazone              VARCHAR(10),
    tolazamide                VARCHAR(10),
    examide                   VARCHAR(10),
    citoglipton               VARCHAR(10),
    insulin                   VARCHAR(10),
    glyburide_metformin       VARCHAR(10),
    glipizide_metformin       VARCHAR(10),
    glimepiride_pioglitazone  VARCHAR(10),
    metformin_rosiglitazone   VARCHAR(10),
    metformin_pioglitazone    VARCHAR(10),
    med_change                VARCHAR(5),
    diabetes_med              VARCHAR(5),
    readmitted                VARCHAR(5)        -- '<30', '>30', or 'NO'
);

-- 3. Loading the CSV.
LOAD DATA LOCAL INFILE 'C:/Users/tsilo/Downloads/Portfolio/hospital-readmission-analysis/data/raw/diabetic_data.csv'
INTO TABLE encounters_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(encounter_id, patient_nbr, race, gender, age, weight,
 admission_type_id, discharge_disposition_id, admission_source_id,
 time_in_hospital, payer_code, medical_specialty,
 num_lab_procedures, num_procedures, num_medications,
 number_outpatient, number_emergency, number_inpatient,
 diag_1, diag_2, diag_3, number_diagnoses,
 max_glu_serum, a1c_result,
 metformin, repaglinide, nateglinide, chlorpropamide, glimepiride,
 acetohexamide, glipizide, glyburide, tolbutamide, pioglitazone,
 rosiglitazone, acarbose, miglitol, troglitazone, tolazamide,
 examide, citoglipton, insulin,
 glyburide_metformin, glipizide_metformin, glimepiride_pioglitazone,
 metformin_rosiglitazone, metformin_pioglitazone,
 med_change, diabetes_med, @readmitted)
SET readmitted = TRIM(TRAILING '\r' FROM @readmitted);   -- handles Windows line endings

-- 4. checks
-- Expected: 101,766 rows
SELECT COUNT(*) AS total_encounters FROM encounters_raw;

-- Expected: 3 groups ('NO', '>30', '<30')
SELECT readmitted,
       COUNT(*) AS encounters,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM encounters_raw
GROUP BY readmitted
ORDER BY encounters DESC;
select * from encounters_raw;


USE readmissions;



   -- Q0. overrall readmission rate
SELECT
    COUNT(*) AS stays,
    SUM(readmit_30)   AS readmissions,
    ROUND(100.0 * AVG(readmit_30), 1) AS readmit_30_pct
FROM encounters_clean;

 -- Q1. Primary diagnosis - rate 
SELECT
    primary_diagnosis_group,
    COUNT(*)    AS stays,
    SUM(readmit_30)  AS readmissions,
    ROUND(100.0 * AVG(readmit_30), 1) AS readmit_30_pct,
    ROUND(100.0 * AVG(readmit_30)
          - 100.0 * SUM(SUM(readmit_30)) OVER () / SUM(COUNT(*)) OVER (), 1) AS vs_overall,
    ROUND(100.0 * SUM(readmit_30) / SUM(SUM(readmit_30)) OVER (), 1)  AS share_of_all_pct
FROM encounters_clean
GROUP BY primary_diagnosis_group
HAVING COUNT(*) >= 100
ORDER BY readmit_30_pct DESC;


/* Q2. Age - are older patients readmitted more? ------------------------ */
SELECT
    age_band,
    COUNT(*)     AS stays,
    SUM(readmit_30) AS readmissions,
    ROUND(100.0 * AVG(readmit_30), 1)   AS readmit_30_pct,
    ROUND(100.0 * AVG(readmit_30)
          - 100.0 * SUM(SUM(readmit_30)) OVER () / SUM(COUNT(*)) OVER (), 1) AS vs_overall
FROM encounters_clean
GROUP BY age_band, age_start
HAVING COUNT(*) >= 100
ORDER BY age_start;          


 -- Q3. Prior inpatient visits 
SELECT
    prior_inpatient_group,
    COUNT(*)   AS stays,
    SUM(readmit_30)  AS readmissions,
    ROUND(100.0 * AVG(readmit_30), 1)  AS readmit_30_pct,
    ROUND(100.0 * AVG(readmit_30)
          - 100.0 * SUM(SUM(readmit_30)) OVER () / SUM(COUNT(*)) OVER (), 1) AS vs_overall,
    ROUND(100.0 * SUM(readmit_30) / SUM(SUM(readmit_30)) OVER (), 1)   AS share_of_all_pct
FROM encounters_clean
GROUP BY prior_inpatient_group
ORDER BY prior_inpatient_group;


-- Q4. Discharge destination - where patients go after leaving 
SELECT
    discharge_group,
    COUNT(*)   AS stays,
    SUM(readmit_30)   AS readmissions,
    ROUND(100.0 * AVG(readmit_30), 1)    AS readmit_30_pct,
    ROUND(100.0 * AVG(readmit_30)
          - 100.0 * SUM(SUM(readmit_30)) OVER () / SUM(COUNT(*)) OVER (), 1) AS vs_overall,
    ROUND(100.0 * SUM(readmit_30) / SUM(SUM(readmit_30)) OVER (), 1)        AS share_of_all_pct
FROM encounters_clean
GROUP BY discharge_group
HAVING COUNT(*) >= 100
ORDER BY readmit_30_pct DESC;


-- Q5. Length of stay 
SELECT
    los_group,
    COUNT(*)  AS stays,
    SUM(readmit_30)   AS readmissions,
    ROUND(100.0 * AVG(readmit_30), 1)  AS readmit_30_pct,
    ROUND(100.0 * AVG(readmit_30)
          - 100.0 * SUM(SUM(readmit_30)) OVER () / SUM(COUNT(*)) OVER (), 1) AS vs_overall,
    ROUND(AVG(num_medications), 1)  AS avg_medications
FROM encounters_clean
GROUP BY los_group
ORDER BY MIN(length_of_stay);


 -- Q6. Diabetes care - was the A1C (3-month blood sugar) test done?
SELECT
    a1c_result,
    COUNT(*)   AS stays,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_stays_pct,
    ROUND(100.0 * AVG(readmit_30), 1) AS readmit_30_pct,
    ROUND(100.0 * AVG(readmit_30)
          - 100.0 * SUM(SUM(readmit_30)) OVER () / SUM(COUNT(*)) OVER (), 1) AS vs_overall
FROM encounters_clean
GROUP BY a1c_result
ORDER BY stays DESC;


-- Q7. First stay vs. returning patients 
SELECT
    CASE WHEN is_first_stay = 1 THEN 'First stay in dataset'
         ELSE 'Returning patient' END  AS patient_type,
    COUNT(*)  AS stays,
    ROUND(100.0 * AVG(readmit_30), 1)  AS readmit_30_pct
FROM encounters_clean
GROUP BY patient_type;



   -- Q8. HIGH-RISK SEGMENTS 
WITH segments AS (
    SELECT
        prior_inpatient_group,
        discharge_group,
        COUNT(*)  AS stays,
        SUM(readmit_30) AS readmissions,
        ROUND(100.0 * AVG(readmit_30), 1) AS readmit_30_pct
    FROM encounters_clean
    GROUP BY prior_inpatient_group, discharge_group
    HAVING COUNT(*) >= 200             
)
SELECT
    RANK() OVER (ORDER BY readmit_30_pct DESC) AS risk_rank,
    prior_inpatient_group,
    discharge_group,
    stays,
    readmissions,
    readmit_30_pct
FROM segments
ORDER BY risk_rank
LIMIT 10;

-- ============================================================================
-- Project: Pharmacovigilance Analysis of GLP-1 GI Adverse Events (2020–July 2024)
-- Author: Lydia Simmons
-- Description: Cohort extraction, schema standardisation, deterministic 10-bucket
--              clinical taxonomy mapping, edge-case resolution, and QA audits
--              in Google BigQuery.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: Filter Raw FAERS Snapshot to Study Window & Target Brands
-- ----------------------------------------------------------------------------
CREATE TABLE `glp_1_GI.glp_1_AE_2020_2026` AS (
  SELECT *
  FROM `glp-1-513513.glp_1_GI.glp_1_AE`
  WHERE receive_date BETWEEN '2020-01-01' AND '2026-12-31'
    AND brand_queried IN ('OZEMPIC', 'WEGOVY', 'SAXENDA', 'TRULICITY', 'MOUNJARO')
);

-- Rename table to reflect actual source dataset coverage (2020–July 2024)
ALTER TABLE `glp-1-513513.glp_1_GI.glp_1_AE_2020_2026`
RENAME TO `glp_1_AE_2020_2024`;


-- ----------------------------------------------------------------------------
-- STEP 2: Standardise Age Schema
-- ----------------------------------------------------------------------------
ALTER TABLE `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024`
DROP COLUMN patient_age_unit;

ALTER TABLE `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024`
RENAME COLUMN patient_age TO patient_age_yrs;


-- ----------------------------------------------------------------------------
-- STEP 3: Deterministic 10-Bucket Clinical Taxonomy Mapping
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TABLE `glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped` AS (
  SELECT *,
    CASE
      -- 1. Nausea & Vomiting
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(nausea|vomiting|retching|emesis)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(procedural|gravidarum|faecal)')
        THEN 'Nausea/Vomiting'

      -- 2. Diarrhoea
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(diarrhoea|faecal volume)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(haemorrhagic|viral)')
        THEN 'Diarrhoea'

      -- 3. Constipation
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(constipation)')
        THEN 'Constipation'

      -- 4. Abdominal Pain
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(Abdo|Abdominal|gastrointestinal)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(wall|hernia|plasty)')
        THEN 'Abdominal Pain'

      -- 5. Pancreatitis
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(pancreatitis|pancreatic enzymes|pancreatic disorder|pancreatic failure)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(carcinoma|cyst|mass|autoimmune|alcoholic|neoplasm|enlargement)')
        THEN 'Pancreatitis'

      -- 6. Gastroparesis
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(gastric emptying|gastro motility|gastro hypomotility|dumping|functional gastro)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(mass|ulcer|cancer|viral|gastroenteritis)')
        THEN 'Gastroparesis'

      -- 7. Intestinal Obstruction
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(obstruction|ileus)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(biliary|nasal|gallbladder)')
        THEN 'Intestinal Obstruction'

      -- 8. Biliary Disorders
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(chole|biliary|gallbladder|bile)')
        AND NOT REGEXP_CONTAINS(reaction, r'(?i)(cholecystectomy|operation|immobile)')
        THEN 'Biliary Disorder'

      -- 9. Dehydration
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(dehydration)')
        THEN 'Dehydration'

      -- 10. GERD
      WHEN REGEXP_CONTAINS(reaction, r'(?i)(dyspepsia|GERD)')
        THEN 'GERD'
    END AS Clean_GI_sx
  FROM `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024`
  WHERE REGEXP_CONTAINS(reaction, r'(?i)(nausea|vomiting|retching|emesis|diarrhoea|faecal volume|Constipation|Abdo|Abdominal|gastrointestinal|pancreat|gastric emptying|gastro motility|gastro hypomotility|dumping|functional gastro|obstruction|ileus|chole|biliary|gallbladder|bile|dehydration|dyspepsia|GERD)')
    AND NOT REGEXP_CONTAINS(reaction, r'(?i)(procedural|gravidarum|haemorrhagic|hernia|plasty|carcinoma|cyst|autoimmune|alcoholic|cholecystectomy|operation|immobile|skin|urinary|musculoskeletal|chest|viral|ear|abscess|mass|neoplasm|enlargement|nasal|wall)')
);


-- ----------------------------------------------------------------------------
-- STEP 4: Clinical Edge-Case Resolution
-- ----------------------------------------------------------------------------
UPDATE `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped`
SET Clean_GI_sx = 'Intestinal Obstruction'
WHERE reaction = 'Faecal vomiting';

UPDATE `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped`
SET Clean_GI_sx = 'Pancreatitis'
WHERE Clean_GI_sx IS NULL
  AND reaction IN ('Pancreatic duct dilation', 'Pancreatic atrophy', 'Pancreatolithiasis');

UPDATE `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped`
SET Clean_GI_sx = 'Pancreatitis'
WHERE reaction = 'Pancreatic duct dilatation';


-- ----------------------------------------------------------------------------
-- STEP 5: Data Quality, Multi-Symptom Duplication & Completeness Audits
-- ----------------------------------------------------------------------------
SELECT
  Clean_GI_sx,
  COUNT(*) AS Total_count
FROM `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped`
GROUP BY Clean_GI_sx
ORDER BY Total_count DESC;

SELECT
  COUNT(*) AS Total_rows,
  COUNT(DISTINCT safetyreportid) AS unique_id,
  (COUNT(*) - COUNT(DISTINCT safetyreportid)) AS duplicate_count
FROM `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped`;

SELECT
  -- Total Records
  COUNT(*) AS total_rows,

  -- Patient Sex Missing Data
  COUNT(patient_sex) AS sex_populated_count,
  COUNT(*) - COUNT(patient_sex) AS sex_null_count,
  ROUND((COUNT(patient_sex) / COUNT(*)) * 100, 2) AS sex_percent_complete,

  -- Patient Weight Missing Data
  COUNT(patient_weight_kg) AS weight_populated_count,
  COUNT(*) - COUNT(patient_weight_kg) AS weight_null_count,
  ROUND((COUNT(patient_weight_kg) / COUNT(*)) * 100, 2) AS weight_percent_complete,

  -- Patient Age Missing Data
  COUNT(patient_age_yrs) AS age_populated_count,
  COUNT(*) - COUNT(patient_age_yrs) AS age_null_count,
  ROUND((COUNT(patient_age_yrs) / COUNT(*)) * 100, 2) AS age_percent_complete
FROM `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024_GI_Clean_Mapped`;


-- ----------------------------------------------------------------------------
-- STEP 6: Extract Control Cohort Baseline for Python Denominator Modelling
-- ----------------------------------------------------------------------------
SELECT
  safetyreportid,
  brand_queried,
  serious,
  seriousness_death,
  seriousness_lifethreatening,
  seriousness_hospitalization,
  seriousness_disabling,
  patient_age_yrs,
  patient_sex
FROM `glp-1-513513.glp_1_GI.glp_1_AE_2020_2024`;

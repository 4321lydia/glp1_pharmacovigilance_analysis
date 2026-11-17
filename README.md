# Pharmacovigilance Analysis: Gastrointestinal Adverse Events Across GLP-1 Receptor Agonists (2020–July 2024)

**Interactive Dashboard:** [View Live on Tableau Public](https://public.tableau.com/app/profile/lydia.simmons/viz/GLP-1Project-FDAFAERSDataset-GIAdverseEvents/Dashboard1)

---

## 📋 Executive Summary

This end-to-end pharmacovigilance capstone investigates gastrointestinal (GI) adverse event profiles across four of the most used GLP-1 and dual GIP/GLP-1 receptor agonists—**Ozempic**, **Wegovy**, **Mounjaro**, and **Saxenda**—using real-world post-marketing surveillance data from an FDA Adverse Event Reporting System (FAERS) dataset accessed from Kaggle.

By combining warehouse-scale SQL standardisation in **Google BigQuery**, data analysis in **Python**, and interactive clinical visualisations in **Tableau**, this project separates high-frequency, manageable GI side effects (e.g., nausea, vomiting) from low-frequency, high-acuity structural emergencies (e.g., intestinal obstruction, gastroparesis, pancreatitis).

---

## 🔍 Key Clinical & Analytical Findings

* **Overall GI Adverse Event Rates:**
  * Across **39,485 adverse event reports** among **13,939 unique patients**, **7,447** were GI-related among **4,353 unique patients**.
  * **Ozempic** exhibited the highest rate of GI adverse events at **41.82%**, while **Mounjaro** had the lowest at **25.67%**.

* **Structural vs. Manageable Symptom Concentration:**
  * It is worth noting that **Wegovy** and **Mounjaro** had almost twice as many unique patient reports as **Ozempic** and **Saxenda** and explains why when we look at GI AER’s alone **Wegovy** made up the majority of all GI AER’s when compared to the other brands, most noticeably **Wegovy** accounted for **60%** of all **intestinal obstructions** and **58%** of **Gastroparesis reports**.
  * **Saxenda** consistently represented the smallest share across symptoms, with the exception of **Biliary Disorders**, where both **Saxenda** and **Wegovy** accounted for nearly **40%** each.

* **Demographic Risk Divergences:**
  * **Sex:** **Wegovy** showed no significant reporting difference between males and females, and females reported only slightly more GI adverse events with **Ozempic**. Females reported **4% more** GI adverse events with **Saxenda**, whereas males reported **5% more** with **Mounjaro**—a notable divergence given that total male reports were four times lower than female reports overall.
  * **Age:** GI reporting share remained broadly stable across adult cohorts (`18–29` through `70–79`), with **Ozempic** serving as the sole medication meeting minimum sample-size reliability thresholds (`n > 20`) in the **80+** bracket.
The sole exception was **Mounjaro**, which showed a sharp increase in GI adverse events within the **50–64** and **65–79** age brackets.

* **Multi-Dimensional Symptom Stratification (Brand × Sex × Age):**
  * **Universal Dominance of GI Intolerance:** Across every age bracket and both sexes, **Nausea/Vomiting**, **Diarrhoea**, and **Constipation** consistently accounted for the largest share of GI reports across all four brands—confirming that baseline GI motility intolerance is a class-wide effect rather than isolated to a single demographic group.
  * **Biliary Disorders:** Disproportionately higher in women on **Saxenda**, particularly across ages **18–64**.
  * **Intestinal Obstruction:** Low across most cohorts and brands, with standout concentrations restricted to **Wegovy females aged 65–79** and **Saxenda males aged 50–64**.
  * **Pancreatitis:** Rates were generally higher in males across cohorts, with particular elevations in **Ozempic males** and **Saxenda females**.

* **Clinical Acuity & Hospitalisation:**
  * Serious clinical endpoints cluster heavily around structural complications rather than common GI intolerance across all four brands.

* **Longitudinal Reporting Waves (2020–July 2024):**
  * **2020–2021:** GI adverse event reporting was dominated by **Ozempic**, reflecting established real-world clinical use.
  * **2021–2023:** Reporting surged sharply for **Mounjaro** and **Wegovy** following their FDA approvals, rapid clinical adoption, and expanding patient exposure (alongside structural dataset cut-offs detailed below).
  * It is worth noting that looking at these trends also shows some of the limitations of this data which will be discussed later in this document. 

---

## 🏗️ Data Architecture & Tech Stack

```text
[FDA FAERS GLP-1 Snapshot from Kaggle]
        │
        ▼
[Google BigQuery (SQL)]  ──► Clinical taxonomy mapping (10 clean GI buckets, 0 NULLs)
        │
        ▼
[Google Colab (Python)]  ──► Patient-level de-duplication (.nunique on safetyreportid) & severity aggregation
        │
        ▼
[Tableau Public]         ──► Dual-tab interactive executive & clinical severity dashboards
```

### 1. Data Warehousing & Clinical Mapping (`Google BigQuery`)
* **Study Window (`2020 – July 2024`):** Selected to capture the worldwide surge in GLP-1 agonist adoption, heightened public and social media awareness, and major FDA approvals (**Wegovy** in 2021 and **Mounjaro** in 2022).
* **Brand Cohort Selection:** Isolated four of the most active brands (**Ozempic**, **Wegovy**, **Mounjaro**, **Saxenda**), yielding **7,447** standardised GI adverse event records against a control baseline of **39,485** adverse event reports. **Trulicity** was systematically excluded due to source dataset truncation at 2016.
* **10-Bucket Clinical Taxonomy:** Engineered a deterministic SQL `CASE WHEN` layer to consolidate fragmented and inconsistent symptom reports into **10 standardised GI categories** with **100% mapping coverage (0 NULL values)**, preventing denominator dilution across overlapping terms and separating manageable intolerance from structural emergencies.
* **Clinical Edge-Case Governance:** Applied domain-specific routing rules to prevent misclassification—re-routing acute emergencies such as *faecal vomiting* into **Intestinal Obstruction** so they were not masked as routine GI symptoms, and grouping structural pancreatic findings (*duct dilatation, atrophy, pancreatolithiasis*) into **Pancreatitis** while excluding confounding malignancies (*pancreatic carcinoma*).

### 2. Statistical Processing & Bias Control (`Python / Pandas / NumPy`)
* **Patient-Level De-duplication (`.nunique()`):** Because FAERS reports frequently log multiple concurrent symptoms per patient, all incidence, demographic, and severity metrics were compressed via `.nunique()` on `safetyreportid` to prevent multi-symptom inflation.
* **Boolean Severity Squeezing:** Consolidated serious outcome flags (`serious`, `seriousness_hospitalization`, `seriousness_death`, `seriousness_lifethreatening`, `seriousness_disabiling`) to the unique patient-symptom level using `.max()`.
* **Completeness & Small-Sample Guardrails:**
  * **Patient Weight (`18%` complete):** Excluded entirely to prevent severe clinical selection bias.
  * **Patient Sex (`92%` complete) & Age (`61%` complete):** Retained as active demographic dimensions.
  * **Sample Thresholds:** Paediatric (`<18`) records contained single-digit counts where 1 or 2 GI reports produced artificial 100% incidence spikes (similar noise appeared in select `80+` brand cells). Dropped the Under-18 cohort and enforced a strict **`n > 20`** minimum report threshold across demographic slices.
* **Pre-Aggregated BI Schema:** Exported **7 decoupled flat CSV tables** (`data_exports/`), isolating each analytical dimension so downstream visualisations remain immune to many-to-many join inflation.

### 3. Visual Storytelling (`Tableau Public`)
* **Dashboard Architecture:** Designed a fixed-size (`1300 × 850`), two-tab interactive dashboard suite—**Overview & Demographics** and **Clinical Severity & Reporting Waves**—preventing visual crowding and ensuring crisp readability without vertical scrolling.
* **Visual Consistency & Data Integrity:** Applied a consistent, colourblind-safe brand palette and ingested each pre-aggregated Python CSV as an independent Tableau data source rather than joining tables, eliminating any risk of many-to-many join inflation across differing denominators.
* **Tab 1 — Overview & Demographics:** Executive horizontal bar comparison of overall GI reporting share, a 100% stacked brand contribution chart across all 10 GI symptom categories, a dual-axis gender risk dumbbell chart, and an adult age-cohort multi-line trajectory.
* **Tab 2 — Clinical Severity & Reporting Waves:** Interactive GI symptom demographic matrix stratifying all 10 GI symptoms simultaneously across age, sex, and brand, paired with single-brand clinical severity highlight matrices (mapping hospitalisation, disability, life-threatening, and death rates) and a continuous monthly reporting timeline.

## ⚠️ Methodological Limitations

* **Third-Party Data Provenance:** This analysis utilises a curated snapshot of FDA FAERS records hosted on Kaggle rather than raw quarterly ASCII/XML files pulled directly from the FDA or OpenFDA API. Consequently, the cohort scope is bound by the upstream extract's pre-processing and cut-off dates—accounting for the mid-quarter **July 2024** endpoint and the pre-2016 truncation that necessitated excluding **Trulicity**.
* **Spontaneous Reporting Bias:** FAERS is a passive post-marketing surveillance database; figures represent **reporting proportions among submitted adverse event reports**, not true clinical incidence rates across all prescribed patients.
* **Market Launch Timing:** Staggered FDA approval dates (e.g., **Mounjaro** launching in May 2022) influence cumulative reporting volumes and older-adult cohort representation (`80+`).
* **Partial Final Quarter:** The **July 2024** endpoint reflects the mid-Q3 cut-off of the source FAERS extract rather than a complete calendar quarter, accounting for the apparent tail-off in final-month volume.

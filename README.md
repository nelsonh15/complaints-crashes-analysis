# NYC Illegal Parking Complaints & Motor Vehicle Collisions

A Kimball-style data warehouse that aligns NYC 311 illegal parking complaints with motor vehicle collision records (2020–2025) through shared date and geography dimensions, enabling cross-source analysis of where and when complaint activity and crash activity overlap.

**Course:** CIS 9440 – Data Warehousing (Baruch College) · **Group 18**

[Dashboard](https://datastudio.google.com/reporting/3e7b7dad-7ad7-47a6-bbad-2d87f7410803) · [Dimensional Model](https://dbdiagram.io/d/6990074dbd82f5fce2b31f87)

---

## Overview

NYC publishes 311 illegal parking complaints and reported motor vehicle collisions as separate open datasets. Neither can be joined at the incident level, but both carry date and location. This project loads both into BigQuery, models them as two event-grain fact tables sharing conformed `dim_date` and `dim_geography_bucket` dimensions, and uses that common grain to compare complaint and crash activity by month, borough, and ZIP code.

**Analytics questions**

1. **Cross-source relationship** — Is there a relationship between illegal parking complaints and motor vehicle crashes, and where or when is it strongest? Do the two move together over time? Does seasonality or time of day help explain collision activity?
2. **Hotspots over time** — How did collision hotspots shift from 2020 to 2025? Which ZIP codes are persistently high-risk versus emerging or declining?

**Stakeholders:** NYC DOT, NYPD, community boards, and neighborhood groups focused on street safety and parking enforcement.

**Key metrics:** complaint volume · collision volume · injury-involved collisions · total persons injured · complaint-to-collision ratio · injury collision rate · monthly complaint–collision correlation by borough · seasonal and time-band patterns · ZIP-code hotspot classification.

---

## Architecture

```
NYC Open Data → Socrata API → Cloud Functions / Cloud Scheduler
    → BigQuery raw → dbt staging → dbt dimensions & facts
    → BigQuery analysis tables → Looker Studio
```

| Tool | Purpose |
|---|---|
| NYC Open Data | Source platform for both datasets |
| Socrata API | Programmatic extraction of source records |
| Cloud Functions / Cloud Run | Python-based extract and load |
| Cloud Scheduler | Automated batch ingestion runs |
| BigQuery | Raw, staging, warehouse, and analysis storage |
| dbt | Raw → staging → marts transformation workflow |
| GitHub | Version control for the dbt project |
| Looker Studio | Dashboarding and visualization |

### BigQuery datasets

| Dataset | Purpose | Key tables |
|---|---|---|
| `group18_raw_data` | Raw landing zone | `raw_311_illegal_parking`, `raw_mvc_crashes` |
| `group18_seed` | Lookup data | `nyc_zip_polygons` |
| `group18_stg_data` | Cleaned, standardized staging | `stg_311_illegal_parking`, `stg_mvc_crashes` |
| `group_18_conformed_dimensions` | Shared dimensions | `dim_date`, `dim_geography_bucket` |
| `group_18_illegal_parking_mart` | 311 mart | `fact_311_illegal_parking`, `dim_complaint`, `dim_agency`, `dim_channel`, `dim_status` |
| `group_18_mvc_crashes_mart` | Collisions mart | `fact_mvc_crash`, `dim_crash_time`, `dim_contributing_factor`, `dim_vehicle_type` |

---

## Dimensional Model

Two event-grain fact tables joined to two conformed dimensions plus mart-local dimensions.

<!-- TODO: replace with dbdiagram.io export -->
<img width="911" height="773" alt="image" src="https://github.com/user-attachments/assets/a1e686d1-97eb-4f94-85e8-cff3c2120066" />

**Conformed dimensions**

- `dim_date` — full date, year, month, month name, day of month, day of week, day name, weekend flag, holiday flag.
- `dim_geography_bucket` — ZIP code as the primary bucket, with borough as a roll-up.

**`fact_311_illegal_parking`** — grain: one row per illegal parking complaint. Measure: `complaint_count` (1 per record). Local dimensions:

| Dimension | Describes |
|---|---|
| `dim_complaint` | Complaint type, descriptor, location type |
| `dim_agency` | Responding agency acronym and full name (NYPD) |
| `dim_channel` | Method of submission (phone, online, mobile, other, unknown) |
| `dim_status` | Complaint status (closed, in progress, unspecified) |

**`fact_mvc_crash`** — grain: one row per reported collision. Measures: `crash_count` (1 per record), `number_of_persons_injured`, `number_of_persons_killed`. Local dimensions:

| Dimension | Describes |
|---|---|
| `dim_crash_time` | Hour (0–23) and time band (morning, afternoon, evening, night) |
| `dim_contributing_factor` | Standardized primary contributing factor |
| `dim_vehicle_type` | Standardized vehicle type |

Time is modeled at hour grain rather than minute grain to keep the model practical for analysis.

---

## Data Processing

**Extraction & loading.** Records were pulled from the Socrata API in batches — both sources are large and actively updated — with Cloud Scheduler triggering repeated Cloud Function runs. Filters restricted the load to 2020 onward, keyed on complaint created date (311) and crash date/time (MVC).

**Staging.** dbt staging models assigned consistent data types, standardized text, borough, and ZIP fields, aligned date and time fields, handled missing geography, and added load timestamps for auditability. The raw crash date field carries no time component, so crash time was used separately to derive hour and time band.

**Geography standardization.** Some records were missing ZIP or borough. Using a `nyc_zip_polygons` dbt seed built from Census ZCTA shapefiles, the transformation logic:

1. Matched coordinates to ZIP polygons via point-in-polygon.
2. Fell back to nearest-polygon matching for edge cases near boundaries and bridges.
3. Assigned standardized `UNKNOWN` values where geography could not be reliably derived.

This meaningfully improved ZIP and borough coverage in the shared geography dimension, which cross-source comparison depends on.

<!-- TODO: replace with dbt lineage graph screenshot -->
<img width="1027" height="798" alt="image" src="https://github.com/user-attachments/assets/8cfe65a8-98ba-4fb7-8d8a-1f96baa23200" />

**Analysis tables.** Saved BigQuery tables pre-aggregate complaint and collision metrics by shared date and geography fields, keeping complex SQL out of the BI layer:

`monthly_complaints_vs_collisions` · `geo_complaints_vs_collisions` · `complaint_collision_ratio` · `geo_injury_risk_comparison` · `time_band_collision_analysis` · `total_complaints_collisions_seasonality` · `collision_hotspots` · `injury_risk_comparison` · `monthly_complaint_collision_correlation_by_borough` · `persistent_vs_emerging_collision_hotspots`

---

## Dashboard

Built in Looker Studio on the saved analysis tables, organized into two sections.

**Complaint–Collision Relationship**

<!-- TODO: replace with dashboard screenshot -->
<img width="952" height="1347" alt="image" src="https://github.com/user-attachments/assets/a1d79208-d8a4-4d18-96b2-fc7886083d58" />

| Visualization | What it shows |
|---|---|
| Monthly complaints vs collisions | Whether the two measures move together month to month |
| Monthly correlation by borough | Descriptive borough-level association between the two series |
| Complaint–collision counts by season | Whether the relationship varies across the year |
| Complaints vs collisions by borough | Where both complaint and crash activity run high |
| Collision injury severity by borough | Injury-involved collisions and persons injured by borough |

**Hotspots and Change Over Time**

<!-- TODO: replace with dashboard screenshot -->
<img width="950" height="1303" alt="image" src="https://github.com/user-attachments/assets/e686c5de-eda9-4d43-96e0-c1715593439f" />

| Visualization | What it shows |
|---|---|
| Complaints vs injury severity (ZIP) | Complaint volume against injury severity rate, sized by crash volume |
| Time-band collision analysis | Crash clustering by time of day and weekday/weekend/holiday |
| Collision hotspots by ZIP | Heat map plus yearly trend lines for high-crash ZIP codes |
| Persistent vs emerging hotspots | ZIP codes classified by 2020 → 2025 crash change |
| Collisions high relative to complaints | Treemap of ZIPs where crash risk outpaces complaint activity |

---

## Findings

Complaints and collisions become comparable once aligned on shared time and geography. Some areas show genuine overlap between high complaint volume and high crash volume; others show clear mismatches in both directions — heavy crash activity with few complaints, or heavy complaint activity with few crashes. Borough-level monthly correlations were weak and inconsistent in sign, ranging from slightly positive (Staten Island) to slightly negative (Bronx, Brooklyn).

The hotspot analysis was more decisive. Comparing 2020 against 2025 (2026 would only contribute partial-year data), several Brooklyn ZIP codes remained persistent hotspots even as citywide crash counts declined across every time band.

**Interpretation and limits.** These are descriptive associations, not causal evidence — complaint records and crash records describe different kinds of events, and complaint volume reflects reporting behavior, neighborhood differences in 311 usage, and enforcement patterns as much as street conditions. 311 activity may be a useful supplementary signal for flagging areas worth review, but it is not a proxy for crash risk.

**Future work:** lead-lag testing to see whether complaint spikes precede crash spikes, and finer-grained analysis at the intersection, street-segment, or coordinate level where data quality supports it.

---

## Repository Structure

<!-- TODO: adjust to match the actual repo layout -->
```
.
├── models/
│   ├── staging/          # stg_311_illegal_parking, stg_mvc_crashes
│   ├── conformed/        # dim_date, dim_geography_bucket
│   └── marts/
│       ├── illegal_parking/
│       └── mvc_crashes/
├── seeds/                # nyc_zip_polygons
├── analysis/             # BigQuery analysis table SQL
├── ingestion/            # Cloud Function extract & load
├── docs/images/          # Diagrams and dashboard screenshots
└── dbt_project.yml
```

## Data Sources

- [NYC 311 — Local Law 8 of 2020 Complaints of Illegal Parking](https://data.cityofnewyork.us/City-Government/Local-Law-8-of-2020-Complaints-of-Illegal-Parking-/cwy2-px8b/about_data) — NYC Open Data
- [Motor Vehicle Collisions — Crashes](https://data.cityofnewyork.us/Public-Safety/Motor-Vehicle-Collisions-Crashes/h9gi-nx95/about_data) — NYC Open Data
- [ZIP Code Tabulation Area Shapefiles (2020)](https://www.census.gov/cgi-bin/geo/shapefiles/index.php?year=2020&layergroup=ZIP%20Code%20Tabulation%20Areas) — U.S. Census Bureau

## Team

Daniel Hennessy · Omaru Jawara · Nelson Huang · Allysa Oviedo

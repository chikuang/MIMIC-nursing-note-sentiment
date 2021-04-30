DROP TABLE IF EXISTS FOO CASCADE;

CREATE TABLE FOO AS
WITH tab1 AS (
	SELECT p.subject_id
		, a.hadm_id
		, a.admittime
		, p.dob
		, p.dod
		, p.dod_hosp
		, p.dod_ssn
	    	, p.gender 
		, p.expire_flag
	    , case
	    	when a.admittime = MIN (a.admittime) OVER (PARTITION BY p.subject_id) then 1
	    	when a.admittime != MIN (a.admittime) OVER (PARTITION BY p.subject_id) then 0
	    	end AS first_admission
	    , ROUND( (cast(admittime as date) - cast(dob as date)) / 365.242,2)
		AS first_admit_age
	FROM mimiciii.admissions a
	INNER JOIN mimiciii.patients p
	ON p.subject_id = a.subject_id
	ORDER BY p.subject_id, a.hadm_id
) 

, tab2 AS
(
select subject_id
	, hadm_id
	, icustay_id
	, dbsource
	, first_careunit
	, case
    	when intime = MIN (intime) OVER (PARTITION BY hadm_id) then 1
    	when intime != MIN (intime) OVER (PARTITION BY hadm_id) then 0
    	end AS first_icu
from mimiciii.icustays
order by subject_id, icustay_id
)


, tab3 as
(
	select tab1.*
		, tab2.icustay_id
		, tab2.dbsource
		, tab2.first_careunit
		, tab2.first_icu


	from tab1 
	inner join tab2 
	on tab1.subject_id = tab2.subject_id and tab1.hadm_id = tab2.hadm_id
	where tab1.first_admission = 1 and tab2.first_icu = 1 and tab1.first_admit_age >=15
) 

, tab4 as(
	select tab3.*, 
	case 
		when round((EXTRACT(EPOCH FROM (tab3.dod - tab3.admittime)) / 60 / 60 / 24)) <= 30 then 1
		else 0
		end as thirty_day_mortality
	from tab3
) 

SELECT * from tab4;
\copy (select * from FOO) to '/mnt/d/work/patient_df.csv' HEADER CSV
DROP TABLE IF EXISTS FOO CASCADE;
--\copy (select * from tab4) to 'patient_df.csv' HEADER CSV
--\copy (select * from tab4) to '~/Desktop/patient_df.csv' (FORMAT csv, header)

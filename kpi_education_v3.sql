---internal выводит структуру регионов сотурудников обучения сom и edu 
with 
internal as (
select 
	rgn.id as region_id, rgn.name as region_name, rgn.brand_id, rgn.region_level, rgn.structure_type, rgn.is_blocked, rgn.code as region_code, rgn.status as region_status, rgn.education_region_id,
	usr.id as user_id, usr.last_name || ' ' || usr.first_name as full_name,  usr.email, usr.mobile_number, usr.city
from regions as rgn
	left join user_post_brands as upb on rgn.id = upb.region_id
	left join user_posts as usp on usp.id = upb.user_post_id
	left join users as usr on usp.user_id = usr.id),
---internal_hrr выводит структру с вышестоящими регионами на три уровня выше
internal_hrr as (
select 
distinct inte.brand_id, inte.region_id,  inte.region_level, inte.structure_type, 
inte.user_id, inte.full_name,  inte.email, inte.mobile_number, inte.city, 
(CASE WHEN inte.region_level = 6 then l1.user_id ELSE NULL END) as "n1_user_id", 
(CASE WHEN inte.region_level = 6 THEN l1.full_name ELSE NULL END) as "n1_full_name",
(CASE inte.region_level 
 		WHEN 5 THEN l1.user_id
 		WHEN 6 THEN l2.user_id END) as "n2_user_id", 
 	(CASE inte.region_level 
 		WHEN 5 THEN l1.full_name
 		WHEN 6 THEN l2.full_name END) as "n2_full_name",
 	(CASE inte.region_level 
 		WHEN 4 THEN l1.user_id
 		WHEN 5 THEN l2.user_id
 		WHEN 6 THEN l3.user_id END) as "n3_user_id",
 	(CASE inte.region_level
 		WHEN 4 THEN l1.full_name
 		WHEN 5 THEN l2.full_name
 		WHEN 6 THEN l3.full_name END) as "n3_full_name",
 	(CASE inte.structure_type 
 		WHEN 1 THEN 'COM'
 		WHEN 2 THEN 'EDU' end) AS team,
 	brn.code
from internal as inte
left join region_hierarchies as rgh1 on rgh1.descendant_id = inte.region_id and rgh1.generations = 1
left join internal as l1 on  rgh1.ancestor_id = l1.region_id
left join region_hierarchies as rgh2 on rgh2.descendant_id = inte.region_id and rgh2.generations = 2
left join internal as l2 on  rgh2.ancestor_id = l2.region_id
left join region_hierarchies as rgh3 on rgh3.descendant_id = inte.region_id and rgh3.generations = 3
left join internal as l3 on  rgh3.ancestor_id = l3.region_id
left join brands AS brn ON inte.brand_id = brn.id ),
---------------------------------------
region_srep as (
select 
	brn."name" as brand, brn.code,
	rgn.id as com_ter_id, 
	rgn.name as com_ter_name, 
	rgn.code as com_ter_code, 
	rgn.status as ter_status, 
	rgn1.id as com_reg_id, 
	rgn1.name as com_reg_name, 
	rgn1.code as com_reg_code, 
	rgn1.status as reg_status, 
	rgn2.id as com_mreg_id, 
	rgn2.name as com_mreg_name, 
	rgn2.code as com_mreg_code, 
	rgn2.status as mreg_status, 
	rgn1.education_region_id as edu_reg_id, 
	rgn1_edu."name" as edu_reg_name,
	rgn2_edu.id as edu_mreg_id, 
	rgn2_edu."name" as edu_mreg_name
from regions as rgn
	left join regions as rgn1 on rgn.parent_id = rgn1.id
	left join regions as rgn2 on rgn1.parent_id = rgn2.id
	left join regions as rgn1_edu on rgn1.education_region_id = rgn1_edu.id
	left join regions as rgn2_edu on rgn1_edu.parent_id = rgn2_edu.id
	left join brands as brn on rgn.brand_id = brn.id
where rgn.region_level = 6 and rgn.structure_type = 1),
---------------------------
dataset_users as (
select
	usr.id as user_id,
	usr.last_name || ' ' || usr.first_name as user_name,
	(case when usr.email is not null then 1 else 0 end ) as status_email,
	(case when usr.mobile_number is not null then 1 else 0 end ) as status_mobile,
	(case when usr.last_request_at is not null then 1 else 0 end ) as status_ecad_active_user
from users as usr),
----
dataset_users_salons as (
select 
	sln.id AS salon_id,
	sln."name" ||'. '|| sln.address || '. ' || sln.city as salon_name,   
	sln.city,  
	slt."name" as salon_type,
	rgs.open_date,
	extract(year from rgs.open_date) as open_year,
	--rgu.com_ter_id as com_ter_id,
	(case rgs.status
		when 0 then 'potencial'
		when 1 then 'active'
		when 2 then 'closed' end) as client_status,
	brn.code,
	rgu.com_ter_name as com_ter_name, 
	rgu.com_reg_name as com_reg_name, 
	rgu.com_mreg_name as com_mreg_name, 
	rgu.edu_reg_name as edu_reg_name,
	rgu.edu_mreg_name as edu_mreg_name,
	usr_sln.user_id
from users_salons as usr_sln
	 full join salons as sln on usr_sln.salon_id = sln.id
	 left join salon_types as slt on sln.salon_type_id = slt.id
	 left join regions_salons as rgs on sln.id = rgs.salon_id
	 left join region_srep as rgu on rgs.region_id = rgu.com_ter_id
	 left join brands as brn on rgu.brand = brn.name),
------------------------------------------------------
dataset_educators as (
select distinct 
	sme.educator_id,
	brn.code,
	usr.first_name || ' ' || usr.last_name as educator_name,
	--(case inte.region_level
	--	when 6 then 'technolog' 
	--	when 5 then 'manager'
	--	when 4 then 'regional_technolog'
	--	when 3 then 'education_director'
	--	else 'other' end) as  role_name,
	usr.technolog_salary_category as technolog_salary_category,
	inte.n1_full_name, 
	inte.n2_full_name, 
	inte.n3_full_name
from seminar_events as sme
	left join seminars as smr on sme.seminar_id = smr.id
	left join brands as brn on smr.brand_id = brn.id
	left join users as usr on sme.educator_id = usr.id
	left join internal_hrr as inte on sme.educator_id = inte.user_id and brn.code = inte.code
where sme.educator_id is not null),
---
dataset_training_center as (
select
	trc.id as studio_id,
	0 as salon_id,
	trc.name, 
	trc.address, 
	trc.costs_coefficient,
	(case trc.center_type
			when 0 then 'studio'
			when 1 then 'class' end)  as type_place,
	brn.code, 
	rgn.id as region_id, 
	rgn."name" as edu_reg,
	rgn1."name" as edu_mreg
from training_centers as trc
	left join regions_training_centers as rgn_t on trc.id = rgn_t.training_center_id
	left join regions as rgn on rgn_t.region_id = rgn.id
	left join regions as rgn1 on rgn.parent_id = rgn1.id
	left join brands as brn on rgn.brand_id = brn.id
union all
select distinct
	0,
	sme.salon_id,
	sln."name",
	sln.address,
	1,
	'salon',
	rgu.code,
	rgu.edu_reg_id,
	rgu.edu_reg_name,
	rgu.edu_mreg_name
from seminar_events as sme
	left join seminars as smr on sme.seminar_id = smr.id
	left join brands as brn on smr.brand_id = brn.id
	left join salons as sln on sme.salon_id = sln.id
	left join regions_salons as rgs on sln.id = rgs.salon_id
	left join region_srep as rgu on rgs.region_id = rgu.com_ter_id and brn.code = rgu.code
where sme.salon_id is not null),
----
dataset_seminars as (
select
	(case when brn.code is not null then brn.code else smrkt."name" end) as code,
	---seminar info
	extract(day from sme.started_at::timestamp at time zone 'UTC') as Day, 
	extract(month from sme.started_at::timestamp at time zone 'UTC') as Month, 
	extract(year from sme.started_at::timestamp at time zone 'UTC') as Year,
	to_char(sme.created_at::timestamp at time zone 'UTC','dd.mm.YYYY') as smr_created_date,
	to_char(sme.started_at::timestamp at time zone 'UTC','dd.mm.YYYY') as smr_start_date ,
	to_char(sme.performed_at::timestamp at time zone 'UTC','dd.mm.YYYY') as smr_closed_date ,
	(case  when  sme.performed_at is not Null then 'Closed' else 'NotClosed' end) as seminar_closed,
	sme.id as event_id,
	smr.name as smr_name,
	sme.business_trip as smr_status_trip,
	smrkt."name" as smr_kpi_type, 
	smrsp."name" as smr_specializations,
	smr.duration as smr_duration,
	(case when smr.cost = 0 then 'free' else 'paid' end) as smr_cost_type,
	sme.studio_id,
	sme.salon_id,
	(case when sme.studio_id  is not null then d_trc_std.name else d_trc_sln.name end) as place_name, 
	(case when sme.studio_id  is not null then d_trc_std.address else d_trc_sln.address end) as place_address, 
	(case when sme.studio_id  is not null then d_trc_std.costs_coefficient else d_trc_sln.costs_coefficient end) as costs_coefficient,
	(case when sme.studio_id  is not null then d_trc_std.type_place else d_trc_sln.type_place end) as type_place, 
	(case when sme.studio_id  is not null then d_trc_std.region_id else d_trc_sln.region_id end) as com_reg, 
	(case when sme.studio_id  is not null then d_trc_std.edu_reg else d_trc_sln.edu_reg end) as edu_reg,
	(case when sme.studio_id  is not null then d_trc_std.edu_mreg else d_trc_sln.edu_mreg end) as edu_mreg,
	sme.educator_id,
	d_edu.educator_name,
	d_edu.technolog_salary_category,
	d_edu.n1_full_name, 
	d_edu.n2_full_name, 
	d_edu.n3_full_name
from seminar_events as sme
	left join seminars as smr on sme.seminar_id = smr.id
	left join brands as brn on smr.brand_id = brn.id
	left join seminar_kpis_types as smrkt on smr.seminar_kpis_type_id = smrkt.id
	left join seminar_event_types as smret on sme.seminar_event_type_id = smret.id
	left join seminar_specializations as smrsp on smr.seminar_specialization_id = smrsp.id
	left join dataset_training_center as d_trc_std on sme.studio_id = d_trc_std.studio_id and brn.code = d_trc_std.code
	left join dataset_training_center as d_trc_sln on sme.salon_id = d_trc_sln.salon_id and brn.code = d_trc_sln.code
	left join dataset_educators as d_edu on sme.educator_id = d_edu.educator_id and brn.code = d_edu.code
--where 
--	to_char(sme.started_at::timestamp at time zone 'UTC','YYYY') in ('2017', '2016')
),
dataset_participations as (
select
	prt.seminar_event_id,
	d_usr.*,
	d_sln.*
from participations as prt
	left join seminar_events as sme on prt.seminar_event_id = sme.id
	left join seminars as smr on sme.seminar_id = smr.id
	left join brands as brn on smr.brand_id = brn.id
	left join dataset_users as d_usr on prt.user_id = d_usr.user_id
	left join dataset_users_salons as d_sln on prt.user_id = d_sln.user_id and brn.code = d_sln.code)
--XXXXXXXXXXXXXXXX
select 
	*	
from dataset_seminars as d_smr
	left join dataset_participations as d_prt on d_smr.event_id = d_prt.seminar_event_id 
--where d_smr.educator_id  = 59529 -- and d_smr.event_id = 36165
order by d_smr.event_id
--limit 100

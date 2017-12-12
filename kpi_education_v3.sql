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
---выводит регионы для связки салона и коммерции на уровне представителя. 
region_srep as (
select 
	brn."name" as brand, brn.code,
	rgn.id as com_ter_id, rgn.name as com_ter_name, rgn.code as com_ter_code, rgn.status as ter_status, 
	rgn1.id as com_reg_id, rgn1.name as com_reg_name, rgn1.code as com_reg_code, rgn1.status as reg_status, 
	rgn2.id as com_mreg_id, rgn2.name as com_mreg_name, rgn2.code as com_mreg_code, rgn2.status as mreg_status, 
	rgn1.education_region_id as edu_reg_id, rgn1_edu."name" as edu_reg_name,
	rgn2_edu.id as edu_mreg_id, rgn2_edu."name" as edu_mreg_name
from regions as rgn
	left join regions as rgn1 on rgn.parent_id = rgn1.id
	left join regions as rgn2 on rgn1.parent_id = rgn2.id
	left join regions as rgn1_edu on rgn1.education_region_id = rgn1_edu.id
	left join regions as rgn2_edu on rgn1_edu.parent_id = rgn2_edu.id
	left join brands as brn on rgn.brand_id = brn.id
where rgn.region_level = 6 and rgn.structure_type = 1),
---salon_regions - связка салона с регионом коммерции и обучения
salons_rgn as (

select 
	sln.id AS salon_id,
	rgu.brand, brn.code, 
	sln."name" ||'. '|| sln.address || '. ' || sln.city as salon_name,   
	sln.city,  
	slt."name" as salon_type, 
	rgu.com_ter_id as com_ter_id, rgu.com_ter_name as com_ter_name, 
	rgu.com_reg_id as com_reg_id, rgu.com_reg_name as com_reg_name, 
	rgu.com_mreg_id as com_mreg_id, rgu.com_mreg_name as com_mreg_name, 
	rgu.edu_reg_id as edu_reg_id, rgu.edu_reg_name as edu_reg_name,
	rgu.edu_mreg_id as edu_mreg_id, rgu.edu_mreg_name as edu_mreg_name
from  salons as sln 
	left join salon_types as slt on sln.salon_type_id = slt.id
	left join regions_salons as rgs on sln.id = rgs.salon_id
	left join region_srep as rgu on rgs.region_id = rgu.com_ter_id
	left join brands as brn on rgu.brand = brn.name
order by sln.id
),
---выводит регионы обучения для учебных центров
training_centers_regions as (
select
	trc.id, 
	trc.name, 
	trc.address, 
	trc.costs_coefficient,
	trc.center_type,
	brn.code, 
	rgn.id as region_id, 
	rgn."name" as edu_reg,
	rgn1."name" as edu_mreg
from training_centers as trc
	left join regions_training_centers as rgn_t on trc.id = rgn_t.training_center_id
	left join regions as rgn on rgn_t.region_id = rgn.id
	left join regions as rgn1 on rgn.parent_id = rgn1.id
	left join brands as brn on rgn.brand_id = brn.id),
--- подсчет участников семинара
participations_count as(
select 
	prt.seminar_event_id, count(distinct prt.user_id) as user_count
from participations as prt
group by prt.seminar_event_id),
---салоны участников
participations_nobrand_salons as (
	select distinct  usr_sln.salon_id,  sln_user.com_mreg_name 
	from participations as prt
		left join seminar_events as sme on sme.id = prt.seminar_event_id
		left join seminars as smr on sme.seminar_id = smr.id
		left join users_salons as usr_sln on prt.user_id = usr_sln.user_id
		left join brands as brn on smr.brand_id = brn.id
		left join salons_rgn as sln_user on usr_sln.salon_id = sln_user.salon_id and brn."name" <> sln_user.brand
	where sln_user.com_mreg_name is not null and sln_user.com_mreg_name not like 'МегаТест'),
--
payments_usr as (
select 
	ord.item_id, ord.base_cost, ord.cost, pmt.amount
from orders as ord
left join payments as pmt on ord.id = pmt.order_id
where ord.item_type = 'Participation')
---
---XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
---
select
	(case when brn.code is not null then brn.code else smrkt."name" end) as brand,
	---seminar info
	extract(day from sme.started_at::timestamp at time zone 'UTC') as Day, 
	extract(month from sme.started_at::timestamp at time zone 'UTC') as Month, 
	extract(year from sme.started_at::timestamp at time zone 'UTC') as Year,
	to_char(sme.created_at::timestamp at time zone 'UTC','dd.mm.YYYY') as smr_created_date,
	to_char(sme.started_at::timestamp at time zone 'UTC','dd.mm.YYYY') as smr_start_date ,
	to_char(sme.performed_at::timestamp at time zone 'UTC','dd.mm.YYYY') as smr_closed_date ,
	(case  when  sme.performed_at is not Null then 'Closed' else 'NotClosed' end) as seminar_closed,
	--(case when  (row_number() over (Partition by sme.id order by prt.id))  = '1' then sme.id Else Null end) as uniq_smr_id,
	sme.id as smr_id,
	smr.name as smr_name,
	sme.business_trip as smr_status_trip,
	smrkt."name" as smr_kpi_type, 
	smrsp."name" as smr_specializations,
	--(case when  (row_number() over (Partition by sme.id order by prt.id))  = '1' then smr.duration Else Null end) as smr_duration,
	(case when smr.cost = 0 then 'free' else 'paid' end) as smr_cost_type,
	--(case when (row_number() over (Partition by sme.id))  = '1' then
	--	Sum(case when smr.cost <> 0 then  (case when dsc.percent_value is not null then (smr.cost *  (dsc.percent_value::int / 10)) /10 else smr.cost * 1 end) end)
	--		over (Partition by sme.id) else null end) as smr_paid,
	--(case when row_number() over (partition by sme.id) = 1 then count(prtnm.id) over (partition by sme.id)	end) as users_count,
	--(case when count(prtnm.id) over (partition by sme.id) > 0 then 'attend' else 'no_users' end) as status_seminar_users,
	--(case when row_number() over (partition by sme.id) = 1 then count(usr_sln.salon_id) over (partition by sme.id) end) as clients_count,
	---place info
	(case when sme.studio_id is not null then 
		(case trc_r.center_type
			when 0 then 'studio'
			when 1 then 'class' end)
			else 'salon' end) as type_place,
	(case when sme.studio_id is not null then  sme.studio_id else sme.salon_id end) as id_place,
	(case when sme.studio_id is not null then  trc_r."name" || ' ' || trc_r.address
		else 'in_salon: ' || sln.salon_name  end) as name_place,
	(case when sme.studio_id is not null then trc_r.edu_reg else sln.com_reg_name end) as place_reg,
	(case when sme.studio_id is not null then trc_r.edu_mreg else sln.com_mreg_name end) as place_mreg, 
	---educater info
	sme.educator_id as educater_id,
	edu.first_name || ' ' || edu.last_name as educator_name,
	(case inte.region_level
		when 6 then 'technolog' 
		when 5 then 'manager'
		when 4 then 'regional_technolog'
		when 3 then 'education_director'
		else 'other' end) as  role_name,
	edu.technolog_salary_category as technolog_salary_category,
	inte.n1_full_name, inte.n2_full_name, inte.n3_full_name,
	---kpi
	(case when smrkt."name" = 'Brand Day' then 'Brand Day' else
		(case when smrkt."name" = 'Consultations' then 'Consultations' else
			(case when smrkt."name" <> 'Consultations' and sme.studio_id is null and sme.salon_id is not Null  then 'training in salon' else
				(case when sme.studio_id is not null then 'studios seminars' else 'Other' end) end) end) end),
	---participations info
	--count(prtnm.id) over (partition by sme.id order by prt.id) as user_num,
	--(case when  (row_number() over (Partition by Concat(sme.id, '|' ,prt.user_id)))  = '1' then prt.user_id end) as user_id, 
	prtnm.last_name || ' ' || prtnm.first_name as master_name,
	(case when prtnm.email is not null then 1 else 0 end ) as status_email,
	(case when prtnm.email is not null then prtnm.id else Null end ) as unuq_hd_with_email,
	(case when prtnm.mobile_number is not null then 1 else 0 end ) as status_mobile,
	(case when prtnm.last_request_at is not null then 1 else 0 end ) as status_ecad_active_user,
	'' as type_master,
	(case when smr.cost <> 0 then  (case when dsc.percent_value is not null then (smr.cost *  (dsc.percent_value::int / 10)) /10 else smr.cost * 1 end) end) as user_must_pay,
	pmt_prt.amount as payment,
	dsc.percent_value as discount,
	---participations salons info
	sln_user.salon_id as uniq_educated_salon,
	sme.id || '|' || sln_user.salon_id as educated_salon,
	sln_user.salon_name as salon,
	(case when sln_user.com_mreg_name is not null then sln_user.com_mreg_name else 
		(case when pns.com_mreg_name is not null then pns.com_mreg_name  
					end) 
						end)as com_mreg, 
	sln_user.com_reg_name as com_reg, 
	sln_user.com_ter_name as com_ter,
	(case when sln_user.com_mreg_name is null and usr_sln.salon_id is not null then 'other_brand' else 
		(case when sln_user.com_mreg_name is null and usr_sln.salon_id is null then 'not_salon' else 'brand_salon' end ) end) as salon_brand_status,
	sln.salon_type,	
	'' as booking_user_name, '' as role, '' as prebooking_day, '' as status_booking
from seminar_events as sme
	left join seminars as smr on sme.seminar_id = smr.id
	left join brands as brn on smr.brand_id = brn.id
	left join seminar_kpis_types as smrkt on smr.seminar_kpis_type_id = smrkt.id
	left join seminar_event_types as smret on sme.seminar_event_type_id = smret.id
	left join seminar_specializations as smrsp on smr.seminar_specialization_id = smrsp.id
	---
	left join users as edu on sme.educator_id = edu.id
	---
	left join training_centers_regions as trc_r on sme.studio_id = trc_r.id and brn.code = trc_r.code
	left join salons_rgn as sln on sme.salon_id = sln.salon_id and brn."name" = sln.brand
	--
	left join participations as prt on sme.id = prt.seminar_event_id
	left join users as prtnm on prt.user_id = prtnm.id
	--left join discounts as dsc on prt.discount_id = dsc.id 
	--left join payments_usr as pmt_prt on prt.id = pmt_prt.item_id
where
	-- sme.id = 293485
	to_char(sme.started_at::timestamp at time zone 'UTC','YYYY') in ('2017', '2016') --and  
	--to_char(sme.started_at::timestamp at time zone 'UTC','MM') in ('07') and 
	--and brn."name" is not null and 
	-- brn.code = 'KR' -- and 
  	--inte.n1_full_name is not null and
	--inte.n3_full_name is not null and 
	-- sme.studio_id is null
	--and sln_user.com_mreg_name is null 
	--and usr_sln.salon_id in (3023)
order by sme.started_at, sme.id, prt.id
--limit 100



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
--
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
	usr.id as user_id,
	usr.last_name || ' ' || usr.first_name as master,
	(case when usr.email is not null then 1 else 0 end ) as status_email,
	(case when usr.mobile_number is not null then 1 else 0 end ) as status_mobile,
	(case when usr.last_request_at is not null then 1 else 0 end ) as status_ecad_active_user
from users_salons as usr_sln
	 full join salons as sln on usr_sln.salon_id = sln.id
	 left join salon_types as slt on sln.salon_type_id = slt.id
	 left join regions_salons as rgs on sln.id = rgs.salon_id
	 left join region_srep as rgu on rgs.region_id = rgu.com_ter_id
	 left join brands as brn on rgu.brand = brn.name
	 full join users as usr on usr_sln.user_id = usr.id),
---
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
	left join salons as sln on sme.salon_id = sln.id
	left join regions_salons as rgs on sln.id = rgs.salon_id
	left join region_srep as rgu on rgs.region_id = rgu.com_ter_id
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
	sme.educator_id,
	sme.studio_id,
	sme.salon_id,
	(case when sme.studio_id  is not null then d_trc_std.name else d_trc_sln.name end) as place_name, 
	(case when sme.studio_id  is not null then d_trc_std.address else d_trc_sln.address end) as place_address, 
	(case when sme.studio_id  is not null then d_trc_std.costs_coefficient else d_trc_sln.costs_coefficient end) as costs_coefficient,
	(case when sme.studio_id  is not null then d_trc_std.type_place else d_trc_sln.type_place end) as type_place, 
	(case when sme.studio_id  is not null then d_trc_std.region_id else d_trc_sln.region_id end) as com_reg, 
	(case when sme.studio_id  is not null then d_trc_std.edu_reg else d_trc_sln.edu_reg end) as edu_reg,
	(case when sme.studio_id  is not null then d_trc_std.edu_mreg else d_trc_sln.edu_mreg end) as edu_mreg	,
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
	left join dataset_training_center as d_trc_std on sme.studio_id = d_trc_std.studio_id
	left join dataset_training_center as d_trc_sln on sme.salon_id = d_trc_sln.salon_id
	left join dataset_educators as d_edu on sme.educator_id = d_edu.educator_id and brn.code = d_edu.code
--where 
--	to_char(sme.started_at::timestamp at time zone 'UTC','YYYY') in ('2017', '2016')
),
dataset_participations as (
select
	prt.seminar_event_id, 
	d_usr.*
from participations as prt 
	left join dataset_users_salons as d_usr on prt.user_id = d_usr.user_id)
--XXXXXXXXXXXXXXXX
select 
	*	
from dataset_seminars as d_smr
	left join dataset_participations as d_prt on d_smr.event_id = d_prt.seminar_event_id 
--where d_smr.educator_id  = 59529
--order by d_smr.smr_start_date
--limit 100

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
	LEFT JOIN brands AS brn ON inte.brand_id = brn.id ),
---
---выводит регионы для связки салона и коммерции на уровне представителя. 
region_srep as (
select 
	brd."name" as brand, 
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
	left join brands as brd on rgn.brand_id = brd.id
where rgn.region_level = 6 and rgn.structure_type = 1),
---salon_regions - связка салона с регионом коммерции и обучения
salons_rgn as (
select 
	sln.id AS salon_id,
	rgu.brand, sln."name" ||'. '|| sln.address || '. ' || sln.city as salon_name,   sln.city,  slt."name" as salon_type, 
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
order by sln.id),
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
	(case when  (row_number() over (Partition by sme.id order by prt.id))  = '1' then sme.id Else Null end) as uniq_smr_id,
	sme.id as smr_id,
	smr.name as smr_name,
	sme.business_trip as smr_status_trip,
	smrkt."name" as smr_kpi_type, 
	smrsp."name" as smr_specializations,
	(case when  (row_number() over (Partition by sme.id order by prt.id))  = '1' then smr.duration Else Null end) as smr_duration,
	(case when smr.cost = 0 then 'free' else 'paid' end) as smr_cost_type,
	(case when (row_number() over (Partition by sme.id))  = '1' then
		Sum(case when smr.cost <> 0 then  (case when dsc.percent_value is not null then (smr.cost *  (dsc.percent_value::int / 10)) /10 else smr.cost * 1 end) end)
			over (Partition by sme.id) else null end) as smr_paid,
	(case when row_number() over (partition by sme.id) = 1 then count(prtnm.id) over (partition by sme.id)	end) as users_count,
	(case when count(prtnm.id) over (partition by sme.id) > 0 then 'attend' else 'no_users' end) as status_seminar_users,
	(case when row_number() over (partition by sme.id) = 1 then count(usr_sln.salon_id) over (partition by sme.id) end) as clients_count,
	---place info
	(case when sme.studio_id is not null then 
		(case trc.center_type
			when 0 then 'studio'
			when 1 then 'class' end)
			else 'salon' end) as type_place,
	(case when sme.studio_id is not null then  sme.studio_id else sme.salon_id end) as id_place,
	(case when sme.studio_id is not null then  trc."name" || ' ' || trc.address
		else 'in_salon: ' || sln.salon_name  end) as name_place,
	sln.com_mreg_name as place_mreg, 
	sln.com_reg_name as place_reg, 
	sln.com_ter_name as place_ter,
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
	count(prtnm.id) over (partition by sme.id order by prt.id) as user_num,
	(case when  (row_number() over (Partition by Concat(sme.id, '|' ,prt.user_id)))  = '1' then prt.user_id end) as user_id, 
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
		(case when pns.com_mreg_name is not null then pns.com_mreg_name else 
			(case when rgn_trc.name is not null then rgn_trc.name else sln.edu_mreg_name 
				end) 
					end) 
						end)as com_mreg, 
	sln_user.com_reg_name as com_reg, 
	sln_user.com_ter_name as com_ter,
	(case when sln_user.com_mreg_name is null and usr_sln.salon_id is not null then 'other_brand' else 
		(case when sln_user.com_mreg_name is null and usr_sln.salon_id is null then 'not_salon' else 'brand_salon' end ) end) as salon_brand_status,
	sln.salon_type,	
	(case when sln.edu_mreg_name is not null then sln.edu_mreg_name else 
		(case when rgn_trc.name is not null then rgn_trc.name else
			(case when sln_user.com_mreg_name is not null then sln_user.com_mreg_name else pns.com_mreg_name 
				end)  
					end) 
						end) as edu_mreg_name,
	sln.edu_reg_name, 
	'' as booking_user_name, '' as role, '' as prebooking_day, '' as status_booking
from seminar_events as sme
	left join seminars as smr on sme.seminar_id = smr.id
	left join seminar_kpis_types as smrkt on smr.seminar_kpis_type_id = smrkt.id
	left join training_centers as trc on sme.studio_id = trc.id
	left join seminar_event_types as smret on sme.seminar_event_type_id = smret.id 
	left join brands as brn on smr.brand_id = brn.id
	left join salons_rgn as sln on sme.salon_id = sln.salon_id and brn."name" = sln.brand
	left join users as edu on sme.educator_id = edu.id
	left join participations as prt on sme.id = prt.seminar_event_id
	left join users as prtnm on prt.user_id = prtnm.id
	left join users_salons as usr_sln on prtnm.id = usr_sln.user_id
	left join salons_rgn as sln_user on usr_sln.salon_id = sln_user.salon_id and brn."name" = sln_user.brand
	left join participations_nobrand_salons as pns on usr_sln.salon_id = pns.salon_id 
	left join discounts dsc on prt.discount_id = dsc.id 
	left join regions as rgn_trc on trc.region_id =rgn_trc.id
	left join internal_hrr as inte on sme.educator_id = inte.user_id
	left join payments_usr as pmt_prt on prt.id = pmt_prt.item_id
	left join seminar_specializations as smrsp on smr.seminar_specialization_id = smrsp.id
where
	-- sme.id = 293485
	--to_char(sme.started_at::timestamp at time zone 'UTC','YYYY') in ('2017', '2016') and  
	--to_char(sme.started_at::timestamp at time zone 'UTC','MM') in ('07') and 
	--and brn."name" is not null and 
	 brn.code = 'KR' -- and 
  	--inte.n1_full_name is not null and
	--inte.n3_full_name is not null and 
	-- sme.studio_id is null
	--and sln_user.com_mreg_name is null 
	--and usr_sln.salon_id in (3023)
order by sme.started_at, sme.id, prt.id
LIMIT 1000



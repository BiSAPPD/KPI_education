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
	distinct inte.brand_id, inte.region_level, inte.structure_type, 
	inte.user_id, inte.full_name,  inte.email, inte.mobile_number, inte.city, 
	l5.user_id as "n1_user_id", l5.full_name as "n1_full_name", 
	l4.user_id as "n2_user_id", l4.full_name as "n2_full_name", 
	l3.full_name as "n3_full_name"
from internal as inte
	left join region_hierarchies as rgh5 on rgh5.descendant_id = inte.region_id and rgh5.generations = 1
	left join internal as l5 on  rgh5.ancestor_id = l5.region_id
	left join region_hierarchies as rgh4 on rgh4.descendant_id = inte.region_id and rgh4.generations = 2
	left join internal as l4 on  rgh4.ancestor_id = l4.region_id
	left join region_hierarchies as rgh3 on rgh3.descendant_id = inte.region_id and rgh3.generations = 3
	left join internal as l3 on  rgh3.ancestor_id = l3.region_id),
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
	sln.id, rgu.brand, sln."name" ||'. '|| sln.address || '. ' || sln.city as salon_name,   sln.city,  slt."name" as salon_type, 
	rgu.com_ter_id as com_ter_id, rgu.com_ter_name as com_ter_name, 
	rgu.com_reg_id as com_reg_id, rgu.com_reg_name as com_reg_name, 
	rgu.com_mreg_id as com_mreg_id, rgu.com_mreg_name as com_mreg_name, 
	rgu.edu_reg_id as edu_reg_id, rgu.edu_reg_name as edu_reg_name,
	rgu.edu_mreg_id as edu_mreg_id, rgu.edu_mreg_name as edu_mreg_name
from  salons as sln 
	left join salon_types as slt on sln.salon_type_id = slt.id
	left join regions_salons as rgs on sln.id = rgs.salon_id
	left join region_srep as rgu on rgs.region_id = rgu.com_ter_id
order by sln.id),
---
participations_count as(
select 
	prt.seminar_event_id, count(distinct prt.user_id) as user_count
from participations as prt
group by prt.seminar_event_id),
---
payments_usr as (
select 
	ord.item_id, ord.base_cost, ord.cost, pmt.amount
from orders as ord
left join payments as pmt on ord.id = pmt.order_id
where ord.item_type = 'Participation')
---
select
	brn.pretty_name,
	(case when  (row_number() over (Partition by sme.id order by prt.id))  = '1' then sme.id Else Null end) as smr_id, 
	sme.seminar_event_type_id as smr_type_id, 
	smr.name as smr_name,
	sme.business_trip as smr_status_trip,
	smrkt."name" as smr_kpi_type, 
	(case when  (row_number() over (Partition by sme.id order by prt.id))  = '1' then smr.duration Else Null end) as smr_duration,
	inte.n1_full_name, inte.n2_full_name, inte.n3_full_name,
	(case when  (row_number() over (Partition by sme.id))  = '1' then
		(case when smr.name like '%CRAFT%' or  smr.name like '%твор%'  or smr.name like '%МП%' then '1' else 0 end)
	 		end) as is_craft,
	 (case when  (row_number() over (Partition by sme.id))  = '1' then
		(case when smrkt."name" like 'Brand Day' then '1' else 0 end)
	 		end) as is_Day_MX,
	 (case when (row_number() over (Partition by sme.id))  = '1' then 
	    (case when smr.cost = 0 then 'free' else 'paid' end) 
			end)  as smr_type,
	(case when (row_number() over (Partition by sme.id))  = '1' then
		Sum(case when smr.cost <> 0 then  (case when dsc.percent_value is not null then (smr.cost *  (dsc.percent_value::int / 10)) /10 else smr.cost * 1 end) end)
			over (Partition by sme.id) else null end)
	as smr_paid,
	(case when row_number() over (partition by sme.id) = 1 then 
	    count(prtnm.id) over (partition by sme.id) 
	end) as users_count,
	(case when row_number() over (partition by sme.id) = 1 then
		count(usr_sln.salon_id) over (partition by smr.id) 
	end) as clients_count,
	(case when sme.studio_id is not null then 'studio' else 'in_salon' end) as type_place,
	(case when sme.studio_id is not null then  trc."name" || ' ' || trc.address
		else 'in_salon: ' || sln.salon_name  end) as name_place,
	sme.educator_id as educater_id,
	edu.first_name || ' ' || edu.last_name as educator_name,
	(case inte.region_level
		when 6 then 'technolog' 
		when 5 then 'manager'
		when 4 then 'reg_technolog'
		end) as  role_name,
	(case when  (row_number() over (Partition by sme.id))  = '1' then extract(day from sme.started_at::timestamp at time zone 'UTC') end) as Day, 
	(case when  (row_number() over (Partition by sme.id))  = '1' then extract(month from sme.started_at::timestamp at time zone 'UTC') end)as Month, 
	(case when  (row_number() over (Partition by sme.id))  = '1' then extract(year from sme.started_at::timestamp at time zone 'UTC') end) as Year,
	(case when  (row_number() over (Partition by sme.id))  = '1' then to_char(sme.created_at::timestamp at time zone 'UTC','dd.mm.YYYY') end) as smr_createdDate,
	(case when  (row_number() over (Partition by sme.id))  = '1' then to_char(sme.started_at::timestamp at time zone 'UTC','dd.mm.YYYY') end) as smr_startDate ,
	(case when  (row_number() over (Partition by sme.id))  = '1' then to_char(sme.performed_at::timestamp at time zone 'UTC','dd.mm.YYYY') end) as smr_closedDate ,
	(case when  (row_number() over (Partition by sme.id))  = '1' then (case  when  sme.performed_at is not Null then '1' else 0 end) end) as seminar_closed,
	count(prtnm.id) over (partition by sme.id order by prt.id) as user_num, 
	(case when  (row_number() over (Partition by Concat(sme.id, '|' ,prt.user_id)))  = '1' then prt.user_id end) as user_id, 
	prtnm.last_name || ' ' || prtnm.first_name as master_name,
	(case when prtnm.email is not null then 1 else 0 end ) as status_email,
	(case when prtnm.mobile_number is not null then 1 else 0 end ) as status_mobile,
	(case when prtnm.last_request_at is not null then 1 else 0 end ) as status_ecad_active_user,
	'' as type_master,
	(case when smr.cost <> 0 then  (case when dsc.percent_value is not null then (smr.cost *  (dsc.percent_value::int / 10)) /10 else smr.cost * 1 end) end) as user_must_pay,
	pmt_prt.amount as payment,
	dsc.percent_value as discount,
	usr_sln.salon_id as salon_id,
	sme.id || '|' || usr_sln.salon_id as educated_salon,
	sln_user.salon_name as salon,
	sln.com_mreg_name, sln.com_reg_name, sln.com_ter_name,
	sln.com_ter_name, sln.com_reg_name, sln.com_mreg_name, sln.salon_type,
	sln.edu_reg_name, sln.edu_mreg_name,
	'' as booking_user_name, '' as role, '' as prebooking_day, '' as status_booking
from seminar_events as sme
	left join seminars as smr on sme.seminar_id = smr.id
	left join seminar_kpis_types as smrkt on smr.seminar_kpis_type_id = smrkt.id
	left join training_centers as trc on sme.studio_id = trc.id
	left join seminar_event_types as smret on sme.seminar_event_type_id = smret.id 
	left join brands as brn on smr.brand_id = brn.id
	left join salons_rgn as sln on sme.salon_id = sln.id and brn."name" = sln.brand
	left join users as edu on sme.educator_id = edu.id
	left join participations as prt on sme.id = prt.seminar_event_id
	left join users as prtnm on prt.user_id = prtnm.id
	left join users_salons as usr_sln on prtnm.id = usr_sln.user_id
	left join salons_rgn as sln_user on usr_sln.salon_id = sln_user.id and brn."name" = sln_user.brand
	left join discounts dsc on prt.discount_id = dsc.id 
	left join regions as rgn_edu on sme.region_id =rgn_edu.id
	left join internal_hrr as inte on sme.educator_id = inte.user_id
	left join payments_usr as pmt_prt on prt.id = pmt_prt.item_id
where 
	to_char(sme.started_at::timestamp at time zone 'UTC','YYYY') in ('2017') and  
	--to_char(sme.started_at::timestamp at time zone 'UTC','MM') in ('07') and 
	brn."name" is not null and 
	brn.pretty_name = 'Matrix' and 
  	--inte.n1_full_name is not null and 
	--inte.n3_full_name is not null and 
	sme.studio_id is null
order by sme.started_at, sme.id, prt.id
limit 100
---end


with a as (select admin_coach_events.id as id, users.id as coach_id, 
admin_coach_seminars."name" as sem_name, 
admin_coach_events.started_date,
users.first_name || ' ' || users.last_name as coach_last_name, 
admin_coach_events.educator_id
from admin_coach_events
left join admin_coach_seminars
on admin_coach_events.admin_coach_seminar_id = admin_coach_seminars.id
left join users
on admin_coach_events.user_id = users.id)
select a.*, 
users.first_name || ' ' || users.last_name as stolbew, users.last_name as educator_last_name
from a
left join users
on a.educator_id = users.id


select *
from users as usr
left join users_salons as usrs on usr.id = usrs.user_id
left join user_posts as usp on usr.id = usp.user_id
left join posts as pst on usp.post_id = pst.id
where pst.role_id = 4 and usp.salon_id is not null
order by usr.id
limit 100

select *
from seminars as smr 
	left join seminar_kpis_types as smrkt on smr.seminar_kpis_type_id = smrkt.id
where smrkt.id is  null

WITH programs as (

select *
from dblink('dbname=academie user=readonly password=', 
	'select spcr.status as status, spc.id as id, spc.name as name, spc.brand_id as brand_id, 
	(Case spc.brand_id
			When 1 then ''loreal'' 
			When 5 then ''matrix''
			When 6 then ''luxe''
			When 7 then ''redken''
			When 3 then ''essie''
		        End) as brand,
	spcr.salon_id as salon_id

	from special_program_club_records as spcr
	left join special_program_clubs as spc ON spcr.club_id = spc.id') AS spp (status  text, id integer, name_prog text, brand_id  integer, brand text, salon_id  integer )

where spp.brand_id = 

(Case current_database()
                When 'loreal' then 1
                When 'matrix' then 5
                When 'luxe' then 6
                When 'redken' then 7
                When 'essie' then 3
               End)


)

, club_py_clb as (
select *
from programs 
where name_prog like '%2016%' and 
	(Case when name_prog like '%Expert%' then 1 else
		(case when name_prog like '%МБК%' then 1  else
			(case when name_prog like '%Селективное Соглашение%' then 1 else 0 end ) end) end) = 1
)
, club_ty_clb as (
select * 
from programs 
where name_prog like '%2017%' and 
	(Case when name_prog like '%Expert%' then 1 else
		(case when name_prog like '%МБК%' then 1  else
			(case when name_prog like '%Селективное Соглашение%' then 1 else 0 end ) end) end) = 1
)

, club_py_emt as (
select *
from programs 
where name_prog like '%2016%' and name_prog like '%Emotion%'
)
, club_ty_emt as (
select *
from programs 
where name_prog like '%2017%' and name_prog like '%Emotion%'
)

Select 
smr.id as smr_id,
concat(smr.id, '_', smt.name) as uniq_event,
smt.id as smr_type, 
smt.name, 
smt.kpis_type, 

(case when  (row_number() over (Partition by smr.id))  = '1' then smt.duration Else Null end) as duration,
(case  (row_number() over (Partition by smr.id))  
when  '1' then (count(usr.id) over (Partition by smr.id))
when '0' then 0
else Null  end) as users_count,
(case when smt.is_free is true then 'free' else 'paid' end) as is_free,


pmt.ykassa,


extract(year from smr.started_at) as cd_year,
extract(month from smr.started_at)  as cd_month,
extract(day from smr.started_at)  as cd_day,
smr.started_at as cd_data_smr_start,
smr.closed_at as cd_data_smr_closed,
smr.created_at as cd_data_smr_creat, 


(Case when smr.trip is true or false then
    (case when smr.trip = 't' then 1 else 0 end) 
else
    (case when smr.business_trip = 't' then '1' else 0 end)
end) as trip,

(case when smr.salon_id is not null or smr.salon_id not in ( '0' )then 'SALON' else
(case when smr.studio_id  is not null and (Select std.studio_type from studios as std where smr.studio_id = std.id) = 'classroom' then 'CLASSROOM' else 
(case when smr.studio_id  is not null and (Select std.studio_type from studios as std where smr.studio_id = std.id) = 'studio' then 'STUDIO' else  'NOT_TYPE' 
end) end) end) as type_place,

(case when smr.salon_id is not null or smr.salon_id not in ( '0' )then Concat('inSalon_', slnPlace.name,'. ',slnPlace.address) else
(case when smr.studio_id  is not null or smr.studio_id not in ( '0' ) then concat(std.name, '. ',std.address)  else '' end)
 end) as name_place,

(case when smr.closed_at is not null then 'CLOSED' else 'NOT_CLOSED' end) as seminar_closed,

(case when smr.partimer_id is not null then smr.partimer_id else
(case when smr.technolog_id  is not null then smr.technolog_id else
(case when smr.partner_id  is not null then smr.partner_id end) end) end) as educater_id,

(case when smr.partimer_id is not null then smr.partimer_full_name else
(case when smr.technolog_id  is not null then smr.technolog_full_name else 
(case when smr.partner_id  is not null then smr.partner_full_name else 'Not_found' end) end) end) as educater,

(case when smr.technolog_id is not null then (select usr_edu.role from users as usr_edu where smr.technolog_id = usr_edu.id) else
(case when smr.partimer_id is not null then (select usr_edu.role from users as usr_edu where smr.partimer_id = usr_edu.id) else
(case when smr.partner_id is not null then (select usr_edu.role from users as usr_edu where smr.partner_id = usr_edu.id) 
 end) end )end) as edu_role,

usr.id, usr.full_name, usr.role, 

(case when usr.email is not null then 1 else 0 end ) as status_email,
(case when usr.mobile_number is not null then 1 else 0 end ) as status_mobile,
(case when usr.last_request_at is not null then 1 else 0 end ) as status_ecad_active_user,

--usr.mobile_number, usr.email

(Case when usr.salon_id is not null then 'salon_master' else 
(Case when slnMNG.id is not null then 'salon_master' else 
(Case when usr.id is not null then 'hairdresser' else 'not_reg_user' end) end) end) as type_master,

(Case when usr.salon_id is not null then usr.salon_id else slnMNG.id end) as salon_id,

(Case when usr.salon_id is not null then concat(sln.id, '_', sln.name, '. ',sln.address) else 
(Case when slnMNG.id is not null then concat(slnMNG.id, '_', slnMNG.name, '. ',slnMNG.address) else '' end) end) as salon,

(Case when usr.salon_id is not null then sln.com_mreg else slnMNG.com_mreg end) as com_mreg,
(Case when usr.salon_id is not null then sln.com_mreg else slnMNG.com_reg end) as com_reg,
(Case when usr.salon_id is not null then sln.com_sect else slnMNG.com_sect end) as com_sect,
(Case when usr.salon_id is not null then sln.client_type else slnMNG.client_type end) as client_type,


(Case when sln.id is not null then
	(Case when sln.is_closed = 't' then 'in_ptnc_base' else 'in_act_base' end) else
	(Case when slnMNG.id is not null then
(Case when slnMNG.is_closed = 't' then 'in_ptnc_base' else 'in_act_base' end) end) end) as active_clnt,

(Case when	
	(CASE when clp.name_prog like '%Expert%' then clp.status else
	   (CASE when clp.name_prog like '%МБК%' then clp.status Else 
		(CASE when clp.name_prog like '%Соглашение%' then clp.status else 'Empty' End)End)End) <> 'Empty' then '2016' Else 'Empty' end)
 	|| ' | ' ||
(Case when 
 (CASE when clt.name_prog like '%Expert%' then clt.status else
   (CASE when clt.name_prog like '%МБК%' then clt.status Else 
	(CASE when clt.name_prog like '%Соглашение%' then clt.status else 'Empty' End)End)End) <> 'Empty' then '2017' Else 'Empty' end)
	 as club,

(Case when 
(CASE when clp_em.name_prog like '%Emotion%' then clp_em.status else 'Empty' End) <> 'Empty' then '2016' Else 'Empty' end)
|| ' | ' ||
(Case when 
(CASE when clt_em.name_prog like '%Emotion%' then clt_em.status else 'Empty' End)  <> 'Empty' then '2017' Else 'Empty' end) as emotion


--(select distinct usr2.chief from users as USR2 where usr2.full_name=usr.chief limit 1 ) as nPlus1

from seminars as SMR
left join seminar_types as smt On smr.seminar_type_id = smt.id 
left join seminar_users as smu ON smu.seminar_id = smr.id
left join users as usr ON smu.user_id = usr.id
left join salons as sln ON usr.salon_id is not null and usr.salon_id = sln.id
left join salons as slnPlace ON smr.salon_id is not null and smr.salon_id = slnPlace.id
left join salons as slnMNG ON usr.salon_id is null and usr.id = slnMNG.salon_manager_id
left join studios as std ON smr.studio_id is not null and smr.studio_id = std.id
left join club_ty_clb  as clt ON 
	sln.id = clt.salon_id and clt.brand = current_database()  
left join club_py_clb  as clp ON 
	sln.id = clp.salon_id and clp.brand = current_database()

left join club_ty_emt  as clt_em ON 
	sln.id = clt_em.salon_id and clt_em.brand = current_database()
left join club_py_emt  as clp_em ON 
	sln.id = clp_em.salon_id and clp_em.brand = current_database()


left join 
	 
dblink('dbname=academie user=readonly password=', 
	'select distinct brand_id as brand_id, master_id as master_id, seminar_id as seminar_id, (Case when price is not null then 1 end) as ykassa
	from payments') AS pmt (brand_id integer, master_id integer, seminar_id integer, ykassa integer)
 ON  smr.id = pmt.seminar_id and usr.id = pmt.master_id and pmt.brand_id = 

 (Case current_database()
                When 'loreal' then 1
                When 'matrix' then 5
                When 'luxe' then 6
                When 'redken' then 7
                When 'essie' then 3
                End)

Where   
smr.started_at >= '2016-01-01' and smr.started_at < '2017-06-01'


order by smr.id
--GROUP BY smr.id, smt.name, smt.id, std.coefficient, spp.status, slnplace.name, slnplace.address, std.name
--group by smr.started_at, smu.user_Id

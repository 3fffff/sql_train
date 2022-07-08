
create table eplreq(
id int primary key,
name varchar(100),
	manager_id int,

	foreign key(manager_id) references eplreq(id)
);
insert into  eplreq values (333,'YASNINA',NULL),
(198,'JOHN',333),(29,'PEDRO',198),(4610,'SARAH',29),(79,'PIERRE',29),(692,'TAREK',333)

drop table eplreq_ext;
create table eplreq_ext as select id, name,manager_id, 0 as report
from eplreq  where id not in (select manager_id from eplreq where manager_id is not null);

select m.id,m.name,m.manager_id,SUM(1+e.report) as reports
from eplreq as m join eplreq_ext as e on e.manager_id = m.manager_id group by  m.id,m.name,m.manager_id

with recursive eplreq_ext(id,name,manager_id,report) as(
	--начало рекурсии, начало все работники не имеющие подчиненных
	select id,name,manager_id,0 as report from eplreq where id not in (select manager_id from eplreq where manager_id is not null)
	UNION
	select m.id,m.name,m.manager_id, e.report+1 from eplreq as m join eplreq_ext as e on m.id=e.manager_id
)

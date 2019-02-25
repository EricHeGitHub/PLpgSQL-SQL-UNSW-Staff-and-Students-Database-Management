
--create type TranscriptRecord as (code text, term text, course integer, prog text, name text, mark integer, grade text, uoc integer, rank integer, totalEnrols integer);

create type TranscriptRecord as (code char(8), term char(4), course integer, prog char(4), name text, mark integer, grade char(2), uoc integer, rank integer, totalEnrols integer);

create or replace function
       semester_transfer(integer) returns text
as
$$
	select substring(cast(year as char(4)) from 3 for 2) || lower(term)  from  Semesters where id = $1;
$$ language sql;

create or replace function total_enrolment(integer)
       returns integer
as
$$
	select cast(count(*) as integer) from course_enrolments where course = $1 and not mark is null;
$$ language sql;

create or replace function rank(integer,integer)
       returns integer
as
$$
declare rank integer :=1;
	r integer;
begin
	if ( not ($2 is null or $1 is null)) then
	   for r in select mark from course_enrolments where course = $1 loop
	       if (r > $2) then 
	       	     rank := rank + 1;
	       end if;
	       end loop;
        else
	   return null string;
	end if;
	return rank;
end
$$ language plpgsql;

create or replace function get_uoc(char(2),integer,integer)
       returns integer
as $$
begin
	if not $1 in('SY','PC','PS','CR','DN','HD','PT','A','B','C') and not $2 is null then
	   return 0;
	else
	   return $3; 
	end if;
end
$$ language plpgsql;	

create or replace function Q1(integer)
	returns setof TranscriptRecord
as $$
declare t TranscriptRecord%rowtype;
begin
	for t in select  sb.code,semester_transfer(sm.id),cs.id,ps.code,sb.name,ce.mark,ce.grade,get_uoc(ce.grade,ce.mark,sb.uoc),rank(ce.course,ce.mark),total_enrolment(ce.course) from programs ps,program_enrolments pe,semesters sm, students sd,courses cs,subjects sb, course_enrolments ce,people pp where ce.course = cs.id and cs.subject = sb.id and ce.student = sd.id and sd.id = pp.id and pp.unswid = $1 and sm.id = cs.semester and sd.id = pe.student and pe.program = ps.id and pe.semester = sm.id loop
	return next t;
	end loop;
return;
end
$$ language plpgsql;


-- Q2: ...
create type MatchingRecord as ("table" text, "column" text, nexamples integer);

create or replace function Q2("table" text, pattern text) 
	returns setof MatchingRecord
as $$
declare matching MatchingRecord%rowtype;
	r text;
	c refcursor;
begin
	for r in select column_name from information_schema.columns where table_name = $1 
	loop
	    select $1 into matching."table";
	    select r into matching."column";
	    open c for execute 'select count('||r||') from '||$1||' where cast('||r||' as text) '||' ~ '''|| $2 ||'''';
	    fetch c into matching.nexamples;
	    close c;
	    if matching.nexamples <> 0 then
	       return next matching;
	    end if;  
	end loop;
end
$$ language plpgsql;

-- Q3: ...
create or replace view all_owners(owners)
as
select owner from orgunit_groups;

create type EmploymentRecord as (unswid integer, name text, roles text);

create or replace function is_null(ending date)
       returns text
as $$
begin 
      if (ending is null) then
      	 return '';
      else 
      	  return cast(ending as text);
      end if;
end
$$ language plpgsql;

create or replace function find_all_org(integer)
       returns setof integer
as $$
declare r integer;
begin 
	for r in select member from orgunit_groups where owner = $1 loop
	    return next r;
	    if (r <> $1) then
	       return query select * from find_all_org(r);
	    end if;
	end loop;
end
$$ language plpgsql;

create or replace function Q3(integer)
        returns  setof EmploymentRecord
as $$
declare r record;
	id integer :=null;
	e EmploymentRecord%rowtype;
	roles text :='';
	org_name text := '';
	role_name text :='';
	starting_time date;
	ending_time date;
	staff_name text;
	staff_unswid integer;
	count_number integer := 0;
begin
	for r in select * from affiliations,people where people.id = affiliations.staff and affiliations.orgunit in (select find_all_org($1)) order by people.sortname, affiliations.starting 
	loop
		if (r.staff <> id or roles = '') then
		   if (roles = '') then
		      id := r.staff;
		      select people.unswid,people.name,staff_roles.name,orgunits.name,affiliations.starting,affiliations.ending into staff_unswid,staff_name,role_name,org_name,starting_time,ending_time from people, affiliations,staff_roles,orgunits where affiliations.staff = r.staff and affiliations.starting=r.starting and affiliations.orgunit = r.orgunit and affiliations.role = r.role and affiliations.orgunit = orgunits.id and affiliations.role=staff_roles.id and people.id = affiliations.staff; 		      
		      roles := role_name || ','||org_name ||' ('|| starting_time ||'..' ||is_null(ending_time) ||')'|| E'\n';
		      count_number := count_number + 1;
		   else 
		      if(count_number > 1) then			   
		      	 e.roles := roles;
			 e.name := staff_name;
			 e.unswid := staff_unswid;
			 return next e;
		      end if;
		      roles := '';
                      count_number := 0;
		      id := r.staff;
		      select people.unswid,people.name,staff_roles.name,orgunits.name,affiliations.starting,affiliations.ending into staff_unswid,staff_name,role_name,org_name,starting_time,ending_time from people, affiliations,staff_roles,orgunits where affiliations.staff =r.staff and affiliations.starting=r.starting and affiliations.orgunit = r.orgunit and affiliations.role = r.role and affiliations.orgunit =orgunits.id and affiliations.role=staff_roles.id and people.id = affiliations.staff;
		      roles := role_name ||', '|| org_name || ' ('||starting_time ||'..' ||is_null(ending_time) ||')'|| E'\n';
                      count_number := count_number + 1;
		   end if;
		else
		      if(ending_time <= r.starting)then
		      	 select people.unswid,people.name,staff_roles.name,orgunits.name,affiliations.starting,affiliations.ending into staff_unswid,staff_name,role_name,org_name,starting_time,ending_time from people, affiliations,staff_roles,orgunits where affiliations.staff =r.staff and affiliations.starting=r.starting and affiliations.orgunit = r.orgunit and affiliations.role = r.role and affiliations.orgunit =orgunits.id and affiliations.role=staff_roles.id and people.id = affiliations.staff;
		      	 roles := roles || role_name ||', '|| org_name ||' ('|| starting_time ||'..'|| is_null(ending_time) ||')'|| E'\n';
			 count_number := count_number + 1;
		      end if;
		end if;
         end loop;
	 if (count_number > 1) then
               e.roles := roles;
               e.name := staff_name;
               e.unswid := staff_unswid;
               return next e;
	 end if;
end
$$ language plpgsql;

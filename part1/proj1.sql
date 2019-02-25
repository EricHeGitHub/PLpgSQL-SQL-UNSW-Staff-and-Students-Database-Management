-- COMP9311 16s1 Project 1
--
-- MyMyUNSW Solution Template


-- Q1: students who have taken more than 55 courses

create or replace function 
       findnumber(studentID integer) returns int as $$
declare course_number integer;
begin
	select count(student) into course_number 
	from course_enrolments 
	where student = studentID;
	return course_number;
end;
$$language plpgsql;
 
create or replace view Q1(unswid, name)
as
select People.unswid, People.name from People where findnumber(People.id) > 55;



-- Q2: get details of the current Heads of Schools

create or replace view HeadisPrimaryandCurrent(id,school,starting) 
as
select af.staff,ou.longname ,af.starting from Affiliations af,OrgUnits ou,Staff_roles sr where af.ending is null and isPrimary is True and ou.id = af.orgUnit and sr.id = af.role and ou.longname like '%School%' and sr.name = 'Head of School';

create or replace view Q2(name,school,starting)
as
select p.name,h.school,h.starting from HeadisPrimaryandCurrent h, People p where h.id = p.id;  

-- Q3 UOC/ETFS ratio
create or replace function calRatio (integer, float)
returns numeric(4,1) as $$
declare results numeric(4,1);
begin
	if($2 > 0) then
	      results := $1/$2;
	      return results;
	else 
	     return null;
	end if;
end;
$$language plpgsql; 
create or replace view ratioView
as
select id, calRatio(uoc, eftsload) from Subjects;

create or replace view Q3(ratio,nsubjects)
as
select calRatio, count(id) from ratioView where not calRatio is null  group by calRatio;



-- Q4: convenor for the most courses

create or replace view CountCourse(id,ncourses)
as 
select Course_staff.staff, count(*)  from Course_staff where Course_staff.role in (select id from Staff_roles where name = 'Course Convenor') group by Course_staff.staff;

create or replace view Q4(name, ncourses)
as
select People.name, CountCourse.ncourses from People,CountCourse where People.id = CountCourse.id and CountCourse.ncourses in (select max(CountCourse.ncourses) from CountCourse);


-- Q5: program enrolments from 05S2
create or replace view Q5a(id)
as select People.unswid from People,Program_enrolments where People.id = Program_enrolments.student and Program_enrolments.program in (select id from Programs where code = '3978') and Program_enrolments.semester in (select id from Semesters where year = 2005 and term = 'S2')
;

create or replace view Q5b(id)
as
select People.unswid from People,Stream_enrolments,Program_enrolments where People.id = Program_enrolments.student and	Program_enrolments.id = Stream_enrolments.partOf and Stream_enrolments.stream in (select id from Streams where code='SENGA1') and Program_enrolments.semester in (select id from Semesters where year = 2005 and term = 'S2')
;

create or replace view Q5c(id)
as
select People.unswid from People,Programs,Program_enrolments where People.id = Program_enrolments.student and Program_enrolments.program = Programs.id and Programs.offeredBy  = (select id from OrgUnits where longname = 'School of Computer Science and Engineering')and Program_enrolments.semester = (select id from Semesters where year = 2005 and term = 'S2')
;


-- Q6: semester names
-- Testing case in check.sql: SELECT * FROM Q6(123);
create or replace function
	Q6(integer) returns text
as
$$
	select substring(cast(year as char(4)) from 3 for 2) || lower(term)  from  Semesters where id = $1;
$$ language sql;



-- Q7: percentage of international students, S1 and S2, starting from 2005
create or replace function percentage (integer)
returns  numeric(4,2) as $$
declare results numeric(4,2);
	total float;
	intern float;
begin
	select count(*) into total from program_enrolments where semester = $1;
	select count(*) into intern from program_enrolments,students where semester = $1 and program_enrolments.student = Students.id and Students.stype = 'intl';
	if(not total = 0) then
		results := intern/total;
	else 
		return null;
	end if;
	return results;
end;
$$language plpgsql;
create or replace view Q7(semester, percent)
as
select q6(id), percentage(id) from Semesters where year >= 2005 and q6(id) ~'[0-9][0-9]s[0-9]' and not percentage(id) is null;
;



-- Q8: subjects with > 25 course offerings and no staff recorded
create or replace view sparse(subject,nOfferings)
as
select Courses.subject ,count(Courses.id)from Courses,Subjects where Subjects.id = Courses.subject and Subjects.id in  ((select distinct Courses.subject from Courses) except (select distinct Courses.subject from course_staff,courses where  Course_staff.course = Courses.id and not staff is null)) group by Courses.subject having count(Courses.id) > 25;

create or replace view Q8(subject, nOfferings)
as
select Subjects.code||' '||Subjects.name,sparse.nOfferings from sparse, Subjects where sparse.subject = Subjects.id 
;


-- Q9: find a good research assistant
	      
create or replace view COMP34(code)
as
select distinct code from Subjects where code like 'COMP34%';

create or replace view distinctstudent(id, unswid, name, code)
as
select Course_enrolments.student, People.unswid, People.name, Subjects.code from Subjects, Courses,Course_enrolments,People where Subjects.code like 'COMP34%' and Course_enrolments.course = Courses.id and Courses.subject = Subjects.id and People.id = Course_enrolments.student;

create or replace view Q9(unswid, name)
as
select distinct d1.unswid, d1.name from distinctstudent d1 where not exists ((select * from COMP34) except (select code from distinctstudent d2 where d2.id = d1.id));



-- Q10: find all students who had been enrolled in all popular subjects
create or replace view majorsemester(year, semester)
as
select distinct year, term from semesters where year between 2002 and 2013 and q6(id) ~ '[0-9][0-9]s[0-9]' order by year asc;

create or replace view COMP9(id)
as
select s1.id from courses c1, subjects s1 where c1.subject = s1.id and s1.code like 'COMP9%'; 

create or replace view popular(id)
as
select distinct cp9.id from comp9 cp9 where not exists ((select year,semester from majorsemester) except (select sm.year,sm.term from semesters sm,courses c1 where c1.subject = cp9.id and c1.semester = sm.id));

create or replace view enrolinpcourses(id, sid)
as
select ce.student, sb.id from Course_enrolments ce,Courses cs,Subjects sb where ce.course = cs.id and cs.subject = sb.id and sb.id in (select * from popular) and ce.grade in ('HD','DN');

create or replace view allenrol (id)
as
select distinct ep1.id from enrolinpcourses ep1 where not exists ((select * from popular) except (select ep2.sid from enrolinpcourses ep2 where ep2.id = ep1.id));

create or replace view q10(unseid,name) 
as
select distinct People.unswid,People.name from People,allenrol where People.id = allenrol.id;




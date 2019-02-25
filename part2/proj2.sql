
--create type TranscriptRecord as (code text, term text, course integer, prog text, name text, mark integer, grade text, uoc integer, rank integer, totalEnrols integer);

create type TranscriptRecord as (code char(8), term char(4), course integer, prog char(4), name text, mark integer, grade char(2), uoc integer, rank integer, totalEnrols integer);

create or replace function Q1(integer)
	returns setof TranscriptRecord
as $$
... one SQL statement, possibly using other functions defined by you ...
$$ language plpgsql;


-- Q2: ...
create type MatchingRecord as ("table" text, "column" text, nexamples integer);

create or replace function Q2("table" text, pattern text) 
	returns setof MatchingRecord
as $$
... one SQL statement, possibly using other functions defined by you ...
$$ language plpgsql;

-- Q3: ...




create type EmploymentRecord as (unswid integer, name text, roles text);
create or replace function Q3(integer) 
	returns setof EmploymentRecord 
as $$
... one SQL statement, possibly using other functions defined by you ...
$$ language plpgsql;


select * from continent_map;
select * from continents;
select * from countries;
select * from per_capita;

--1. Data Integrity Checking & Cleanup

--Alphabetically list all of the country codes in the continent_map table that appear more than once. Display any values where country_code is null as country_code = "FOO" and make this row appear first in the list, even though it should alphabetically sort to the middle. Provide the results of this query as your answer.

with cte as(
select coalesce(country_code, 'FOO') country_code, row_number() over(partition by country_code order by country_code) rn from continent_map
)
select country_code from cte
where rn = 2;

--For all countries that have multiple rows in the continent_map table, delete all multiple records leaving only the 1 record per country. The record that you keep should be the first one when sorted by the continent_code alphabetically ascending. Provide the query/ies and explanation of step(s) that you follow to delete these records.

select * into continent_map1 from continent_map;
with cte as(
select country_code, continent_code, row_number() over(partition by country_code order by country_code, continent_code) rn from continent_map1)

delete from cte where rn>1

select * from continent_map1;


--2. List the countries ranked 10-12 in each continent by the percent of year-over-year growth descending from 2011 to 2012.

--The percent of growth should be calculated as: ((2012 gdp - 2011 gdp) / 2011 gdp)

--The list should include the columns:

--rank
--continent_name
--country_code
--country_name
--growth_percent

with cte as(
select *, lag(gdp_per_capita) over(partition by country_code order by country_code, year) LY_GPC from per_capita
),
cte2 as(
select a.*, round((gdp_per_capita-LY_GPC)*100/LY_GPC, 2) growth_percent, 
b.continent_code, c.continent_name, d.country_name
from cte a left join continent_map1 b
on a.country_code = b.country_code
left join continents c on b.continent_code = c.continent_code
left join countries d on a.country_code = d.country_code
where a.year = 2012),
cte3 as(
select *, rank() over(partition by continent_name order by growth_percent desc) rank from cte2)
select rank, continent_name, country_code, country_name, cast(growth_percent as nvarchar)+'%' growth_percent from cte3
where rank in (10,11,12) and continent_name is not null;


--3. For the year 2012, create a 3 column, 1 row report showing the percent share of gdp_per_capita for the following regions:

--(i) Asia, (ii) Europe, (iii) the Rest of the World. Your result should look something like

--Asia	Europe	Rest of World
--25.0%	25.0%	50.0%

with cte as(
select a.country_code, case when c.continent_name = 'Asia' then 'Asia'
when c.continent_name = 'Europe' then 'Europe' else 'Rest of World' end as continent,
a.gdp_per_capita from per_capita a left join continent_map1 b
on a.country_code = b.country_code
left join continents c on b.continent_code = c.continent_code
where a.year = 2012),
cte2 as(
select continent, cast(round(sum(gdp_per_capita)*100/(select sum(gdp_per_capita) from cte), 2) as nvarchar)+'%' percentage from cte
group by continent)

SELECT *
FROM (
    SELECT continent, percentage
    FROM cte2
) AS SourceTable
PIVOT (
    MAX(percentage)
    FOR continent IN ([Asia], [Europe], [Rest of World])
) AS PivotTable;


--4a. What is the count of countries and sum of their related gdp_per_capita values for the year 2007 where the string 'an' (case insensitive) appears anywhere in the country name?

select count(a.country_code) count, 
'$'+CONVERT(VARCHAR(50), CAST(ROUND(SUM(b.gdp_per_capita), 2) AS DECIMAL(18, 2))) sum_gpc
from countries a left join per_capita b
on a.country_code = b.country_code
where lower(a.country_name) like '%an%'
and b.year = 2007;

--4b. Repeat question 4a, but this time make the query case sensitive.

select count(a.country_code) count, 
'$'+CONVERT(VARCHAR(50), CAST(ROUND(SUM(b.gdp_per_capita), 2) AS DECIMAL(18, 2))) sum_gpc
from countries a left join per_capita b
on a.country_code = b.country_code
where country_name COLLATE SQL_Latin1_General_CP1_CS_AS 
like '%an%' COLLATE SQL_Latin1_General_CP1_CS_AS 
and b.year = 2007;

--5. Find the sum of gpd_per_capita by year and the count of countries for each year that have non-null gdp_per_capita where (i) the year is before 2012 and (ii) the country has a null gdp_per_capita in 2012. Your result should have the columns:

--year
--country_count
--total

select year, count(*) country_count, 
'$'+CONVERT(VARCHAR(50), CAST(ROUND(SUM(gdp_per_capita), 2) AS DECIMAL(18, 2)))  total from per_capita 
where country_code in
(
select country_code from per_capita
where year = 2012 and gdp_per_capita is null
)
and year<2012 and gdp_per_capita is not null
group by year;

--6. All in a single query, execute all of the steps below and provide the results as your final answer:

--a. create a single list of all per_capita records for year 2009 that includes columns:

--continent_name
--country_code
--country_name
--gdp_per_capita
--b. order this list by:

--continent_name ascending
--characters 2 through 4 (inclusive) of the country_name descending
--c. create a running total of gdp_per_capita by continent_name

--d. return only the first record from the ordered list for which each continent's running total of gdp_per_capita meets or exceeds $70,000.00 with the following columns:

--continent_name
--country_code
--country_name
--gdp_per_capita
--running_total

with cte as(
select d.continent_name, a.country_code, b.country_name, a.gdp_per_capita,
sum(a.gdp_per_capita) over(partition by d.continent_name order by d.continent_name) running_total
from per_capita a
left join countries b on a.country_code = b.country_code
left join continent_map1 c on b.country_code = c.country_code
left join continents d on c.continent_code = d.continent_code
where d.continent_name is not null and a.year = 2009),
cte2 as(
select *, dense_rank() over(partition by continent_name order by continent_name asc, SUBSTRING(country_name, 2, 3) desc) rn from cte where running_total>=70000
)
select continent_name, country_code, country_name,
'$'+CONVERT(VARCHAR(50), CAST(ROUND(gdp_per_capita, 2) AS DECIMAL(18, 2))) gdp_per_capita,
'$'+CONVERT(VARCHAR(50), CAST(ROUND(running_total, 2) AS DECIMAL(18, 2)))  total
from cte2 where rn=1;

--7. Find the country with the highest average gdp_per_capita for each continent for all years. Now compare your list to the following data set. Please describe any and all mistakes that you can find with the data set below. Include any code that you use to help detect these mistakes.

--rank	continent_name	country_code	country_name	avg_gdp_per_capita
--1	Africa	SYC	Seychelles	$11,348.66
--1	Asia	KWT	Kuwait	$43,192.49
--1	Europe	MCO	Monaco	$152,936.10
--1	North America	BMU	Bermuda	$83,788.48
--1	Oceania	AUS	Australia	$47,070.39
--1	South America	CHL	Chile	$10,781.71

with cte as(
select d.continent_name, a.country_code, b.country_name, avg(a.gdp_per_capita) avg_gdp_per_capita, 
rank() over(partition by d.continent_name order by avg(a.gdp_per_capita) desc) rn
from per_capita a
left join countries b on a.country_code = b.country_code
left join continent_map1 c on b.country_code = c.country_code
left join continents d on c.continent_code = d.continent_code
where d.continent_name is not null
group by d.continent_name, b.country_name, a.country_code)

select rn rank, continent_name, country_code, country_name,
'$'+CONVERT(VARCHAR(50), CAST(ROUND(avg_gdp_per_capita, 2) AS DECIMAL(18, 2))) avg_gdp_per_capita
from cte where rn = 1;

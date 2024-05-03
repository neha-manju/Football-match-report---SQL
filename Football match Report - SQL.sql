use pro;

select * from country limit 5;

select * from league limit 5;

select * from matches limit 5;

select * from team limit 5;

-- building all primary and foreign keys 

alter table country add primary key(id);

alter table league add primary key(id);

alter table matches add primary key(match_api_id);

alter table team add primary key(team_api_id);

alter table league add foreign key(country_id) references country(id);

alter table matches add foreign key(home_team_api_id) references team(team_api_id);

alter table matches add foreign key(away_team_api_id) references team(team_api_id);


select count(*) from matches;
select count(*) from team;

-- Duplicate check 

select country_id,name,count(*)
from
league
group by country_id,name
having count(*)>1;



-- Data type mismatch check (converting string to timestamp)
select str_to_date(date,'%Y-%m-%d %H:%i:%s') as converted_date, date from matches;

-- change the data type of column

alter table matches modify column date timestamp;


-- views - virtual table 

-- home_team_goal count

-- matches, team
-- Home_team_goal_count view is to identify the number of goals made by team played in the home ground.
-- The minimum number of goals a home team should have done is 3.

create view home_team_goal_count as
select matches.home_team_api_id,
	   team.team_long_name,
       sum(matches.home_team_goal) as goal_count
from
	  matches
      inner join
      team
on
	  matches.home_team_api_id=team.team_api_id
group by matches.home_team_api_id
having sum(matches.home_team_goal)>3;

select count(*) from home_team_goal_count;

select * from home_team_goal_count order by goal_count desc;
      
-- build a view for away_team_goal_count
-- build a away_team_goal_count view using the matches and team tables.
-- let the total number of away_team_goal_count be a minimum of 3.

#building away_team_goal_count

create view away_team_goal_count as
select matches.away_team_api_id, team.team_long_name,sum(matches.away_team_goal) as goal_count
from
matches
inner join
team
on
matches.away_team_api_id=team.team_api_id
group by
matches.away_team_api_id
having sum(matches.away_team_goal)>3;

-- Use Case 1

-- Find the team that won based on the number of goals they have made on the day of the match.

create table team_winning_details as
select winning_team_api_id,match_api_id,match_date
from
(select match_api_id,
`date` as match_date,
case when home_team_goal > away_team_goal then home_team_api_id
when away_team_goal>home_team_goal then away_team_api_id
when away_team_goal=home_team_goal then "Tie"
end as winning_team_api_id
from
matches)A
join
team
on
A.winning_team_api_id=team.team_api_id;

-- Use Case 2 
-- List down the different league names that happened in every country.

select country.name as country_name,
league.name as league_name
from
league
inner join
country
on
country.id=league.country_id;

-- Use Case 3 
-- match based details.. country,league,season,date,match_id,home_team,away_team,,home_team_goal,away_team_goal
-- home_team_names,away_team_names

-- all 4 tables... 

select 
country.name as country_name,
league.name as league_name,
matches.season,
matches.`date`,
matches.match_api_id,
HT.team_long_name as home_team_long_name,
AT.team_long_name as away_team_long_name,
HT.team_short_name as home_team_short_name,
AT.team_short_name as away_team_short_name,
matches.home_team_goal,
matches.away_team_goal,
case when matches.home_team_goal > matches.away_team_goal then matches.home_team_api_id
when matches.away_team_goal>matches.home_team_goal then matches.away_team_api_id
when matches.away_team_goal=matches.home_team_goal then "Tie"
end as winning_team_api_id
from
matches
join
country
on
matches.country_id=country.id
join
league
on
matches.league_id=league.id
left join
team as HT
on
HT.team_api_id=matches.home_team_api_id
left join
team as AT
on
AT.team_api_id=matches.away_team_api_id;

-- Use Case 4 
-- Under every country and league
-- calculate the metrics like
-- no.of distinct stages 
-- no. of teams
-- average home team goals
-- average away team goals
-- average total number of goals
-- sum of the total goals made by home and away.


select 
country.name as country_name,
league.name as league_name,
count(distinct matches.stage) as no_of_distinct_stages,
count(AT.team_api_id) as no_of_teams,
avg(matches.home_team_goal) as avg_home_team_goals,
avg(matches.away_team_goal) as avg_away_team_goals,
avg(matches.home_team_goal+matches.away_team_goal) as avg_total_no_of_goals,
sum(matches.home_team_goal+matches.away_team_goal) as sum_total_no_of_goals
from
matches
join
country
on
country.id=matches.country_id
join
league
on
league.id=matches.league_id
left join team as HT 
on
HT.team_api_id=matches.home_team_api_id
left join team as AT
on
AT.team_api_id=matches.away_team_api_id
group by  country.name,league.name
order by country.name,league.name;

-- Use Case 5
-- Identify the league names and the number of high score matches happened in every league
-- High score matches -- matches with a total of home and away goals >10


 -- CTE (common table expression)
 
 with big_game as (
 select league_id,match_api_id,
 home_team_api_id,away_team_api_id
 from
 matches
 where home_team_goal+away_team_goal>=10)
 select 
 league.name as league_name,
 count(big_game.match_api_id) as high_score_matches
 from
 big_game
 left join
 league 
 on 
 league.id=big_game.league_id
 group by league_id;
 
  -- Use Case 6
  
  -- Rank functions
  -- rank the leagues based on the average total number of goals achieved in every league.
  
  select
  league.name as league_name,
  rank() over (order by avg(home_team_goal+away_team_goal) desc) as league_rank,
  round(avg(home_team_goal+away_team_goal),2) as avg_tol_no_of_goals
  from
  matches
  left join
  league
  on
  league.id=matches.league_id
  group by league.id
  order by league_rank;
 
 -- Use Case 7
 -- Identify the league where the highest goal count is taken by a home and away team using the views.
 -- Based on the views we built, try to perform thre join with the respective table to gather the 
 -- league level details.
 
-- Store procedure
-- Build a procedure to know the total home team goal count and total away team goal count 
-- for a particular team_api

delimiter |
create procedure team_goal_count(IN team_api int,OUT home_team_count int,OUT away_team_count int)
begin
select 
sum(case when home_team_api_id=team_api then home_team_goal end) as home_team_goal_count,
sum(case when away_team_api_id=team_api then away_team_goal end) as away_team_goal_count
from
matches;
end |

set @team_api=9987;
call team_goal_count(@team_api,@home_team_count,@away_team_count);
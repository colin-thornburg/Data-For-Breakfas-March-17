{{ config(materialized='view') }}

with source as (

    select *
    from {{ ref('march_madness_games') }}

),

typed as (

    select
        cast(year as integer) as year,
        cast(round_of as integer) as round_of,

        winning_team_name,
        cast(winning_team_seed as integer) as winning_team_seed,
        cast(winning_team_score as integer) as winning_team_score,

        losing_team_name,
        cast(losing_team_seed as integer) as losing_team_seed,
        cast(losing_team_score as integer) as losing_team_score

    from source

),

enriched as (

    select
        {{ dbt_utils.generate_surrogate_key([
            'year',
            'round_of',
            'winning_team_name',
            'losing_team_name'
        ]) }} as game_id,

        year,
        round_of,
        case
            when round_of = 64 then 'First Round'
            when round_of = 32 then 'Second Round'
            when round_of = 16 then 'Sweet Sixteen'
            when round_of = 8 then 'Elite Eight'
            when round_of = 4 then 'Final Four'
            when round_of = 2 then 'Championship'
        end as round_name,

        winning_team_name,
        winning_team_seed,
        winning_team_score,

        losing_team_name,
        losing_team_seed,
        losing_team_score,

        winning_team_score - losing_team_score as point_differential,
        losing_team_seed - winning_team_seed as seed_differential,
        (losing_team_seed < winning_team_seed) as is_upset

    from typed

)

select *
from enriched

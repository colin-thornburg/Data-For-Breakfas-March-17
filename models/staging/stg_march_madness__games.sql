{{ config(materialized='view') }}

with source_data as (
    select *
    from {{ ref('march_madness_games') }}
),

typed as (
    select
        year::integer as year,
        round_of::integer as round_of,
        winning_team_name,
        winning_team_seed::integer as winning_team_seed,
        winning_team_score::integer as winning_team_score,
        losing_team_name,
        losing_team_seed::integer as losing_team_seed,
        losing_team_score::integer as losing_team_score
    from source_data
),

final as (
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

        (winning_team_score - losing_team_score) as point_differential,
        (losing_team_seed < winning_team_seed) as is_upset,
        (losing_team_seed - winning_team_seed) as seed_differential
    from typed
)

select *
from final

{{
  config(
    materialized='semantic_view',
    static_analysis='off'
  )
}}

TABLES(
  team_games AS {{ ref('fct_team_tournament_games') }}
)

DIMENSIONS(
  team_games.game_id AS game_id,
  team_games.tournament_year AS tournament_year,
  team_games.round_of AS round_of,
  team_games.round_name AS round_name,
  team_games.team_name AS team_name,
  team_games.team_seed AS team_seed,
  team_games.team_score AS team_score,
  team_games.opponent_name AS opponent_name,
  team_games.opponent_seed AS opponent_seed,
  team_games.opponent_score AS opponent_score,
  team_games.is_winner AS is_winner,
  team_games.point_differential AS point_differential,
  team_games.is_upset AS is_upset,
  team_games.is_underdog AS is_underdog
)

{{ config(materialized='semantic_view', static_analysis='off') }}

TABLES(
  team_games AS {{ ref('fct_team_tournament_games') }}
)
DIMENSIONS (
  team_games.game_id            AS game_id            COMMENT = 'Surrogate key for the game',
  team_games.tournament_year    AS tournament_year    COMMENT = 'Tournament year',
  team_games.round_of           AS round_of           COMMENT = 'Round size (64, 32, 16, 8, 4, 2)',
  team_games.round_name         AS round_name         COMMENT = 'Human-readable name for the round',

  team_games.team_name          AS team_name          COMMENT = 'Team name for this row',
  team_games.team_seed          AS team_seed          COMMENT = 'Team seed (lower is better)',
  team_games.team_score         AS team_score         COMMENT = 'Team score',

  team_games.opponent_name      AS opponent_name      COMMENT = 'Opponent team name',
  team_games.opponent_seed      AS opponent_seed      COMMENT = 'Opponent seed (lower is better)',
  team_games.opponent_score     AS opponent_score     COMMENT = 'Opponent score',

  team_games.is_winner          AS is_winner          COMMENT = 'True when this team won the game',
  team_games.point_differential AS point_differential COMMENT = 'Team score minus opponent score (positive=won, negative=lost)',
  team_games.is_upset           AS is_upset           COMMENT = 'True when the winning team was the underdog',
  team_games.is_underdog        AS is_underdog        COMMENT = 'True when team_seed > opponent_seed'
)
COMMENT = 'Team-grain March Madness tournament games exposed as a Snowflake Semantic View.'

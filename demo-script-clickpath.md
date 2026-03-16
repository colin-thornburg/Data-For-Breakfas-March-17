## Pre-Demo Setup Clickpath

### 1. Verify dbt project and profiles

```bash
cd ~/Data-For-Breakfast-March-17
dbt debug
```

### 2. Ensure packages are installed

`packages.yml` contents:

```yaml
packages:
  - package: Snowflake-Labs/dbt_semantic_view
    version: 1.0.3
  - package: dbt-labs/dbt_utils
    version: 1.3.0
```

Install packages:

```bash
cd ~/Data-For-Breakfast-March-17
dbt deps
```

### 3. Prepare the seed file

Copy CSV into `seeds/`:

```bash
Verify seed file exists
```

Clean the CSV (remove blank team names):

```bash
Optional
cd ~/Data-For-Breakfast-March-17
awk -F',' 'NR==1 || ($3 != "" && $6 != "")' seeds/march_madness_games.csv > seeds/tmp.csv && mv seeds/tmp.csv seeds/march_madness_games.csv
```

### 4. Install dbt agent skills in Claude Code

Launch Claude Code from the project directory:

```bash
cd ~/Data-For-Breakfast-March-17
claude --dangerously-skip-permissions
```

In Claude Code, run (one at a time):

```text
/plugin marketplace add dbt-labs/dbt-agent-skills
```

```text
/skills
```

Then restart Claude Code so skills are loaded:

```text
/quit
```

```bash
cd ~/Data-For-Breakfast-March-17
claude
```

---

## Live Demo Clickpath

### Launch Claude Code in auto-approve mode

From a local terminal:

```bash
cd ~/Data-For-Breakfast-March-17
claude --dangerously-skip-permissions
```

---

### Step 1: Load the seed data

**Prompt to paste into Claude Code:**

```text
Use your dbt analytics engineering skill. I have a CSV seed file at
seeds/march_madness_games.csv with NCAA March Madness tournament game data
from 1985-2024. Run dbt seed --full-refresh to load it into Snowflake.
```

---

### Step 2: Build the staging model

**Prompt to paste into Claude Code:**

```text
Use your dbt analytics engineering skill to create a staging model called
stg_march_madness__games based on the march_madness_games seed. It should:
- Cast year as integer and round_of as integer
- Add a surrogate key game_id using dbt_utils.generate_surrogate_key on year,
  round_of, winning_team_name, and losing_team_name
- Add a round_name column that maps round_of to human-readable names:
  64='First Round', 32='Second Round', 16='Sweet Sixteen', 8='Elite Eight',
  4='Final Four', 2='Championship'
- Add point_differential (winning_team_score - losing_team_score)
- Add is_upset boolean (true when losing_team_seed < winning_team_seed)
- Add seed_differential (losing_team_seed - winning_team_seed)
- Include a schema.yml with column descriptions and tests for unique/not_null
  on game_id

Build and verify the model after creating it.
```

---

### Step 3: Build the fact table

**Prompt to paste into Claude Code:**

```text
Use your dbt analytics engineering skill to create a mart model called
fct_team_tournament_games that pivots stg_march_madness__games into
team-grain — each game produces TWO rows, one per team. Columns:
game_id, tournament_year, round_of, round_name, team_name, team_seed,
team_score, opponent_name, opponent_seed, opponent_score, is_winner,
point_differential (positive=won, negative=lost), is_upset, is_underdog.

Include schema.yml with descriptions and tests. Build and verify — show me
rows where team_name = 'Indiana'.
```

---

### Step 4: Build the Snowflake Semantic View

**Prompt to paste into Claude Code:**

```text
I need to create a Snowflake Semantic View. Do NOT use any dbt semantic layer
skill — this is Snowflake-native DDL, not MetricFlow. Do use the custom skill in the skills/dbt-semantic-view/SKILL.md file.
```

(The agent will write the semantic view macro and run `dbt run-operation create_semantic_view`.)

---

### Step 5: Query the Semantic View

**Prompt to paste into Claude Code:**

```text
Query the semantic view sem_tournament_analytics in Snowflake. Show me:

1. Indiana's all-time tournament record (wins, losses, win rate)
2. Indiana's performance by round (how many times have they made each round?)
3. Indiana's biggest upsets as an underdog
4. Top 10 teams by all-time tournament win rate (minimum 20 games)

Use SELECT from the semantic_view() table function to query it. Run each query
using dbt show or a direct Snowflake query.
```

**Example query the agent may run:**

```sql
SELECT *
FROM semantic_view(
  sem_tournament_analytics
  METRICS total_wins, win_rate, upset_wins
  DIMENSIONS team_name
  WHERE team_name = 'Indiana'
)
```


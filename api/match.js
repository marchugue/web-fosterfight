export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const dbUrl = process.env.TURSO_DATABASE_URL;
  const authToken = process.env.TURSO_AUTH_TOKEN;

  if (!dbUrl || !authToken) {
    return res.status(200).json({
      online: false,
      message: 'Turso environment variables not configured. Recorded locally.'
    });
  }

  const httpUrl = dbUrl.replace(/^libsql:\/\//, 'https://').replace(/\/$/, '') + '/v2/pipeline';
  const { winner_name, winner_combo, win_time_seconds, loser_name, loser_combo } = req.body || {};

  if (!winner_name || !loser_name) {
    return res.status(400).json({ error: 'Missing required match fields.' });
  }

  const playedAt = new Date().toISOString();

  const initTablesSql = `
    CREATE TABLE IF NOT EXISTS players (
      player_name TEXT PRIMARY KEY,
      wins INTEGER DEFAULT 0,
      losses INTEGER DEFAULT 0,
      matches_played INTEGER DEFAULT 0,
      highest_combo INTEGER DEFAULT 0,
      fastest_win_seconds REAL,
      last_played_date TEXT
    );
    CREATE TABLE IF NOT EXISTS matches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      player_name TEXT,
      won INTEGER,
      combo_achieved INTEGER,
      win_time_seconds REAL,
      played_at TEXT
    );
  `;

  const winnerSql = `
    INSERT INTO players (player_name, wins, losses, matches_played, highest_combo, fastest_win_seconds, last_played_date)
    VALUES ('${winner_name.replace(/'/g, "''")}', 1, 0, 1, ${winner_combo || 0}, ${win_time_seconds ? win_time_seconds : 'NULL'}, '${playedAt}')
    ON CONFLICT(player_name) DO UPDATE SET
      wins = wins + 1,
      matches_played = matches_played + 1,
      highest_combo = MAX(highest_combo, ${winner_combo || 0}),
      fastest_win_seconds = CASE
        WHEN fastest_win_seconds IS NULL THEN ${win_time_seconds ? win_time_seconds : 'NULL'}
        WHEN ${win_time_seconds ? win_time_seconds : 'NULL'} IS NOT NULL AND ${win_time_seconds ? win_time_seconds : 'NULL'} < fastest_win_seconds THEN ${win_time_seconds ? win_time_seconds : 'NULL'}
        ELSE fastest_win_seconds
      END,
      last_played_date = '${playedAt}';
  `;

  const loserSql = `
    INSERT INTO players (player_name, wins, losses, matches_played, highest_combo, fastest_win_seconds, last_played_date)
    VALUES ('${loser_name.replace(/'/g, "''")}', 0, 1, 1, ${loser_combo || 0}, NULL, '${playedAt}')
    ON CONFLICT(player_name) DO UPDATE SET
      losses = losses + 1,
      matches_played = matches_played + 1,
      highest_combo = MAX(highest_combo, ${loser_combo || 0}),
      last_played_date = '${playedAt}';
  `;

  const winnerMatchSql = `
    INSERT INTO matches (player_name, won, combo_achieved, win_time_seconds, played_at)
    VALUES ('${winner_name.replace(/'/g, "''")}', 1, ${winner_combo || 0}, ${win_time_seconds ? win_time_seconds : 'NULL'}, '${playedAt}');
  `;
  const loserMatchSql = `
    INSERT INTO matches (player_name, won, combo_achieved, win_time_seconds, played_at)
    VALUES ('${loser_name.replace(/'/g, "''")}', 0, ${loser_combo || 0}, NULL, '${playedAt}');
  `;

  try {
    const response = await fetch(httpUrl, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        requests: [
          { type: 'execute', stmt: { sql: initTablesSql } },
          { type: 'execute', stmt: { sql: winnerSql } },
          { type: 'execute', stmt: { sql: loserSql } },
          { type: 'execute', stmt: { sql: winnerMatchSql } },
          { type: 'execute', stmt: { sql: loserMatchSql } },
          { type: 'close' }
        ]
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      return res.status(500).json({ error: errText });
    }

    return res.status(200).json({ success: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}

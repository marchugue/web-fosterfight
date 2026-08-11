export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const dbUrl = process.env.TURSO_DATABASE_URL;
  const authToken = process.env.TURSO_AUTH_TOKEN;

  if (!dbUrl || !authToken) {
    return res.status(200).json({
      online: false,
      message: 'Turso environment variables (TURSO_DATABASE_URL, TURSO_AUTH_TOKEN) not configured.',
      records: []
    });
  }

  const httpUrl = dbUrl.replace(/^libsql:\/\//, 'https://').replace(/\/$/, '') + '/v2/pipeline';
  const mode = req.query.mode || 'Wins';
  const limit = parseInt(req.query.limit || '50', 10);

  let orderBy = 'wins DESC';
  if (mode === 'HighestCombo') {
    orderBy = 'highest_combo DESC';
  } else if (mode === 'FastestWinSeconds') {
    orderBy = 'fastest_win_seconds ASC';
  }

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
  `;

  const querySql = `SELECT player_name, wins, losses, matches_played, highest_combo, fastest_win_seconds, last_played_date FROM players ORDER BY ${orderBy} LIMIT ${limit};`;

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
          { type: 'execute', stmt: { sql: querySql } },
          { type: 'close' }
        ]
      })
    });

    if (!response.ok) {
      const errText = await response.text();
      return res.status(500).json({ error: errText, records: [] });
    }

    const data = await response.json();
    const queryResult = data?.results?.[1]?.response?.result;

    if (!queryResult) {
      return res.status(200).json({ online: true, records: [] });
    }

    const cols = queryResult.cols.map(c => c.name);
    const rows = queryResult.rows.map(row => {
      const obj = {};
      row.forEach((cell, idx) => {
        const colName = cols[idx];
        obj[colName] = cell.value !== undefined ? cell.value : null;
        if (cell.type === 'integer' || cell.type === 'numeric') {
          obj[colName] = Number(cell.value);
        }
      });
      return obj;
    });

    return res.status(200).json({ online: true, records: rows });
  } catch (err) {
    return res.status(500).json({ error: err.message, records: [] });
  }
}

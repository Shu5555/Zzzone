
const { createClient } = require('@supabase/supabase-js');

exports.handler = async function(event, context) {
  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);
  const today = new Date().toISOString().slice(0, 10);

  // 1. 今日のレコードをすべて、作成時刻の新しい順に取得する
  const { data: records, error } = await supabase
    .from('sleep_records')
    .select(`
      sleep_duration,
      created_at,
      users!left ( id, username )
    `)
    .eq('date', today)
    .order('created_at', { ascending: false });

  if (error) {
    return { statusCode: 500, body: JSON.stringify({ message: error.message }) };
  }

  // 2. ユーザーごとに最新のレコード（リストの最初に出てくるもの）だけを抽出する
  const uniqueUserRecords = [];
  const userIds = new Set();

  for (const record of records) {
    const userId = record.users?.id;
    if (userId && !userIds.has(userId)) {
      uniqueUserRecords.push(record);
      userIds.add(userId);
    }
  }

  // 3. 抽出したレコードを睡眠時間でソートする
  uniqueUserRecords.sort((a, b) => b.sleep_duration - a.sleep_duration);

  // 4. 上位20件に絞って返却する
  const finalRanking = uniqueUserRecords.slice(0, 20);

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(finalRanking),
  };
};

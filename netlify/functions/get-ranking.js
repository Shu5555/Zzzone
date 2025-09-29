
const { createClient } = require('@supabase/supabase-js');

exports.handler = async function(event, context) {
  // 環境変数からSupabaseの情報を取得
  const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

  // 今日の日付を'YYYY-MM-DD'形式で取得
  const today = new Date().toISOString().slice(0, 10);

  // sleep_recordsテーブルから、usersテーブルのusernameを含めてデータを取得
  const { data, error } = await supabase
    .from('sleep_records')
    .select(`
      sleep_duration,
      users ( username )
    `)
    .eq('date', today) // 今日の日付でフィルタリング
    .order('sleep_duration', { ascending: false }) // 睡眠時間で降順ソート
    .limit(20); // 上位20件に制限

  if (error) {
    return { statusCode: 500, body: JSON.stringify({ message: error.message }) };
  }

  return {
    statusCode: 200,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  };
};

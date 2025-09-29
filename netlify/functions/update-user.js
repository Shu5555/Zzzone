
const { createClient } = require('@supabase/supabase-js');

exports.handler = async function(event, context) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    const { id, username } = JSON.parse(event.body);

    if (!id || !username) {
      return { statusCode: 400, body: 'Missing required fields' };
    }

    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);

    // ユーザーIDをキーにして、ユーザー名が存在すれば更新、なければ新しい行を作成する
    const { data, error } = await supabase
      .from('users')
      .upsert({ id, username }, { onConflict: 'id' });

    if (error) {
      throw error;
    }

    return { statusCode: 200, body: JSON.stringify(data) };

  } catch (e) {
    return { statusCode: 500, body: JSON.stringify({ message: e.message }) };
  }
};

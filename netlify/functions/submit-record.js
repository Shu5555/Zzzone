
const { createClient } = require('@supabase/supabase-js');

exports.handler = async function(event, context) {
  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, body: 'Method Not Allowed' };
  }

  try {
    const { user_id, sleep_duration, date } = JSON.parse(event.body);

    if (!user_id || !sleep_duration || !date) {
      return { statusCode: 400, body: 'Missing required fields' };
    }

    const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY);

    const { data, error } = await supabase
      .from('sleep_records')
      .insert([{ user_id, sleep_duration, date }]);

    if (error) {
      throw error;
    }

    return { statusCode: 201, body: JSON.stringify(data) };

  } catch (e) {
    return { statusCode: 500, body: JSON.stringify({ message: e.message }) };
  }
};

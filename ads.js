// /api/ads.js — Vercel Serverless Function
//
// ئەم فایلە لەسەر سێرڤەری Vercel جێبەجێ دەبێت، نەک لە browserـدا.
// SUPABASE_SERVICE_KEY تەنها لێرە دەخوێنرێتەوە (لە Environment Variables)
// و هەرگیز ناچێتە ناو HTML/JSـی کە بۆ کڕیار (browser) دەنێردرێت.
//
// پێویستە لە Vercel Project Settings → Environment Variables ئەمانە زیاد بکەیت:
//   SUPABASE_URL          = https://cojchkwssmasiejcgvbk.supabase.co
//   SUPABASE_SERVICE_KEY  = <کلیلی service_role لە Supabase Dashboard → API>
//   REPORT_ADMIN_KEY      = (ئارەزوومەندانە) هەر نهێنییەکی خۆت، بۆ سنووردارکردنی گەیشتن

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const ADMIN_KEY = process.env.REPORT_ADMIN_KEY; // ئارەزوومەندانە

module.exports = async (req, res) => {
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return res.status(500).json({
      error: 'SUPABASE_URL یان SUPABASE_SERVICE_KEY لە Vercel Environment Variables دانەنراوە',
    });
  }

  // سنووردارکردنی ئارەزوومەندانە: ئەگەر REPORT_ADMIN_KEY دانرابێت، پێویستە
  // داواکارییەکە هێدەری x-admin-key بنێرێت کە یەکسانە پێی.
  if (ADMIN_KEY && req.headers['x-admin-key'] !== ADMIN_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const supaHeaders = {
    apikey: SUPABASE_SERVICE_KEY,
    Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    'Content-Type': 'application/json',
  };

  try {
    if (req.method === 'GET') {
      let rows = [];
      let from = 0;
      const PAGE = 1000;
      while (true) {
        const r = await fetch(
          `${SUPABASE_URL}/rest/v1/pa_ads?select=*&order=created_at.desc&offset=${from}&limit=${PAGE}`,
          { headers: supaHeaders }
        );
        if (!r.ok) throw new Error(`${r.status}: ${await r.text()}`);
        const chunk = await r.json();
        rows = rows.concat(chunk);
        if (chunk.length < PAGE) break;
        from += PAGE;
      }
      return res.status(200).json(rows);
    }

    if (req.method === 'PATCH') {
      const { id } = req.query;
      if (!id) return res.status(400).json({ error: 'id پێویستە' });
      const r = await fetch(`${SUPABASE_URL}/rest/v1/pa_ads?id=eq.${id}`, {
        method: 'PATCH',
        headers: { ...supaHeaders, Prefer: 'return=minimal' },
        body: JSON.stringify(req.body),
      });
      if (!r.ok) throw new Error(`${r.status}: ${await r.text()}`);
      return res.status(200).json({ ok: true });
    }

    if (req.method === 'DELETE') {
      const { id } = req.query;
      if (!id) return res.status(400).json({ error: 'id پێویستە' });
      const r = await fetch(`${SUPABASE_URL}/rest/v1/pa_ads?id=eq.${id}`, {
        method: 'DELETE',
        headers: supaHeaders,
      });
      if (!r.ok) throw new Error(`${r.status}: ${await r.text()}`);
      return res.status(200).json({ ok: true });
    }

    res.setHeader('Allow', 'GET, PATCH, DELETE');
    return res.status(405).json({ error: 'Method Not Allowed' });
  } catch (e) {
    return res.status(500).json({ error: e.message });
  }
};

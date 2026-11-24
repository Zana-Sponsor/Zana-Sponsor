import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

async function googleAccessToken() {
  const raw = Deno.env.get('GOOGLE_CLOUD_SERVICE_ACCOUNT_JSON')
  if (!raw) throw new Error('GOOGLE_CLOUD_SERVICE_ACCOUNT_JSON_MISSING')
  const sa = JSON.parse(raw)
  const enc = (v: string) => btoa(v).replaceAll('+','-').replaceAll('/','_').replaceAll('=','')
  const now = Math.floor(Date.now()/1000)
  const header = enc(JSON.stringify({ alg:'RS256', typ:'JWT' }))
  const claim = enc(JSON.stringify({ iss:sa.client_email, scope:'https://www.googleapis.com/auth/cloud-platform', aud:'https://oauth2.googleapis.com/token', iat:now, exp:now+3600 }))
  const pem = sa.private_key.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'')
  const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c=>c.charCodeAt(0)), { name:'RSASSA-PKCS1-v1_5', hash:'SHA-256' }, false, ['sign'])
  const input = `${header}.${claim}`
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(input))
  const assertion = `${input}.${enc(String.fromCharCode(...new Uint8Array(sig)))} ` .trim()
  const r = await fetch('https://oauth2.googleapis.com/token', { method:'POST', headers:{'Content-Type':'application/x-www-form-urlencoded'}, body:new URLSearchParams({ grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }) })
  if (!r.ok) throw new Error(`GOOGLE_TOKEN_${r.status}`)
  return (await r.json()).access_token as string
}

async function vision(token: string, content: string, features: unknown[]) {
  const project = JSON.parse(Deno.env.get('GOOGLE_CLOUD_SERVICE_ACCOUNT_JSON')!).project_id
  const r = await fetch(`https://vision.googleapis.com/v1/projects/${project}/images:annotate`, { method:'POST', headers:{ Authorization:`Bearer ${token}`, 'Content-Type':'application/json' }, body:JSON.stringify({ requests:[{ image:{content}, features }] }) })
  if (!r.ok) throw new Error(`GOOGLE_VISION_${r.status}`)
  return (await r.json()).responses?.[0] || {}
}

let currentVerificationId: string | null = null

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const auth = req.headers.get('Authorization') || ''
    const token = auth.replace(/^Bearer\s+/i, '')
    if (!token) return json({ error:'AUTH_REQUIRED' }, 401)
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth:{ persistSession:false } })
    const { data:{ user }, error:authError } = await admin.auth.getUser(token)
    if (authError || !user) return json({ error:'AUTH_REQUIRED' }, 401)
    const { verification_id } = await req.json()
    currentVerificationId = verification_id
    const { data: v } = await admin.from('ex_identity_verifications').select('id,user_id,front_image_path,back_image_path,selfie_image_path,status').eq('id', verification_id).eq('user_id', user.id).maybeSingle()
    if (!v) return json({ error:'KYC_NOT_FOUND' }, 404)
    const { error:updateError } = await admin.from('ex_identity_verification_face').upsert({ verification_id:v.id,status:'processing',updated_at:new Date().toISOString() })
    if (updateError) throw updateError
    const read = async (path:string) => { const { data, error } = await admin.storage.from('identity-documents').download(path); if(error) throw error; const bytes = new Uint8Array(await data.arrayBuffer()); let out=''; for(let i=0;i<bytes.length;i+=0x8000) out += String.fromCharCode(...bytes.subarray(i,i+0x8000)); return btoa(out) }
    const [front, selfie] = await Promise.all([read(v.front_image_path), read(v.selfie_image_path)])
    const google = await googleAccessToken()
    const [doc, face] = await Promise.all([
      vision(google, front, [{ type:'DOCUMENT_TEXT_DETECTION', maxResults:1 }]),
      vision(google, selfie, [{ type:'FACE_DETECTION', maxResults:10 }])
    ])
    const faces = face.faceAnnotations || []
    const text = doc.fullTextAnnotation?.text || doc.textAnnotations?.[0]?.description || null
    await admin.from('ex_identity_verification_face').update({ status:faces.length ? 'review' : 'not_matched', face_detected:faces.length>0, match_score:null, error_code:faces.length ? null : 'NO_FACE_DETECTED', model:'google-cloud-vision', processed_at:new Date().toISOString(), updated_at:new Date().toISOString() }).eq('verification_id',v.id)
    await admin.from('ex_identity_verification_ocr').upsert({ verification_id:v.id,status:'completed',model:'google-cloud-vision',processed_at:new Date().toISOString(),updated_at:new Date().toISOString() })
    return json({ ok:true, verification_id:v.id, face_detected:faces.length>0, ocr_text:text })
  } catch (e) {
    console.error(e)
    return json({ error: e instanceof Error ? e.message : 'KYC_GOOGLE_FAILED' }, 500)
  }
})

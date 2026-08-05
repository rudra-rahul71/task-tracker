import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from "npm:google-auth-library@9"

serve(async (req) => {
  try {
    const { record, old_record, type } = await req.json()

    // 1. Return 200 OK for ignored event types (prevents webhook retry loops)
    if (type !== 'INSERT') {
      return new Response(JSON.stringify({ message: "Ignored non-insert event" }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    }

    const taskName = record.name || "A new task"
    const userId = record.userId

    if (!userId) {
      return new Response(JSON.stringify({ message: "No user associated with this task" }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    }

    // 2. Initialize Supabase client to fetch tokens
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: tokens, error } = await supabaseClient
      .schema('users')
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId)
      .eq('app_id', 'task_tracker')

    if (error || !tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ message: "No tokens found" }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    }

    const fcmTokens = tokens.map(t => t.token)

    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if (!serviceAccountStr) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY is not set')
    }
    const serviceAccount = JSON.parse(serviceAccountStr)

    // 3. Generate OAuth Token for FCM v1
    const auth = new GoogleAuth({
      credentials: {
        client_email: serviceAccount.client_email,
        private_key: serviceAccount.private_key,
      },
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const accessToken = await auth.getAccessToken()
    const projectId = serviceAccount.project_id
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

    // 4. Send push to all tokens concurrently
    const pushPromises = fcmTokens.map(async (token) => {
      const payload = {
        message: {
          token: token,
          notification: {
            title: "New Task Created!",
            body: `Task: ${taskName}`
          },
          data: {
            task_id: record.id ?? ''
          }
        }
      }

      const res = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${accessToken}`
        },
        body: JSON.stringify(payload)
      })

      return { token, result: await res.json() }
    })

    const results = await Promise.all(pushPromises)
    const errors = results.flatMap(r => r.result?.error ? [r.result.error] : [])
    console.log(`FCM successful sends: ${results.length - errors.length}`)
    if (errors.length > 0) {
      console.log(`FCM errors: ${errors.length} error(s):`, errors)
    }

    // 5. Clean up stale tokens that FCM rejected
    const staleStatuses = new Set(['NOT_FOUND', 'UNREGISTERED', 'INVALID_ARGUMENT'])
    const staleTokens = results
      .filter(r => staleStatuses.has(r.result?.error?.status))
      .map(r => r.token)

    if (staleTokens.length > 0) {
      await supabaseClient
        .schema('users')
        .from('device_tokens')
        .delete()
        .in('token', staleTokens)

      console.log(`Cleaned up ${staleTokens.length} token(s): ${staleTokens}`)
    }

    return new Response(JSON.stringify({ success: true, sent: fcmTokens.length, staleRemoved: staleTokens.length, results }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err?.message ?? err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    })
  }
})

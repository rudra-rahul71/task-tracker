import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from "npm:google-auth-library@9"

serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}))
    const { record, old_record, type } = body

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey)

    // 1. Initialize Google Auth for FCM v1
    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')
    if (!serviceAccountStr) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY is not set')
    }
    const serviceAccount = JSON.parse(serviceAccountStr)

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

    const processResults: any[] = []

    // 2. Process single record if present (Database Webhook trigger)
    if (record) {
      const userId = record.userId || record.user_id
      if (userId) {
        const senderToken = record.lastUpdatedByToken

        let tokenQuery = supabaseClient
          .schema('users')
          .from('device_tokens')
          .select('token')
          .eq('user_id', userId)
          .eq('app_id', 'task_tracker')

        if (senderToken) {
          tokenQuery = tokenQuery.neq('token', senderToken)
        }

        const { data: tokens, error: tokenError } = await tokenQuery

        if (tokenError) {
          console.error('Error fetching device tokens for record:', tokenError)
        }

        if (tokens && tokens.length > 0) {
          const fcmTokens = tokens.map((t: any) => t.token)
          const hasValidTime = record.notificationTime && !isNaN(new Date(record.notificationTime).getTime())
          const isCompleted = record.status === 'completed'

          let dataPayload: Record<string, string>
          if (!record.notificationTime || isCompleted || !hasValidTime) {
            dataPayload = {
              action: 'CANCEL_SCHEDULE',
              task_id: String(record.id ?? ''),
            }
          } else {
            dataPayload = {
              action: 'SYNC_SCHEDULE',
              task_id: String(record.id ?? ''),
              title: "Task Reminder",
              body: String(record.name ?? ''),
              notification_time: String(record.notificationTime),
            }
          }

          const pushPromises = fcmTokens.map(async (token: string) => {
            const payload = {
              message: {
                token: token,
                data: dataPayload,
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
          }

          processResults.push({
            taskId: record.id,
            action: dataPayload.action,
            sent: fcmTokens.length - staleTokens.length,
            staleRemoved: staleTokens.length,
          })
        }
      }
    } else {
      // 3. Fallback: Process due pending tasks from database if no single record provided
      const nowIso = new Date().toISOString()
      const { data: dueTasks, error: dueError } = await supabaseClient
        .schema('task_tracker')
        .from('tasks')
        .select('*')
        .eq('status', 'pending')
        .eq('isNotificationSent', false)
        .not('notificationTime', 'is', null)
        .lte('notificationTime', nowIso)

      if (dueError) {
        console.error('Error fetching due tasks:', dueError)
      }

      if (dueTasks && dueTasks.length > 0) {
        for (const task of dueTasks) {
          const userId = task.userId || task.user_id
          if (!userId) continue

          const senderToken = task.lastUpdatedByToken

          let tokenQuery = supabaseClient
            .schema('users')
            .from('device_tokens')
            .select('token')
            .eq('user_id', userId)
            .eq('app_id', 'task_tracker')

          if (senderToken) {
            tokenQuery = tokenQuery.neq('token', senderToken)
          }

          const { data: tokens } = await tokenQuery

          let sentCount = 0
          let staleCount = 0

          if (tokens && tokens.length > 0) {
            const fcmTokens = tokens.map((t: any) => t.token)

            const pushPromises = fcmTokens.map(async (token: string) => {
              const payload = {
                message: {
                  token: token,
                  notification: {
                    title: "Task Reminder",
                    body: String(task.name || "Task Reminder"),
                  },
                  data: {
                    action: 'SYNC_SCHEDULE',
                    task_id: String(task.id ?? ''),
                    title: "Task Reminder",
                    body: String(task.name ?? ''),
                    notification_time: String(task.notificationTime),
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
            }

            sentCount = fcmTokens.length - staleTokens.length
            staleCount = staleTokens.length
          }

          if (task.id) {
            await supabaseClient
              .schema('task_tracker')
              .from('tasks')
              .update({ isNotificationSent: true })
              .eq('id', task.id)
          }

          processResults.push({
            taskId: task.id,
            sent: sentCount,
            staleRemoved: staleCount,
          })
        }
      }
    }

    return new Response(JSON.stringify({ success: true, processed: processResults.length, details: processResults }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    })
  } catch (err: any) {
    return new Response(JSON.stringify({ error: String(err?.message ?? err) }), {
      status: 500,
      headers: { "Content-Type": "application/json" }
    })
  }
})

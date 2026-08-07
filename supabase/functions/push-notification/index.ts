import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { GoogleAuth } from "npm:google-auth-library@9"

serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}))
    const { record, type } = body

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey)

    // 1. Fetch due pending tasks from database
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

    const tasksToProcess: any[] = dueTasks ? [...dueTasks] : []

    // 2. Handle single trigger payload if present
    if (record) {
      const isDue = record.status === 'pending' &&
        record.isNotificationSent === false &&
        record.notificationTime &&
        new Date(record.notificationTime) <= new Date()

      if (isDue) {
        if (!tasksToProcess.some((t) => t.id === record.id)) {
          tasksToProcess.push(record)
        }
      } else if (type === 'INSERT' && !record.notificationTime) {
        // Immediate notification for newly created task without scheduled time
        tasksToProcess.push({
          ...record,
          isImmediate: true,
        })
      }
    }

    if (tasksToProcess.length === 0) {
      return new Response(JSON.stringify({ message: "No pending notifications due" }), {
        status: 200,
        headers: { "Content-Type": "application/json" }
      })
    }

    // 3. Initialize Google Auth for FCM v1
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

    const processResults = []

    // 4. Process each task
    for (const task of tasksToProcess) {
      const userId = task.userId
      if (!userId) continue

      // Fetch FCM tokens for user
      const { data: tokens, error: tokenError } = await supabaseClient
        .schema('users')
        .from('device_tokens')
        .select('token')
        .eq('user_id', userId)
        .eq('app_id', 'task_tracker')

      let sentCount = 0
      let staleCount = 0

      if (tokens && tokens.length > 0) {
        const fcmTokens = tokens.map((t: any) => t.token)
        const isImmediate = task.isImmediate === true
        const title = isImmediate ? "New Task Created!" : "Task Reminder"
        const bodyText = isImmediate ? `Task: ${task.name}` : (task.name || "Task Reminder")

        const pushPromises = fcmTokens.map(async (token: string) => {
          const payload = {
            message: {
              token: token,
              notification: {
                title: title,
                body: bodyText,
              },
              data: {
                task_id: task.id ?? '',
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

      // Mark isNotificationSent = true on task if it's a scheduled notification and has an ID
      if (task.id && !task.isImmediate) {
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

# ESupabaseAnalytics — Supabase setup

`ESupabaseAnalytics` writes events to a single table in your existing Supabase
project. Run the migration in `migrations/20260420000000_esupabaseanalytics.sql`
once per project to create it.

## Apply the migration

### Option A — Supabase CLI (recommended)

From the repo root:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

### Option B — SQL editor

Open the Supabase dashboard → SQL editor → paste the contents of
`migrations/20260420000000_esupabaseanalytics.sql` → Run.

## Configure the client

Use the same URL + anon key the rest of your app already uses. You do not need a
separate Supabase project.

```swift
// iOS
ESupabaseAnalytics.shared.configure(
    ESupabaseAnalyticsConfig(
        supabaseUrl: URL(string: "https://your-project.supabase.co")!,
        anonKey: "eyJhbGciOi..."
    )
)
```

```kotlin
// Android
ESupabaseAnalytics.configure(
    context = this,
    config = ESupabaseAnalyticsConfig(
        supabaseUrl = "https://your-project.supabase.co",
        anonKey = "eyJhbGciOi..."
    )
)
```

If you already have a table named `analytics` in that project, pass a different
`tableName` in the config and adjust the migration to match.

## Useful queries

```sql
-- Daily active devices (last 30 days)
select date_trunc('day', occurred_at) as day,
       count(distinct device_id)      as dau
from public.analytics
where occurred_at > now() - interval '30 days'
group by 1
order by 1;

-- Days-visited per user
select user_id,
       count(distinct date_trunc('day', occurred_at)) as days_visited
from public.analytics
where user_id is not null
group by user_id
order by days_visited desc;

-- Average session duration (from session_end events)
select avg((properties->>'duration_ms')::bigint) / 1000.0 as avg_seconds
from public.analytics
where event_name = 'session_end';

-- Top events in the last 24 hours
select event_name, count(*) as n
from public.analytics
where occurred_at > now() - interval '24 hours'
group by event_name
order by n desc;
```

$ErrorActionPreference = "Stop"

param(
  [string]$Device = "emulator-5554"
)

$defines = @()
if ($env:SUPABASE_URL) { $defines += "--dart-define=SUPABASE_URL=$env:SUPABASE_URL" }
if ($env:SUPABASE_ANON_KEY) { $defines += "--dart-define=SUPABASE_ANON_KEY=$env:SUPABASE_ANON_KEY" }

flutter run -d $Device @defines

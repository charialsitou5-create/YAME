/// Projet Supabase de Yame. La clé « anon » est publique par conception : elle est
/// embarquée dans toute application mobile, et c'est la RLS (jeton Firebase) qui protège les données.
/// Surcharge possible : `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://dypounvwmloptxsnvhmj.supabase.co');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5cG91bnZ3bWxvcHR4c252aG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM1NDQ4MDQsImV4cCI6MjEwOTEyMDgwNH0.mDk5sWjuY58a2M9zJnoCN7U5vDLNEYPS5mFamR53lDA');

/// Formats a [DateTime] as 'YYYY-MM-DD' for Supabase / Postgres queries.
String dateToString(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

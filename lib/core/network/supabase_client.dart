import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider del cliente de Supabase.
/// 
/// Inyectado via Riverpod para facilitar el testeo (puedes overridearlo).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

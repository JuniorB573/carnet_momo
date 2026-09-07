/// Configuration Supabase — projet "carnet momo".
///
/// La clé "publishable" est faite pour être utilisée dans une app cliente
/// (elle est protégée par les règles de sécurité RLS définies dans
/// supabase_schema.sql). Elle n'est pas secrète, contrairement à la
/// "secret key" qui ne doit jamais apparaître dans le code de l'app.
class SupabaseConfig {
  static const String url = 'https://lykyrgiiqrgbgrbljali.supabase.co';
  static const String publishableKey =
      'sb_publishable_Bvl9r496XUavSQ1PRTlMew_swRiH4oK';
}

package com.gpm.expensemanager_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (no FlutterActivity): requerido por local_auth para
// mostrar el prompt biométrico (BiometricPrompt necesita FragmentActivity).
class MainActivity : FlutterFragmentActivity()

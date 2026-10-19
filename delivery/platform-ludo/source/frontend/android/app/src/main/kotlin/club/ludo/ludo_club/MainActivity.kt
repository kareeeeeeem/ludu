package club.ludo.ludo_club

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity : FlutterActivity() {
    private var platformChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        platformChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ludo.club/platform")
        platformChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getSession") {
                val session = intent?.getStringExtra("platform_session")
                intent?.removeExtra("platform_session")
                result.success(session)
            } else if (call.method == "returnToPlatform") {
                finish()
                result.success(null)
            } else result.notImplemented()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        platformChannel?.invokeMethod("sessionAvailable", null)
    }
}

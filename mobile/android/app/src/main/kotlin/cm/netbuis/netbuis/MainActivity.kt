package cm.netbuis.netbuis

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var appChannel: AppChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Micro, WhatsApp et composeur du support (les appels passent par Jitsi, D-25).
        val channel = AppChannel(this)
        appChannel = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AppChannel.NAME)
            .setMethodCallHandler(channel)
        // Partage : ouvre la feuille de partage Android avec un texte.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cm.netbuis/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareText") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val text = call.argument<String>("text")
                if (text.isNullOrEmpty()) {
                    result.error("invalid", "Texte vide", null)
                    return@setMethodCallHandler
                }
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                startActivity(Intent.createChooser(send, null))
                result.success(null)
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        appChannel?.onRequestPermissionsResult(requestCode, grantResults)
    }
}

package cm.netbuis.netbuis

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Canal "cm.netbuis/call" : micro, WhatsApp et composeur du support.
 *
 * Depuis D-25 il n'y a plus d'appel téléphonique direct (ni TelecomManager, ni SIM, ni
 * permissions « Téléphone ») : les appels passent par Jitsi vers l'équipe NetBuis.
 *
 * ZONE SENSIBLE : [openWhatsapp] reçoit le lien wa.me, qui CONTIENT le numéro du commerçant :
 *  - ne JAMAIS le journaliser (aucun Log.*, aucun println), ni le mettre dans un message d'erreur ;
 *  - ne JAMAIS le stocker : il n'existe que comme variable locale ;
 *  - seul un lien https://wa.me/… est ouvert, et seulement dans l'application WhatsApp.
 *
 * Méthodes : microphone, requestMicrophone, openWhatsapp, dial (numéro du SUPPORT NetBuis).
 */
class AppChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val NAME = "cm.netbuis/call"
        const val REQUEST_CODE = 5201
        private const val PREFS = "netbuis_call"
        private const val KEY_ASKED = "mic_asked"
        /** WhatsApp, puis WhatsApp Business. */
        private val WHATSAPP_PACKAGES = arrayOf("com.whatsapp", "com.whatsapp.w4b")
    }

    /** Réponse en attente de la demande Android (une seule à la fois). */
    private var pendingMicrophone: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "microphone" -> result.success(
                mapOf("granted" to hasMicrophone(), "asked" to wasAsked())
            )
            "requestMicrophone" -> requestMicrophone(result)
            "openWhatsapp" -> openWhatsapp(call.argument<String>("url"), result)
            "dial" -> dial(call.argument<String>("phone"), result)
            else -> result.notImplemented()
        }
    }

    /** À appeler depuis MainActivity.onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        val pending = pendingMicrophone ?: return
        pendingMicrophone = null
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ASKED, true).apply()
        pending.success(
            grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        )
    }

    private fun hasMicrophone(): Boolean =
        activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun wasAsked(): Boolean =
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ASKED, false)

    private fun requestMicrophone(result: MethodChannel.Result) {
        if (hasMicrophone()) {
            result.success(true)
            return
        }
        if (pendingMicrophone != null) {
            // Une demande est déjà affichée.
            result.success(false)
            return
        }
        pendingMicrophone = result
        activity.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_CODE)
    }

    /** Composeur du téléphone sur le numéro du SUPPORT NetBuis (écran d'aide). */
    private fun dial(phone: String?, result: MethodChannel.Result) {
        if (phone.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            activity.startActivity(Intent(Intent.ACTION_DIAL, Uri.fromParts("tel", phone, null)))
            result.success(true)
        } catch (e: ActivityNotFoundException) {
            result.success(false)
        }
    }

    /**
     * Ouvre le lien dans WhatsApp. Réponses : "opened", "not_installed", "failed" (jamais le lien).
     * L'intention vise explicitement le paquet de WhatsApp : sans WhatsApp, rien ne s'ouvre (pas de
     * repli navigateur, qui afficherait une page contenant le numéro).
     */
    private fun openWhatsapp(url: String?, result: MethodChannel.Result) {
        val uri = try {
            if (url.isNullOrBlank()) null else Uri.parse(url)
        } catch (e: RuntimeException) {
            null
        }
        if (uri == null || uri.scheme != "https" || uri.host != "wa.me") {
            result.success("failed")
            return
        }
        for (pkg in WHATSAPP_PACKAGES) {
            try {
                activity.startActivity(Intent(Intent.ACTION_VIEW, uri).setPackage(pkg))
                result.success("opened")
                return
            } catch (e: ActivityNotFoundException) {
                // Ce paquet n'est pas installé : on essaie le suivant.
            } catch (e: RuntimeException) {
                // Message de l'exception volontairement ignoré : il pourrait contenir le lien.
                result.success("failed")
                return
            }
        }
        result.success("not_installed")
    }
}

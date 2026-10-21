package cm.netbuis.netbuis

import android.Manifest
import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Appel téléphonique direct (canal "cm.netbuis/call"), côté Android.
 *
 * ZONE SENSIBLE : [placeCall] et [dial] reçoivent le numéro du commerçant. Règles :
 *  - ne JAMAIS le journaliser (aucun Log.*, aucun println), ni le mettre dans un message d'erreur ;
 *  - ne JAMAIS le stocker (ni SharedPreferences, ni champ de classe) : il n'existe que comme
 *    variable locale le temps de l'appel ;
 *  - les réponses vers Dart sont des mots simples ("placed", "no_account"…), jamais le numéro.
 *
 * [openWhatsapp] reçoit le lien wa.me, qui CONTIENT le numéro : mêmes règles (ni journal, ni
 * stockage, ni message d'erreur). Seul un lien https://wa.me/… est ouvert, et seulement dans
 * l'application WhatsApp (jamais dans un navigateur).
 *
 * Méthodes : permissions, requestPermissions, listSims, placeCall, dial, openWhatsapp.
 */
class CallChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val NAME = "cm.netbuis/call"
        const val REQUEST_CODE = 5201
        private const val PREFS = "netbuis_call"
        private const val KEY_ASKED = "permissions_asked"
        /** WhatsApp, puis WhatsApp Business. */
        private val WHATSAPP_PACKAGES = arrayOf("com.whatsapp", "com.whatsapp.w4b")
        private val PERMISSIONS = arrayOf(
            Manifest.permission.CALL_PHONE,
            Manifest.permission.READ_PHONE_STATE,
        )
    }

    /** Réponse en attente de la demande Android (une seule à la fois). */
    private var pendingPermissions: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissions" -> result.success(
                mapOf("granted" to hasAll(), "asked" to wasAsked())
            )
            "requestPermissions" -> requestPermissions(result)
            "listSims" -> listSims(result)
            "placeCall" -> placeCall(
                call.argument<String>("phone"),
                call.argument<String>("accountId"),
                result,
            )
            "dial" -> dial(call.argument<String>("phone"), result)
            "openWhatsapp" -> openWhatsapp(call.argument<String>("url"), result)
            else -> result.notImplemented()
        }
    }

    /** À appeler depuis MainActivity.onRequestPermissionsResult. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        val pending = pendingPermissions ?: return
        pendingPermissions = null
        // La demande Android a été faite une fois : on ne la refait plus (explication « une fois »).
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_ASKED, true).apply()
        pending.success(
            grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        )
    }

    private fun has(permission: String): Boolean =
        activity.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun hasAll(): Boolean = PERMISSIONS.all { has(it) }

    private fun wasAsked(): Boolean =
        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ASKED, false)

    private fun requestPermissions(result: MethodChannel.Result) {
        if (hasAll()) {
            result.success(true)
            return
        }
        if (pendingPermissions != null) {
            // Une demande est déjà affichée.
            result.success(false)
            return
        }
        pendingPermissions = result
        activity.requestPermissions(PERMISSIONS, REQUEST_CODE)
    }

    private fun telecom(): TelecomManager? =
        activity.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager

    /** Identifiant opaque d'un compte : composant + id, retrouvé tel quel au moment d'appeler. */
    private fun keyOf(handle: PhoneAccountHandle): String =
        handle.componentName.flattenToString() + "|" + handle.id

    /** Comptes de type SIM capables d'appeler. Exige READ_PHONE_STATE. */
    private fun simHandles(telecom: TelecomManager): List<PhoneAccountHandle> =
        telecom.callCapablePhoneAccounts.filter { handle ->
            telecom.getPhoneAccount(handle)
                ?.hasCapabilities(PhoneAccount.CAPABILITY_SIM_SUBSCRIPTION) == true
        }

    private fun listSims(result: MethodChannel.Result) {
        val telecom = telecom()
        if (telecom == null || !has(Manifest.permission.READ_PHONE_STATE)) {
            result.success(emptyList<Map<String, String>>())
            return
        }
        try {
            val telephony = activity.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            val sims = simHandles(telecom).map { handle ->
                // Noms donnés par le système : le libellé du compte (renommable par l'utilisateur)
                // et l'opérateur lu sur la SIM (API 26+). Dart décide de ce qu'ils veulent dire.
                val label = telecom.getPhoneAccount(handle)?.label?.toString() ?: ""
                val carrier = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    telephony?.createForPhoneAccountHandle(handle)?.simOperatorName ?: ""
                } else {
                    ""
                }
                mapOf("id" to keyOf(handle), "label" to label, "carrier" to carrier)
            }
            result.success(sims)
        } catch (e: SecurityException) {
            result.success(emptyList<Map<String, String>>())
        } catch (e: RuntimeException) {
            result.success(emptyList<Map<String, String>>())
        }
    }

    private fun placeCall(phone: String?, accountId: String?, result: MethodChannel.Result) {
        if (phone.isNullOrBlank()) {
            result.success("failed")
            return
        }
        if (!has(Manifest.permission.CALL_PHONE)) {
            result.success("no_permission")
            return
        }
        val telecom = telecom()
        if (telecom == null) {
            result.success("failed")
            return
        }
        try {
            val extras = Bundle()
            if (accountId != null) {
                // Lire les comptes exige READ_PHONE_STATE.
                if (!has(Manifest.permission.READ_PHONE_STATE)) {
                    result.success("no_permission")
                    return
                }
                val handle = simHandles(telecom).firstOrNull { keyOf(it) == accountId }
                if (handle == null) {
                    result.success("no_account")
                    return
                }
                extras.putParcelable(TelecomManager.EXTRA_PHONE_ACCOUNT_HANDLE, handle)
            }
            telecom.placeCall(Uri.fromParts(PhoneAccount.SCHEME_TEL, phone, null), extras)
            result.success("placed")
        } catch (e: SecurityException) {
            result.success("no_permission")
        } catch (e: RuntimeException) {
            // Message de l'exception volontairement ignoré : il pourrait contenir le numéro.
            result.success("failed")
        }
    }

    /** Repli : composeur du téléphone. Le numéro y est visible (avertissement affiché par Dart). */
    private fun dial(phone: String?, result: MethodChannel.Result) {
        if (phone.isNullOrBlank()) {
            result.success(false)
            return
        }
        try {
            activity.startActivity(
                Intent(Intent.ACTION_DIAL, Uri.fromParts(PhoneAccount.SCHEME_TEL, phone, null))
            )
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
                val intent = Intent(Intent.ACTION_VIEW, uri).setPackage(pkg)
                activity.startActivity(intent)
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

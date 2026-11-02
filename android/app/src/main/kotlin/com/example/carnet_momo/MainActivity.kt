package com.example.carnet_momo

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app.carnetmomo/contacts"
    private val PICK_CONTACT_REQUEST = 101
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "pickContact") {
                pendingResult = result
                val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                try {
                    startActivityForResult(intent, PICK_CONTACT_REQUEST)
                } catch (e: Exception) {
                    pendingResult?.error("PICK_FAILED", e.message, null)
                    pendingResult = null
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_CONTACT_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                val contactUri: Uri? = data.data
                if (contactUri != null) {
                    val projection = arrayOf(
                        ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                        ContactsContract.CommonDataKinds.Phone.NUMBER
                    )
                    var cursor: Cursor? = null
                    try {
                        cursor = contentResolver.query(contactUri, projection, null, null, null)
                        if (cursor != null && cursor.moveToFirst()) {
                            val nameIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                            val numberIndex = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                            val name = if (nameIndex >= 0) cursor.getString(nameIndex) else ""
                            val number = if (numberIndex >= 0) cursor.getString(numberIndex) else ""

                            val map = HashMap<String, String>()
                            map["name"] = name ?: ""
                            map["number"] = number ?: ""
                            pendingResult?.success(map)
                        } else {
                            pendingResult?.success(null)
                        }
                    } catch (e: Exception) {
                        pendingResult?.error("QUERY_FAILED", e.message, null)
                    } finally {
                        cursor?.close()
                    }
                } else {
                    pendingResult?.success(null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}

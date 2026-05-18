package bo.e2v.electropoint

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import android.content.SharedPreferences

class NfcHceService : HostApduService() {

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        if (commandApdu == null) return hexStringToByteArray("6F00")

        val hexCommand = bytesToHex(commandApdu)
        Log.d("NfcHceService", "Command received: $hexCommand")

        // SELECT AID command (00 A4 04 00)
        // We match F222222222 (which is 46 32 32 32 32 32 32 32 32 32 in hex or similar)
        // Actually, many readers send 00A40400 + [length] + [AID]
        if (hexCommand.startsWith("00A40400")) {
            val prefs = getSharedPreferences("nfc_prefs", MODE_PRIVATE)
            val tagValue = prefs.getString("assigned_tag", "UNKNOWN") ?: "UNKNOWN"
            Log.d("NfcHceService", "Responding with tag: $tagValue")

            // Convert tagValue (assumed Hex or String) to Byte Array
            // If it's a valid hex string (even length and 0-9A-F), we send raw bytes
            val tagBytes = if (tagValue.length % 2 == 0 && tagValue.all { it.isDigit() || it.uppercaseChar() in 'A'..'F' }) {
                hexStringToByteArray(tagValue)
            } else {
                tagValue.toByteArray()
            }

            // Return raw bytes + 9000 (Success)
            return (tagBytes + hexStringToByteArray("9000"))
        }

        return hexStringToByteArray("6F00") // Error
    }

    override fun onDeactivated(reason: Int) {
        Log.d("NfcHceService", "Deactivated: $reason")
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val hexArray = "0123456789ABCDEF".toCharArray()
        val hexChars = CharArray(bytes.size * 2)
        for (j in bytes.indices) {
            val v = bytes[j].toInt() and 0xFF
            hexChars[j * 2] = hexArray[v ushr 4]
            hexChars[j * 2 + 1] = hexArray[v and 0x0F]
        }
        return String(hexChars)
    }

    private fun hexStringToByteArray(s: String): ByteArray {
        val len = s.length
        val data = ByteArray(len / 2)
        var i = 0
        while (i < len) {
            data[i / 2] = ((Character.digit(s[i], 16) shl 4) + Character.digit(s[i + 1], 16)).toByte()
            i += 2
        }
        return data
    }
}


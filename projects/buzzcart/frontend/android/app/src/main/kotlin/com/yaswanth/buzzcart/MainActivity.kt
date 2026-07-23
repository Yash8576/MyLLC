package com.yaswanth.buzzcart

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        createMessagesNotificationChannel()
    }

    // High importance so message pushes heads-up/banner while the device is
    // unlocked elsewhere, matching the "messages" channel_id the backend
    // sends (see push_notifications.go) and the manifest's default channel.
    private fun createMessagesNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            "messages",
            "Messages",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "New chat messages"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager?.createNotificationChannel(channel)
    }
}

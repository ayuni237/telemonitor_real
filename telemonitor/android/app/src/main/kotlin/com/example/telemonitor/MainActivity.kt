package com.example.telemonitor

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The worker's notifications (red readings, reminders to measure, the
        // clinician's reviews) use this channel: high importance, so Android
        // shows them on top of the screen with a sound. Its id is the default
        // channel in AndroidManifest.xml and the one the worker names
        // (telemonitor-research, serve/worker.py, ALERT_CHANNEL).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "alerts",
                "Alerts and reminders",
                NotificationManager.IMPORTANCE_HIGH,
            )
            channel.description = "Readings that need attention, reminders to measure, and your clinician's reviews"
            // New messages (worker.py, MESSAGE_CHANNEL), apart: a person may
            // silence the messages and keep the alerts.
            val messages = NotificationChannel(
                "messages",
                "Messages",
                NotificationManager.IMPORTANCE_HIGH,
            )
            messages.description = "New messages from your clinician or your patients"
            getSystemService(NotificationManager::class.java)
                .createNotificationChannels(listOf(channel, messages))
        }
    }
}

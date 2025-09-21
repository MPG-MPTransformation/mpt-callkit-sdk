package com.metechvn.omicxvn

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.mpt.mpt_callkit.MptCallkitPlugin

class MyFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "MyFirebaseMessagingService"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "MyFirebaseMessagingService created")
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // super.onMessageReceived(remoteMessage)
        
        Log.d(TAG, "Message received from: ${remoteMessage.from}")
        Log.d(TAG, "Message data: ${remoteMessage.data}")
        Log.d(TAG, "Message notification: ${remoteMessage.notification}")
        
        // Handle data payload
        val data = remoteMessage.data
        if (data.isNotEmpty()) {
            Log.d(TAG, "Data payload: $data")
            MptCallkitPlugin.shared?.onMessageReceived(this, remoteMessage.data)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d(TAG, "New FCM token: $token")
        
        try {
            if (MptCallkitPlugin.shared != null) {
                Log.d(TAG, "Calling MptCallkitPlugin.onNewToken")
                MptCallkitPlugin.shared?.onNewToken(token)
            } else {
                Log.w(TAG, "MptCallkitPlugin.shared is null, cannot send token")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error calling MptCallkitPlugin.onNewToken", e)
        }
    }
}
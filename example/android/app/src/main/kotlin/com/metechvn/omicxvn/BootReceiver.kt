// package com.metechvn.omicxvn

// import android.content.BroadcastReceiver
// import android.content.Context
// import android.content.Intent
// import android.util.Log

// class BootReceiver : BroadcastReceiver() {
    
//     companion object {
//         private const val TAG = "BootReceiver"
//     }
    
//     override fun onReceive(context: Context, intent: Intent) {
//         when (intent.action) {
//             Intent.ACTION_BOOT_COMPLETED,
//             Intent.ACTION_MY_PACKAGE_REPLACED,
//             Intent.ACTION_PACKAGE_REPLACED -> {
//                 Log.d(TAG, "Boot completed or package replaced: ${intent.action}")
                
//                 // Restart Firebase messaging service if needed
//                 val serviceIntent = Intent(context, MyFirebaseMessagingService::class.java)
//                 context.startService(serviceIntent)
                
//                 Log.d(TAG, "Firebase messaging service restarted")
//             }
//         }
//     }
// }

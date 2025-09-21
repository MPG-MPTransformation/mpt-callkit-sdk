package com.metechvn.omicxvn

import io.flutter.embedding.android.FlutterActivity
import com.mpt.mpt_callkit.MptCallkitPlugin
import android.os.Bundle
import com.hiennv.flutter_callkit_incoming.CallkitEventCallback
import com.hiennv.flutter_callkit_incoming.FlutterCallkitIncomingPlugin

class MainActivity : FlutterActivity() {

    private var callkitEventCallback = object: CallkitEventCallback{
        override fun onCallEvent(event: CallkitEventCallback.CallEvent, callData: Bundle) {
            when (event) {
                CallkitEventCallback.CallEvent.ACCEPT -> {
                    println("SDK-Android: MainActivity - CallkitEventCallback.CallEvent.ACCEPT")
                    // Do something with answer
                    MptCallkitPlugin.shared?.onAccept()
                }
                CallkitEventCallback.CallEvent.DECLINE -> {
                    println("SDK-Android: MainActivity - CallkitEventCallback.CallEvent.DECLINE")
                    // Do something with decline
                    MptCallkitPlugin.shared?.onDecline()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        println("SDK-Android: MainActivity onCreate called")
        System.out.println("SDK-Android: MainActivity onCreate called - System.out")
        
        try {
            FlutterCallkitIncomingPlugin.registerEventCallback(callkitEventCallback)
            println("SDK-Android: CallkitEventCallback registered successfully")
        } catch (e: Exception) {
            println("SDK-Android: Error registering CallkitEventCallback: ${e.message}")
        }
        
        try {
            MptCallkitPlugin.shared?.onCreate()
            println("SDK-Android: MptCallkitPlugin.onCreate called successfully")
        } catch (e: Exception) {
            println("SDK-Android: Error calling MptCallkitPlugin.onCreate: ${e.message}")
        }
    }
    override fun onPause() {
        MptCallkitPlugin.shared?.onPause()
        super.onPause()
    }
    override fun onResume() {
        MptCallkitPlugin.shared?.onResume(this)
        super.onResume()
    }
    override fun onDestroy() {
        MptCallkitPlugin.shared?.onDestroy()
        FlutterCallkitIncomingPlugin.unregisterEventCallback(callkitEventCallback)
        super.onDestroy()
    }
}

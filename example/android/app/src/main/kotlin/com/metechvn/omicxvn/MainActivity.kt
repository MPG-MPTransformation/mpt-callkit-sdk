package com.metechvn.omicxvn

import io.flutter.embedding.android.FlutterActivity
import com.mpt.mpt_callkit.MptCallkitPlugin

class MainActivity : FlutterActivity() {
    override fun onPause() {
        MptCallkitPlugin.shared?.onPause()
        super.onPause()
    }
    override fun onResume() {
        MptCallkitPlugin.shared?.onResume()
        super.onResume()
    }
    override fun onDestroy() {
        MptCallkitPlugin.shared?.onDestroy()
        super.onDestroy()
    }
}

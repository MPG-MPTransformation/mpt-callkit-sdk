package com.mpt.mpt_callkit;

import android.Manifest;
import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentTransaction;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;

import androidx.annotation.IdRes;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;

import android.net.Uri;
import android.os.Build;
import android.os.Bundle;

import android.os.PowerManager;
import android.widget.RadioGroup;
import android.widget.Toast;

import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.mpt.mpt_callkit.PortSipService;


public class MainActivity extends Activity {

    public PortMessageReceiver receiver = null;
    public static MainActivity activity;
    private final int REQ_DANGERS_PERMISSION = 2;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        activity = this;
        receiver = new PortMessageReceiver();
        // setContentView(R.layout.main);

        IntentFilter filter = new IntentFilter();
        filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
        filter.addAction(PortSipService.CALL_CHANGE_ACTION);
        filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
        filter.addAction(PortSipService.ACTION_SIP_AUDIODEVICE);
        filter.addAction(PortSipService.ACTION_HANGOUT_SUCCESS);

        if(Build.VERSION.SDK_INT>=Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else{
            registerReceiver(receiver, filter);
        }

        // Fragment fragment = getFragmentManager().findFragmentById(R.id.video_fragment);

        // FragmentTransaction fTransaction = getFragmentManager().beginTransaction();
        // if(fragment!=null){
        //     fTransaction.show( fragment).commit();
        // }
    }

    @Override
    protected void onResume() {
        super.onResume();
        requestPermissions (this);
    }

    @Override
    protected void onDestroy() {
        if(receiver != null) {
            unregisterReceiver(receiver);
            receiver = null;
        }
        super.onDestroy();
    }

    //if you want app always keep run in background ,you need call this function to request ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS permission.
    public void startPowerSavePermissions(Activity activityContext){
        String packageName = activityContext.getPackageName();
        PowerManager pm = (PowerManager) activityContext.getSystemService(Context.POWER_SERVICE);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&!pm.isIgnoringBatteryOptimizations(packageName)){

            Intent intent = new Intent();
            intent.setAction(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
            intent.setData(Uri.parse("package:" + packageName));

            activityContext.startActivity(intent);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode,
                                           String permissions[], int[] grantResults) {
        switch (requestCode) {
            case REQ_DANGERS_PERMISSION:
                int i=0;
                for(int result:grantResults) {
                    if (result != PackageManager.PERMISSION_GRANTED) {
                        Toast.makeText(this, "you must grant the permission "+permissions[i], Toast.LENGTH_SHORT).show();
						i++;
                        stopService(new Intent(this,PortSipService.class));
                        System.exit(0);
                    }
                }
                break;
        }
    }

    boolean allowBack = false;

    public boolean isAllowBack() {
        return allowBack;
    }

    public void setAllowBack(boolean allowBack) {
        this.allowBack = allowBack;
    }

    @Override
    public void onBackPressed() {
        if (isAllowBack()) {
            super.onBackPressed();
        } else {
            // do something;
        }
    }


    private void switchContent(@IdRes int fragmentId) {
        Fragment fragment = getFragmentManager().findFragmentById(fragmentId);
        Fragment video_fragment = getFragmentManager().findFragmentById(R.id.video_fragment);

        FragmentTransaction fTransaction = getFragmentManager().beginTransaction();
        if(fragment!=null){
            fTransaction.show( fragment).commit();
        }
    }

    public void requestPermissions(Activity activity) {
        // Check if we have write permission
        if(	PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(activity, Manifest.permission.CAMERA)
                ||PackageManager.PERMISSION_GRANTED != ActivityCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO))
        {
            ActivityCompat.requestPermissions(activity,new String[]{
                            Manifest.permission.CAMERA,Manifest.permission.RECORD_AUDIO},
                    REQ_DANGERS_PERMISSION);
        }
    }

}

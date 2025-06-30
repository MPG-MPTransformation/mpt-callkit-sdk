package com.mpt.mpt_callkit.util;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import java.io.File;
import java.util.List;
import java.util.ArrayList;

public class ResourceMonitor {
    private static final String TAG = "ResourceMonitor";
    private static final int FD_WARNING_THRESHOLD = 800; // Cảnh báo khi gần đến giới hạn 1024
    private static final int FD_CRITICAL_THRESHOLD = 950; // Nguy hiểm - cần cleanup ngay
    private static final int MONITOR_INTERVAL = 30000; // 30 seconds

    private static ResourceMonitor instance;
    private Handler handler;
    private Context context;
    private boolean isMonitoring = false;
    private List<ResourceCleanupListener> listeners = new ArrayList<>();

    public interface ResourceCleanupListener {
        void onResourceCleanupNeeded(int currentFDCount, String reason);
    }

    private ResourceMonitor(Context context) {
        this.context = context;
        this.handler = new Handler(Looper.getMainLooper());
    }

    public static synchronized ResourceMonitor getInstance(Context context) {
        if (instance == null) {
            instance = new ResourceMonitor(context);
        }
        return instance;
    }

    public void addListener(ResourceCleanupListener listener) {
        if (!listeners.contains(listener)) {
            listeners.add(listener);
        }
    }

    public void removeListener(ResourceCleanupListener listener) {
        listeners.remove(listener);
    }

    public void startMonitoring() {
        if (!isMonitoring) {
            isMonitoring = true;
            handler.post(monitorRunnable);
            Log.i(TAG, "Resource monitoring started");
        }
    }

    public void stopMonitoring() {
        if (isMonitoring) {
            isMonitoring = false;
            handler.removeCallbacks(monitorRunnable);
            Log.i(TAG, "Resource monitoring stopped");
        }
    }

    private final Runnable monitorRunnable = new Runnable() {
        @Override
        public void run() {
            if (!isMonitoring)
                return;

            try {
                int fdCount = getCurrentFDCount();
                Log.d(TAG, "Current FD count: " + fdCount);

                if (fdCount >= FD_CRITICAL_THRESHOLD) {
                    Log.e(TAG, "CRITICAL: FD count reached " + fdCount + " - forcing cleanup");
                    notifyListeners(fdCount, "CRITICAL_FD_COUNT");
                } else if (fdCount >= FD_WARNING_THRESHOLD) {
                    Log.w(TAG, "WARNING: FD count reached " + fdCount + " - cleanup recommended");
                    notifyListeners(fdCount, "HIGH_FD_COUNT");
                }

                // Schedule next check
                handler.postDelayed(this, MONITOR_INTERVAL);

            } catch (Exception e) {
                Log.e(TAG, "Error during resource monitoring: " + e.getMessage());
                // Continue monitoring even if error occurs
                handler.postDelayed(this, MONITOR_INTERVAL);
            }
        }
    };

    private void notifyListeners(int fdCount, String reason) {
        for (ResourceCleanupListener listener : listeners) {
            try {
                listener.onResourceCleanupNeeded(fdCount, reason);
            } catch (Exception e) {
                Log.e(TAG, "Error notifying listener: " + e.getMessage());
            }
        }
    }

    private int getCurrentFDCount() {
        try {
            // Get process PID
            int pid = android.os.Process.myPid();

            // Count files in /proc/[pid]/fd/ directory
            File fdDir = new File("/proc/" + pid + "/fd");
            if (fdDir.exists() && fdDir.isDirectory()) {
                String[] files = fdDir.list();
                return files != null ? files.length : 0;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting FD count: " + e.getMessage());
        }
        return 0;
    }

    public int getFDCount() {
        return getCurrentFDCount();
    }

    public void forceGarbageCollection() {
        Log.i(TAG, "Forcing garbage collection");
        System.gc();
        System.runFinalization();

        // Wait a bit for GC to complete
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
package com.mpt.mpt_callkit.receiver;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import java.util.ArrayList;
import java.util.List;
import java.util.Iterator;
import java.lang.ref.WeakReference;

public class PortMessageReceiver extends BroadcastReceiver {
    public interface BroadcastListener {
        void onBroadcastReceiver(Intent intent);
    }

    /**
     * Wrapper class to track listeners with tags
     */
    private static class TaggedListener {
        final BroadcastListener listener;
        final String tag;

        TaggedListener(BroadcastListener listener, String tag) {
            this.listener = listener;
            this.tag = tag != null ? tag : "Untagged";
        }

        String getName() {
            String className = listener.getClass().getSimpleName();

            // Handle anonymous classes
            if (className.isEmpty()) {
                className = listener.getClass().getName();
                if (className.contains("$")) {
                    String[] parts = className.split("\\$");
                    if (parts.length > 1) {
                        className = parts[0].substring(parts[0].lastIndexOf('.') + 1) + "$" + parts[parts.length - 1];
                    }
                }
            }

            return tag + "(" + className + ")@" + Integer.toHexString(listener.hashCode());
        }
    }

    // Strong references for persistent/critical listeners with tags
    private List<TaggedListener> persistentListeners = new ArrayList<>();

    // Weak references for temporary listeners (like Fragments)
    private List<WeakReference<BroadcastListener>> temporaryListeners = new ArrayList<>();

    // Keep the original field for backward compatibility
    public BroadcastListener broadcastReceiver;

    @Override
    public void onReceive(Context context, Intent intent) {
        boolean handled = false;

        // Clean up stale weak references first
        cleanupStaleReferences();

        // First try to handle with the primary broadcastReceiver
        if (broadcastReceiver != null) {
            String primaryName = getListenerName(broadcastReceiver, "Primary");
            System.out
                    .println("SDK-Android: PortMessageReceiver onReceive - using primary broadcastReceiver: "
                            + primaryName);
            try {
                broadcastReceiver.onBroadcastReceiver(intent);
                handled = true;
            } catch (Exception e) {
                System.out.println(
                        "SDK-Android: PortMessageReceiver onReceive - primary listener error: " + e.getMessage());
            }
        }

        // If primary receiver is null or failed, try persistent listeners first
        if (!handled && !persistentListeners.isEmpty()) {
            System.out.println("SDK-Android: PortMessageReceiver onReceive - using persistent listeners ("
                    + persistentListeners.size() + " available)");
            // Debug: log all persistent listeners
            for (int i = 0; i < persistentListeners.size(); i++) {
                TaggedListener tl = persistentListeners.get(i);
                System.out.println("SDK-Android: PortMessageReceiver - Persistent listener [" + i + "]: " +
                        (tl != null ? tl.getName() : "null"));
            }
            boolean anyHandled = false;
            for (TaggedListener taggedListener : persistentListeners) {
                if (taggedListener.listener != null) {
                    try {
                        System.out.println(
                                "SDK-Android: PortMessageReceiver onReceive - trying persistent listener: "
                                        + taggedListener.getName());
                        taggedListener.listener.onBroadcastReceiver(intent);
                        anyHandled = true;
                        System.out.println(
                                "SDK-Android: PortMessageReceiver onReceive - persistent listener handled successfully");
                        // Don't break - continue to call all persistent listeners
                    } catch (Exception e) {
                        System.out.println(
                                "SDK-Android: PortMessageReceiver onReceive - persistent listener error: "
                                        + e.getMessage());
                    }
                }
            }
            handled = anyHandled;
        }

        // If still not handled, try temporary listeners
        if (!handled && !temporaryListeners.isEmpty()) {
            System.out.println("SDK-Android: PortMessageReceiver onReceive - using temporary listeners ("
                    + temporaryListeners.size() + " available)");
            boolean anyTempHandled = false;
            Iterator<WeakReference<BroadcastListener>> iterator = temporaryListeners.iterator();
            while (iterator.hasNext()) {
                WeakReference<BroadcastListener> weakRef = iterator.next();
                BroadcastListener listener = weakRef.get();

                if (listener != null) {
                    try {
                        String listenerName = getListenerName(listener, "Temporary");
                        System.out.println(
                                "SDK-Android: PortMessageReceiver onReceive - trying temporary listener: "
                                        + listenerName);
                        listener.onBroadcastReceiver(intent);
                        anyTempHandled = true;
                        System.out.println(
                                "SDK-Android: PortMessageReceiver onReceive - temporary listener handled successfully");
                        // Don't break - continue to call all temporary listeners
                    } catch (Exception e) {
                        System.out.println(
                                "SDK-Android: PortMessageReceiver onReceive - temporary listener error: "
                                        + e.getMessage());
                        // Remove invalid listener
                        iterator.remove();
                    }
                } else {
                    // Remove dead weak references
                    iterator.remove();
                }
            }
            handled = anyTempHandled;
        }

        if (!handled) {
            System.out.println(
                    "SDK-Android: PortMessageReceiver onReceive broadcastReceiver is null - no active listeners");
            String primaryName = getListenerName(broadcastReceiver, "Primary");
            System.out.println("SDK-Android: PortMessageReceiver - Primary receiver: " + primaryName);
            System.out.println("SDK-Android: PortMessageReceiver - Persistent listeners: " + persistentListeners.size()
                    + ", Temporary listeners: " + temporaryListeners.size());
            // Log the intent for debugging
            if (intent != null) {
                System.out.println("SDK-Android: PortMessageReceiver - unhandled intent action: " + intent.getAction());
            }
        }
    }

    /**
     * Add a persistent listener (strong reference - never garbage collected)
     * Use for critical listeners like Engine's fallback
     */
    public synchronized void addPersistentListener(BroadcastListener listener) {
        addPersistentListener(listener, null);
    }

    /**
     * Add a persistent listener with a tag for better identification
     */
    public synchronized void addPersistentListener(BroadcastListener listener, String tag) {
        if (listener == null)
            return;

        String listenerTag = tag != null ? tag : "Untagged";

        // Check if listener with the same tag already exists
        if (hasPersistentListenerWithTag(listenerTag)) {
            System.out.println("SDK-Android: PortMessageReceiver - persistent listener with tag '" + listenerTag
                    + "' already exists, skipping");
            return;
        }

        TaggedListener taggedListener = new TaggedListener(listener, listenerTag);
        persistentListeners.add(taggedListener);
        System.out.println("SDK-Android: PortMessageReceiver - added persistent listener: " + taggedListener.getName()
                + ", total persistent: " + persistentListeners.size());
    }

    /**
     * Check if a persistent listener with the given tag already exists
     */
    private boolean hasPersistentListenerWithTag(String tag) {
        for (TaggedListener taggedListener : persistentListeners) {
            if (taggedListener.tag.equals(tag)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Remove persistent listener by tag
     */
    public synchronized void removePersistentListenerByTag(String tag) {
        Iterator<TaggedListener> iterator = persistentListeners.iterator();
        while (iterator.hasNext()) {
            TaggedListener taggedListener = iterator.next();
            if (taggedListener.tag.equals(tag)) {
                iterator.remove();
                System.out.println("SDK-Android: PortMessageReceiver - removed persistent listener by tag: " + tag
                        + ", remaining: " + persistentListeners.size());
                return;
            }
        }
        System.out.println(
                "SDK-Android: PortMessageReceiver - persistent listener with tag '" + tag + "' not found for removal");
    }

    /**
     * Add a temporary listener (weak reference - can be garbage collected)
     * Use for Fragment/Activity listeners
     */
    public synchronized void addTemporaryListener(BroadcastListener listener) {
        addTemporaryListener(listener, null);
    }

    /**
     * Add a temporary listener with a tag for better identification
     */
    public synchronized void addTemporaryListener(BroadcastListener listener, String tag) {
        if (listener == null)
            return;

        // Check if listener already exists to prevent duplicates
        if (containsTemporaryListener(listener)) {
            String listenerName = getListenerName(listener, tag);
            System.out.println(
                    "SDK-Android: PortMessageReceiver - temporary listener already exists, skipping: " + listenerName);
            return;
        }

        temporaryListeners.add(new WeakReference<>(listener));
        String listenerName = getListenerName(listener, tag);
        System.out.println("SDK-Android: PortMessageReceiver - added temporary listener: " + listenerName
                + ", total temporary: " + temporaryListeners.size());
    }

    /**
     * Generic add listener method (defaults to temporary for backward
     * compatibility)
     */
    public synchronized void addListener(BroadcastListener listener) {
        addTemporaryListener(listener, null);
    }

    /**
     * Remove a listener (from both persistent and temporary lists)
     */
    public synchronized void removeListener(BroadcastListener listener) {
        if (listener == null)
            return;

        boolean removed = false;
        String listenerName = getListenerName(listener, null);

        // Remove from persistent listeners
        Iterator<TaggedListener> persistentIterator = persistentListeners.iterator();
        while (persistentIterator.hasNext()) {
            TaggedListener taggedListener = persistentIterator.next();
            if (taggedListener.listener == listener) {
                persistentIterator.remove();
                System.out.println("SDK-Android: PortMessageReceiver - removed persistent listener: " + listenerName
                        + ", remaining persistent: " + persistentListeners.size());
                removed = true;
                break;
            }
        }

        // Remove from temporary listeners
        Iterator<WeakReference<BroadcastListener>> iterator = temporaryListeners.iterator();
        while (iterator.hasNext()) {
            WeakReference<BroadcastListener> weakRef = iterator.next();
            BroadcastListener existingListener = weakRef.get();

            if (existingListener == null || existingListener == listener) {
                iterator.remove();
                if (existingListener == listener) {
                    System.out.println("SDK-Android: PortMessageReceiver - removed temporary listener: " + listenerName
                            + ", remaining temporary: " + temporaryListeners.size());
                    removed = true;
                }
            }
        }

        if (!removed) {
            System.out.println("SDK-Android: PortMessageReceiver - listener not found for removal: " + listenerName);
        }
    }

    /**
     * Set primary receiver (add as temporary listener for backup)
     */
    public void setPrimaryReceiver(BroadcastListener listener) {
        // Only add as backup if it's not already the primary
        if (listener != null && listener != this.broadcastReceiver) {
            addTemporaryListener(listener, "Primary");
        }

        this.broadcastReceiver = listener;
        String listenerName = getListenerName(listener, "Primary");
        System.out.println("SDK-Android: PortMessageReceiver - set primary receiver: " + listenerName);
    }

    /**
     * Check if listener already exists in temporary list
     */
    private boolean containsTemporaryListener(BroadcastListener listener) {
        if (listener == null)
            return false;

        for (WeakReference<BroadcastListener> weakRef : temporaryListeners) {
            BroadcastListener existingListener = weakRef.get();
            if (existingListener == listener) {
                return true;
            }
        }
        return false;
    }

    /**
     * Clean up stale weak references
     */
    private void cleanupStaleReferences() {
        Iterator<WeakReference<BroadcastListener>> iterator = temporaryListeners.iterator();
        int removedCount = 0;

        while (iterator.hasNext()) {
            WeakReference<BroadcastListener> weakRef = iterator.next();
            if (weakRef.get() == null) {
                iterator.remove();
                removedCount++;
            }
        }

        if (removedCount > 0) {
            System.out.println("SDK-Android: PortMessageReceiver - cleaned up " + removedCount
                    + " stale temporary references, remaining: " + temporaryListeners.size());
        }
    }

    /**
     * Get current listeners count for debugging
     */
    public int getListenersCount() {
        cleanupStaleReferences();
        return persistentListeners.size() + temporaryListeners.size();
    }

    /**
     * Get detailed listeners info for debugging
     */
    public String getListenersInfo() {
        cleanupStaleReferences();
        return "Persistent: " + persistentListeners.size() + ", Temporary: " + temporaryListeners.size();
    }

    /**
     * Clear all listeners
     */
    public synchronized void clearListeners() {
        int persistentCount = persistentListeners.size();
        int temporaryCount = temporaryListeners.size();

        persistentListeners.clear();
        temporaryListeners.clear();

        System.out.println("SDK-Android: PortMessageReceiver - cleared " + persistentCount + " persistent and "
                + temporaryCount + " temporary listeners");
    }

    /**
     * Get a descriptive name for a listener (handles anonymous classes)
     */
    private String getListenerName(BroadcastListener listener, String tag) {
        if (listener == null)
            return "null";

        String className = listener.getClass().getSimpleName();

        // Handle anonymous classes
        if (className.isEmpty()) {
            className = listener.getClass().getName();
            // Extract meaningful part from anonymous class name
            if (className.contains("$")) {
                String[] parts = className.split("\\$");
                if (parts.length > 1) {
                    className = parts[0].substring(parts[0].lastIndexOf('.') + 1) + "$" + parts[parts.length - 1];
                }
            }
        }

        // Add tag if provided
        if (tag != null && !tag.isEmpty()) {
            className = tag + "(" + className + ")";
        }

        // Add object hash for unique identification
        className += "@" + Integer.toHexString(listener.hashCode());

        return className;
    }
}

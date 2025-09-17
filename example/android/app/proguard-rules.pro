# Keep WebRTC classes
-keep class org.webrtc.** { *; }
-keep class com.portsip.** { *; }
-keep class org.webrtc.WebRtcClassLoader { *; }

# Specifically keep the WebRtcClassLoader class and its methods
-keepnames class org.webrtc.WebRtcClassLoader
-keepclassmembers class org.webrtc.WebRtcClassLoader {
    <methods>;
    <fields>;
    <init>();
}

# Keep JNI methods
-keepclasseswithmembers class * {
    native <methods>;
}

# Keep methods called from native code
-keepclassmembers class org.webrtc.** {
    <methods>;
    <fields>;
}

# Keep all classes in the SDK
-keep class com.mpt.mpt_callkit.** { *; }
-keep class com.portsip.PortSipSdk { *; }
-keep class com.portsip.** { *; }

# Don't warn about missing classes from the Android SDK
-dontwarn android.support.**
-dontwarn org.webrtc.**

# Keep all serializable classes
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep the R class
-keepclassmembers class **.R$* {
    public static <fields>;
}

#flutter_callkit_incoming
# Issue: https://github.com/hiennguyen92/flutter_callkit_incoming/issues/171
-keep class com.fasterxml.** { *; }
-dontwarn com.fasterxml.jackson.**

-keepattributes *Annotation*

-keepclassmembers class * {
    @com.fasterxml.jackson.annotation.* <fields>;
    @com.fasterxml.jackson.annotation.* <methods>;
}

-keepclassmembers class * {
    public <init>();
}

-keep class com.hiennv.flutter_callkit_incoming.** { *; }
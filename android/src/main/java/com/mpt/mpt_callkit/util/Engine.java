package com.mpt.mpt_callkit.util;
import android.text.TextUtils;
import com.portsip.PortSipSdk;
import com.portsip.PortSipEnumDefine;

public class Engine {
    private static Engine mInstance;
    private PortSipSdk mEngine;
    public boolean mConference= false;
    private static Object locker = new Object();
    public boolean mUseFrontCamera= false;

    public static Engine Instance()
    {
        if (mInstance == null)
        {
            synchronized (locker)
            {
                if (mInstance == null)
                {
                    mInstance = new Engine();
                }
            }
        }

        return mInstance;
    }

    public void setEngine(PortSipSdk obj){
        mEngine = obj;
        mEngine.clearAudioCodec();
        mEngine.addAudioCodec(PortSipEnumDefine.ENUM_AUDIOCODEC_PCMA);
        mEngine.addAudioCodec(PortSipEnumDefine.ENUM_AUDIOCODEC_PCMU);
        mEngine.addAudioCodec(PortSipEnumDefine.ENUM_AUDIOCODEC_G729);

        mEngine.clearVideoCodec();
        mEngine.addVideoCodec(PortSipEnumDefine.ENUM_VIDEOCODEC_H264);
        mEngine.addVideoCodec(PortSipEnumDefine.ENUM_VIDEOCODEC_VP8);
        mEngine.addVideoCodec(PortSipEnumDefine.ENUM_VIDEOCODEC_VP9);

        mEngine.setVideoNackStatus(true);

        mEngine.enableAEC(true);
        mEngine.enableAGC(true);
        mEngine.enableCNG(true);
        mEngine.enableVAD(true);
        mEngine.enableANS(false);

        boolean foward = false;
        boolean fowardBusy = false;
        String fowardto = null;
        if (foward && !TextUtils.isEmpty(fowardto)) {
            mEngine.enableCallForward(fowardBusy, fowardto);
        }

        mEngine.setReliableProvisional(0);

        String resolution = "CIF";
        int width = 352;
        int height = 288;
        if (resolution.equals("QCIF")) {
            width = 176;
            height = 144;
        } else if (resolution.equals("CIF")) {
            width = 352;
            height = 288;
        } else if (resolution.equals("VGA")) {
            width = 640;
            height = 480;
        } else if (resolution.equals("720P")) {
            width = 1280;
            height = 720;
        } else if (resolution.equals("1080P")) {
            width = 1920;
            height = 1080;
        }

        mEngine.setVideoResolution(width, height);
    }

    public PortSipSdk getEngine(){
        return mEngine;
    }
}

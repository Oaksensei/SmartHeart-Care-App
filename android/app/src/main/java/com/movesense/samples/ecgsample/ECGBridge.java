package com.movesense.samples.ecgsample;

import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.MethodChannel;

public class ECGBridge {
    private static MethodChannel channel;
    private static final Handler uiThreadHandler = new Handler(Looper.getMainLooper());

    public static void setChannel(MethodChannel methodChannel) {
        channel = methodChannel;
    }

    public static void sendSample(final int sample) {
        if (channel != null) {
            uiThreadHandler.post(new Runnable() {
                @Override
                public void run() {
                    channel.invokeMethod("ecgSample", sample);
                }
            });
        }
    }

    public static void sendHR(final int hr) {
        if (channel != null) {
            uiThreadHandler.post(new Runnable() {
                @Override
                public void run() {
                    channel.invokeMethod("hrSample", hr);
                }
            });
        }
    }
}

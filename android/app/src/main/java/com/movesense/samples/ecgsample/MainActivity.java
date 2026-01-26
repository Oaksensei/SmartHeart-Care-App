package com.movesense.samples.ecgsample;

import android.os.Bundle;
import android.util.Log;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import androidx.annotation.NonNull;

import com.google.gson.Gson;
import com.movesense.mds.Mds;
import com.movesense.mds.MdsConnectionListener;
import com.movesense.mds.MdsException;
import com.movesense.mds.MdsNotificationListener;
import com.movesense.mds.MdsSubscription;

public class MainActivity extends FlutterActivity implements MdsConnectionListener {
    private static final String CHANNEL = "ecg_channel";
    private static final String LOG_TAG = "MainActivity";

    // Movesense constants
    public static final String SCHEME_PREFIX = "suunto://";
    public static final String URI_EVENTLISTENER = "suunto://MDS/EventListener";
    public static final String URI_ECG_ROOT = "/Meas/ECG/";

    public static com.movesense.mds.Mds mMds;

    // State
    private String mConnectedSerial;
    private MdsSubscription mECGSubscription;
    private MdsSubscription mHRSubscription;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        MethodChannel channel = new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL);
        ECGBridge.setChannel(channel);

        channel.setMethodCallHandler(
                (call, result) -> {
                    switch (call.method) {
                        case "connect":
                            String macAddress = call.argument("address");
                            if (macAddress != null) {
                                Log.i(LOG_TAG, "Connecting to: " + macAddress);
                                mMds.connect(macAddress, this);
                                result.success(null);
                            } else {
                                result.error("INVALID_ARGS", "Address is null", null);
                            }
                            break;

                        case "disconnect":
                            String macToDisco = call.argument("address");
                            if (macToDisco != null) {
                                mMds.disconnect(macToDisco);
                                result.success(null);
                            } else {
                                // Fallback try disconnect current
                                if (mConnectedSerial != null) {
                                    // NOTE: Movesense disconnect usually takes MAC, not Serial.
                                    // But if we don't have mac handy, we might be stuck.
                                    // For now, assume Flutter passes MAC.
                                    result.success(null);
                                }
                            }
                            break;

                        case "startECG": // Reusing this name for start streaming
                            int sampleRate = 125;
                            if (call.hasArgument("sampleRate")) {
                                sampleRate = call.argument("sampleRate");
                            }
                            startCollection(sampleRate);
                            result.success(null);
                            break;

                        case "stopECG":
                            stopCollection();
                            result.success(null);
                            break;

                        default:
                            result.notImplemented();
                            break;
                    }
                });
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mMds = new com.movesense.mds.Mds.Builder().build(this);
    }

    // -- MDS Subscription Logic (From ECGActivity) --

    private void startCollection(int sampleRate) {
        if (mConnectedSerial == null) {
            Log.e(LOG_TAG, "Cannot start ECG: No device connected");
            return;
        }

        stopCollection(); // Safety clear

        // /Meas/ECG/125
        StringBuilder sb = new StringBuilder();
        String strContract = sb.append("{\"Uri\": \"")
                .append(mConnectedSerial)
                .append(URI_ECG_ROOT)
                .append(sampleRate)
                .append("\"}")
                .toString();

        Log.d(LOG_TAG, "Subscribing to: " + strContract);

        mECGSubscription = mMds.builder().build(this).subscribe(URI_EVENTLISTENER,
                strContract, new MdsNotificationListener() {
                    @Override
                    public void onNotification(String data) {
                        // Log.d(LOG_TAG, "ECG Data: " + data);
                        ECGResponse ecgResponse = new Gson().fromJson(data, ECGResponse.class);
                        if (ecgResponse != null) {
                            for (int sample : ecgResponse.body.samples) {
                                ECGBridge.sendSample(sample);
                            }
                        }
                    }

                    @Override
                    public void onError(MdsException error) {
                        Log.e(LOG_TAG, "Subscription Error: ", error);
                    }
                });

        // Also subscribe to Heart Rate
        enableHRSubscription();
    }

    private void enableHRSubscription() {
        if (mConnectedSerial == null)
            return;

        unsubscribeHR();

        // /Meas/HR
        String strContract = "{\"Uri\": \"" + mConnectedSerial + "/Meas/HR\"}";
        Log.d(LOG_TAG, "Subscribing HR to: " + strContract);

        mHRSubscription = mMds.builder().build(this).subscribe(URI_EVENTLISTENER,
                strContract, new MdsNotificationListener() {
                    @Override
                    public void onNotification(String data) {
                        Log.d(LOG_TAG, "HR Data: " + data);
                        HRResponse hrResponse = new Gson().fromJson(data, HRResponse.class);
                        if (hrResponse != null) {
                            int hr = (int) hrResponse.body.average;
                            ECGBridge.sendHR(hr);
                        }
                    }

                    @Override
                    public void onError(MdsException error) {
                        Log.e(LOG_TAG, "HR Subscription Error: ", error);
                    }
                });
    }

    private void stopCollection() {
        if (mECGSubscription != null) {
            mECGSubscription.unsubscribe();
            mECGSubscription = null;
        }
        unsubscribeHR();
    }

    private void unsubscribeHR() {
        if (mHRSubscription != null) {
            mHRSubscription.unsubscribe();
            mHRSubscription = null;
        }
    }

    // -- MDS Connection Listeners --

    @Override
    public void onConnect(String s) {
        Log.d(LOG_TAG, "onConnect: " + s);
    }

    @Override
    public void onConnectionComplete(String macAddress, String serial) {
        Log.d(LOG_TAG, "onConnectionComplete: " + serial);
        mConnectedSerial = serial;
        // Optionally notify Flutter that connection is ready?
        // For now, Flutter waits for the Future to complete (which returns immediately
        // on 'connect' call),
        // but 'onConnectionComplete' happens asynchronously.
        // Ideal: Send event to channel "onConnected".
        // For simple MVP: User presses Connect, we return success, but actual
        // connection happens async.
        // We can trust Movesense is fast or UI handles "Connecting..." state.

        // Let's send a message to Flutter
        runOnUiThread(() -> {
            // We could use channel.invokeMethod here if we had ref to it class-wide
            // But existing ECGBridge is static?
            // Since ECGBridge is for Stream -> Flutter, let's stick to that for data.
            // For Connection status, maybe just toast for now or rely on no errors.
        });
    }

    @Override
    public void onError(MdsException e) {
        Log.e(LOG_TAG, "Connection Error: ", e);
    }

    @Override
    public void onDisconnect(String bleAddress) {
        Log.d(LOG_TAG, "onDisconnect: " + bleAddress);
        mConnectedSerial = null;
        stopCollection();
    }
}

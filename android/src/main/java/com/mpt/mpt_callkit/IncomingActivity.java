package com.mpt.mpt_callkit;

import android.app.Activity;
import android.app.Fragment;
import android.app.FragmentTransaction;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.TextView;
import android.widget.Toast;

import com.mpt.mpt_callkit.util.Engine;
import com.portsip.PortSipErrorcode;
import com.mpt.mpt_callkit.receiver.PortMessageReceiver;
import com.mpt.mpt_callkit.PortSipService;
import com.mpt.mpt_callkit.util.CallManager;
import com.mpt.mpt_callkit.util.Ring;
import com.mpt.mpt_callkit.util.Session;
import com.mpt.mpt_callkit.MainActivity;

import androidx.annotation.Nullable;

import static com.mpt.mpt_callkit.PortSipService.EXTRA_CALL_SEESIONID;

public class IncomingActivity extends Activity implements PortMessageReceiver.BroadcastListener, View.OnClickListener {

    public PortMessageReceiver receiver = null;
    private boolean isReceiverRegistered = false; // Add flag to track receiver registration
    TextView tvTips;
    Button btnVideo;
    long sessionId;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        System.out.println("quanth: IncomingActivity - onCreate");

        setContentView(R.layout.incomingview);
        final Window win = getWindow();
        win.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                | WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                | WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON);

        tvTips = findViewById(R.id.sessiontips);
        btnVideo = findViewById(R.id.answer_video);

        // Use Engine's shared receiver instead of creating a new one
        receiver = Engine.Instance().getReceiver();
        if (receiver == null) {
            receiver = new PortMessageReceiver();
            Engine.Instance().setReceiver(receiver);
        }

        // Only register if not already registered to prevent multiple registrations
        if (!isReceiverRegistered && receiver != null) {
            IntentFilter filter = new IntentFilter();
            filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
            filter.addAction(PortSipService.CALL_CHANGE_ACTION);
            filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);
            System.out.println("quanth: IncomingActivity - Registering broadcast receiver (using Engine's receiver)");

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                    System.out.println("quanth: IncomingActivity - Registered with RECEIVER_NOT_EXPORTED flag");
                } else {
                    registerReceiver(receiver, filter);
                    System.out.println("quanth: IncomingActivity - Registered without flag");
                }
                isReceiverRegistered = true;
            } catch (Exception e) {
                System.out.println("quanth: IncomingActivity - Error registering receiver: " + e.getMessage());
                isReceiverRegistered = false;
            }
        } else {
            System.out.println("quanth: IncomingActivity - Receiver already registered or is null");
        }

        // Set as primary receiver and add as backup
        receiver.setPrimaryReceiver(this);
        System.out.println("quanth: broadcastReceiver - IncomingActivity - set as primary: " + this.toString());

        Intent intent = getIntent();

        findViewById(R.id.hangup_call).setOnClickListener(this);
        findViewById(R.id.answer_audio).setOnClickListener(this);
        btnVideo.setOnClickListener(this);

        sessionId = intent.getLongExtra(EXTRA_CALL_SEESIONID, PortSipErrorcode.INVALID_SESSION_ID);
        System.out.println("quanth: IncomingActivity - Received sessionId: " + sessionId);
        Session session = CallManager.Instance().findSessionBySessionID(sessionId);
        if (sessionId == PortSipErrorcode.INVALID_SESSION_ID || session == null
                || session.state != Session.CALL_STATE_FLAG.INCOMING) {
            System.out.println("quanth: IncomingActivity - Invalid session, finishing activity");
            this.finish();
            return;
        }

        System.out.println("quanth: IncomingActivity - Setting up for call from: " + session.remote);
        tvTips.setText(session.lineName + "   " + session.remote);
        setVideoAnswerVisibility(session);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);

        long sessionid = intent.getLongExtra("incomingSession", PortSipErrorcode.INVALID_SESSION_ID);
        Session session = CallManager.Instance().findSessionBySessionID(sessionid);
        if (sessionId != PortSipErrorcode.INVALID_SESSION_ID && session != null) {
            sessionId = sessionid;
            setVideoAnswerVisibility(session);
            tvTips.setText(session.lineName + "   " + session.remote);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();

        // Ensure receiver is still registered
        if (receiver != null && !isReceiverRegistered) {
            System.out.println("quanth: IncomingActivity - Receiver lost in onResume, attempting to re-register");
            // Re-register if needed
            IntentFilter filter = new IntentFilter();
            filter.addAction(PortSipService.REGISTER_CHANGE_ACTION);
            filter.addAction(PortSipService.CALL_CHANGE_ACTION);
            filter.addAction(PortSipService.PRESENCE_CHANGE_ACTION);

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
                } else {
                    registerReceiver(receiver, filter);
                }
                isReceiverRegistered = true;
                System.out.println("quanth: IncomingActivity - Re-registered receiver in onResume");
            } catch (Exception e) {
                System.out.println(
                        "quanth: IncomingActivity - Error re-registering receiver in onResume: " + e.getMessage());
            }
        }
    }

    @Override
    public void onBackPressed() {
        super.onBackPressed();
        this.finish();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();

        // Remove this activity as listener and clear primary if it's this activity
        if (receiver != null) {
            receiver.removeListener(this);
            if (receiver.broadcastReceiver == this) {
                receiver.broadcastReceiver = null;
            }
            System.out.println("quanth: IncomingActivity - Removed as listener on destroy");

            // Only unregister if this activity registered the receiver
            if (isReceiverRegistered) {
                try {
                    unregisterReceiver(receiver);
                    isReceiverRegistered = false;
                    System.out.println("quanth: IncomingActivity - Unregistered receiver successfully");
                } catch (IllegalArgumentException e) {
                    System.out.println("quanth: IncomingActivity - Receiver was not registered: " + e.getMessage());
                    isReceiverRegistered = false;
                } catch (Exception e) {
                    System.out.println("quanth: IncomingActivity - Error unregistering receiver: " + e.getMessage());
                    isReceiverRegistered = false;
                }
            } else {
                System.out.println("quanth: IncomingActivity - Receiver was not registered by this activity");
            }
        } else {
            System.out.println("quanth: IncomingActivity - Receiver is null, nothing to unregister");
        }

        startActivity(new Intent(this, MainActivity.class));
    }

    @Override
    public void onBroadcastReceiver(Intent intent) {
        System.out.println("quanth: IncomingActivity - onBroadcastReceiver received intent");
        String action = intent.getAction();
        System.out.println("quanth: IncomingActivity - Action: " + action);

        if (PortSipService.CALL_CHANGE_ACTION.equals(action)) {
            long sessionId = intent.getLongExtra(EXTRA_CALL_SEESIONID, Session.INVALID_SESSION_ID);
            String status = intent.getStringExtra(PortSipService.EXTRA_CALL_DESCRIPTION);
            System.out.println(
                    "quanth: IncomingActivity - CALL_CHANGE_ACTION - sessionId: " + sessionId + ", status: " + status);

            Session session = CallManager.Instance().findSessionBySessionID(sessionId);
            if (session != null) {
                System.out.println("quanth: IncomingActivity - Session state: " + session.state);
                switch (session.state) {
                    case INCOMING:
                        System.out.println("quanth: IncomingActivity - Call state: INCOMING");
                        break;
                    case TRYING:
                        System.out.println("quanth: IncomingActivity - Call state: TRYING");
                        break;
                    case CONNECTED:
                        System.out.println("quanth: IncomingActivity - Call state: CONNECTED");
                    case FAILED:
                        System.out.println("quanth: IncomingActivity - Call state: FAILED");
                    case CLOSED:
                        System.out.println("quanth: IncomingActivity - Call state: CLOSED");
                        Session anOthersession = CallManager.Instance().findIncomingCall();
                        if (anOthersession == null) {
                            System.out.println("quanth: IncomingActivity - No other incoming call, finishing");
                            this.finish();
                        } else {
                            System.out.println("quanth: IncomingActivity - Found another incoming call: "
                                    + anOthersession.sessionID);
                            setVideoAnswerVisibility(anOthersession);
                            tvTips.setText(anOthersession.lineName + "   " + anOthersession.remote);
                            sessionId = anOthersession.sessionID;
                        }
                        break;

                }
            } else {
                System.out.println("quanth: IncomingActivity - Session is null for sessionId: " + sessionId);
            }
        }
    }

    @Override
    public void onClick(View view) {
        if (Engine.Instance().getEngine() != null) {
            ((NotificationManager) getSystemService(NOTIFICATION_SERVICE))
                    .cancel(PortSipService.PENDINGCALL_NOTIFICATION);
            Session currentLine = CallManager.Instance().findSessionBySessionID(sessionId);
            if (view.getId() == R.id.answer_audio || view.getId() == R.id.answer_video) {
                if (currentLine.state != Session.CALL_STATE_FLAG.INCOMING) {
                    Toast.makeText(this, currentLine.lineName + "No incoming call on current line", Toast.LENGTH_SHORT);
                    return;
                }
                Ring.getInstance(this).stopRingTone();
                currentLine.state = Session.CALL_STATE_FLAG.CONNECTED;
                int ret = Engine.Instance().getEngine().answerCall(sessionId, true);
                if (ret != 0) {
                    Toast.makeText(this, "answerCall Failed! ret=" + ret, Toast.LENGTH_SHORT);
                }
                Engine.Instance().getEngine().joinToConference(currentLine.sessionID);
            } else if (view.getId() == R.id.hangup_call) {
                Ring.getInstance(this).stop();
                if (currentLine.state == Session.CALL_STATE_FLAG.INCOMING) {
                    Engine.Instance().getEngine().rejectCall(currentLine.sessionID, 486);
                    currentLine.Reset();
                    Toast.makeText(this, currentLine.lineName + ": Rejected call", Toast.LENGTH_SHORT);
                }
            }
        }

        Session anOthersession = CallManager.Instance().findIncomingCall();
        if (anOthersession == null) {
            this.finish();
        } else {
            sessionId = anOthersession.sessionID;
            setVideoAnswerVisibility(anOthersession);
        }

    }

    private void setVideoAnswerVisibility(Session session) {
        if (session == null)
            return;
        if (session.hasVideo) {
            btnVideo.setVisibility(View.VISIBLE);
        } else {
            btnVideo.setVisibility(View.GONE);
        }
    }

}

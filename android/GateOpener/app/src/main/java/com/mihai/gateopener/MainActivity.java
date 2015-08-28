package com.mihai.gateopener;


import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.nsd.NsdManager;
import android.net.nsd.NsdServiceInfo;
import android.os.AsyncTask;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.text.Editable;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONException;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Vector;

import javax.net.ssl.HttpsURLConnection;

public class MainActivity extends AppCompatActivity {
    private String TAG = "discovery";
    private NsdManager.DiscoveryListener mDiscoveryListener = null;
    private NsdManager mNsdManager = null;
    private boolean mHaveService = false;
    private String mServiceHost = null;
    private String mServicePort = null;
    private Vector<Button> mButtons = new Vector<Button>();

    private ResponseProcessor createConfigurator() {
        ResponseProcessor configurator = new ResponseProcessor() {
            @Override
            public void processResponse(String response) {
                if (response == null) {
                    addLogLine("Configuration failed.");
                    // start again with discovery
                    MainActivity.this.runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
//                            discoverServices();
                            for (Button button : mButtons) {
                                button.setEnabled(false);
                                button.setVisibility(View.INVISIBLE);
                            }
                        }
                    });
                } else {
                    try {
                        addLogLine("Configuration OK.");

                        JSONArray jsonArray = new JSONArray(response);

                        for (int i = 0; i < jsonArray.length(); i++) {
                            if (i >= mButtons.size()) break;
                            final int index = i;
                            final String btnText = jsonArray.getString(i);
                            MainActivity.this.runOnUiThread(new Runnable() {
                                @Override
                                public void run() {
                                    mButtons.elementAt(index).setText(btnText);
                                    mButtons.elementAt(index).setEnabled(true);
                                    mButtons.elementAt(index).setVisibility(View.VISIBLE);
                                }
                            });

                        }
                    } catch (JSONException ex) {
                    }
                }
            }
        };
        return configurator;
    }

    private ResponseProcessor createClickFinalizer() {
        return new ResponseProcessor() {
            @Override
            public void processResponse(String response) {
                Log.d(TAG, "after click: " + response);
                MainActivity.this.runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        TextView indicator = (TextView) findViewById(R.id.indicator);
                        indicator.setBackgroundColor(Color.TRANSPARENT);
                        indicator.setTextColor(Color.BLACK);
                    }
                });
                // Do nothing.
            }
        };
    }

    private void saveSettings(String host, String port) {
        if (host == null || port == null) {
            return;
        }
        SharedPreferences prefs = getPreferences(MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("gateservice_host", host);
        editor.putString("gateservice_port", port);
        editor.commit();
    }

    private void loadSavedSettings() {
        SharedPreferences prefs = getPreferences(MODE_PRIVATE);
        if (prefs.contains("gateservice_host") && prefs.contains("gateservice_port")) {
            mServiceHost = prefs.getString("gateservice_host", null);
            mServicePort = prefs.getString("gateservice_port", null);
            new RequestTask(createConfigurator()).execute("http://" + mServiceHost + ":" + mServicePort + "/config");
        } else {
            discoverServices();
        }
    }
    private void discoverServices() {
        mDiscoveryListener = new NsdManager.DiscoveryListener() {
            //  Called as soon as service discovery begins.
            @Override
            public void onDiscoveryStarted(String regType) {
                Log.d(TAG, "Service discovery started");
                addLogLine("Service discovery started");
            }

            @Override
            public void onServiceFound(NsdServiceInfo service) {
                // A service was found!  Do something with it.
                Log.d(TAG, "Service discovery success" + service);
                addLogLine("Service discovery success" + service + ".");
                NsdManager.ResolveListener resolveListener = new NsdManager.ResolveListener() {
                    @Override
                    public void onResolveFailed(NsdServiceInfo nsdServiceInfo, int i) {
                        Log.d(TAG, "Service resolving failed:" + nsdServiceInfo);
                        addLogLine("SService resolving failed.");
                    }

                    @Override
                    public void onServiceResolved(NsdServiceInfo nsdServiceInfo) {
                        Log.d(TAG, "Service resolving success:" + nsdServiceInfo);
                        mServiceHost = nsdServiceInfo.getHost().getHostAddress();
                        mServicePort = Integer.toString(nsdServiceInfo.getPort());
                        mHaveService = true;
                        saveSettings(mServiceHost, mServicePort);
                        new RequestTask(createConfigurator()).execute("http://" + mServiceHost + ":" + mServicePort + "/config");
                        mNsdManager.stopServiceDiscovery(mDiscoveryListener);
                    }
                };

                mNsdManager.resolveService(service, resolveListener);
            }

            @Override
            public void onServiceLost(NsdServiceInfo service) {
                // When the network service is no longer available.
                // Internal bookkeeping code goes here.
                Log.e(TAG, "service lost" + service);
            }

            @Override
            public void onDiscoveryStopped(String serviceType) {
                Log.i(TAG, "Discovery stopped: " + serviceType);
                addLogLine("Service discovery stopped.");
            }

            @Override
            public void onStartDiscoveryFailed(String serviceType, int errorCode) {
                Log.e(TAG, "Discovery failed: Error code:" + errorCode);
                addLogLine("Discovery failed: Error code:" + errorCode);
                mNsdManager.stopServiceDiscovery(this);
            }

            @Override
            public void onStopDiscoveryFailed(String serviceType, int errorCode) {
                Log.e(TAG, "Discovery failed: Error code:" + errorCode);
                addLogLine("Discovery failed: Error code:" + errorCode);
                mNsdManager.stopServiceDiscovery(this);
            }
        };
        mNsdManager.discoverServices("_gateservice._tcp.", NsdManager.PROTOCOL_DNS_SD, mDiscoveryListener);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        mNsdManager = (NsdManager)getSystemService(NSD_SERVICE);
        final LinearLayout lm = (LinearLayout) findViewById(R.id.mainLayout);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        for (int i = 0; i < 4; i++) {
            final Button btn = new Button(this);
            final int index = i;
            btn.setId(i+1);
            btn.setText("Button " + Integer.toString(i));
            btn.setLayoutParams(params);

            btn.setOnClickListener(new View.OnClickListener() {
                public void onClick(View v) {
                    TextView indicator = (TextView) findViewById(R.id.indicator);
                    indicator.setBackgroundColor(Color.RED);
                    indicator.setTextColor(Color.RED);
                    Log.i(TAG, "index :" + index);
                    new RequestTask(createClickFinalizer()).execute("http://" + mServiceHost + ":" + mServicePort + "/button?k=" + Integer.toString(index));

                }
            });
            btn.setEnabled(false);
            btn.setVisibility(View.INVISIBLE);
            mButtons.add(btn);
            lm.addView(btn);
        }
        loadSavedSettings();
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        // Inflate the menu; this adds items to the action bar if it is present.
        getMenuInflater().inflate(R.menu.menu_main, menu);
        return true;
    }

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        // Handle action bar item clicks here. The action bar will
        // automatically handle clicks on the Home/Up button, so long
        // as you specify a parent activity in AndroidManifest.xml.
        int id = item.getItemId();

        //noinspection SimplifiableIfStatement
        if (id == R.id.action_settings) {
            if (mServicePort != null && mServiceHost != null) {
                new RequestTask(createConfigurator()).execute("http://" + mServiceHost + ":" + mServicePort + "/config");
            }
            discoverServices();

            return true;
        }

        return super.onOptionsItemSelected(item);
    }

    private void addLogLine(final String line) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                EditText log = (EditText) findViewById(R.id.logText);
                Editable oldText = log.getText();
                oldText.append('\n');
                oldText.append(line);
            }
        });
    }

    class RequestTask extends AsyncTask<String, String, String> {
        ResponseProcessor mResponseProcessor = null;
        boolean mSuccess = false;
        public RequestTask(ResponseProcessor responseProcessor) {
            mResponseProcessor = responseProcessor;
        }

        @Override
        protected String doInBackground(String... uri) {
            String responseString = "";
            try {
                URL url = new URL(uri[0]);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                if(conn.getResponseCode() == HttpsURLConnection.HTTP_OK) {
                    try {
                        BufferedReader ir = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                        String line;
                        while ((line = ir.readLine()) != null) {
                            responseString += line;
                        }
                        Log.d(TAG, "final response:" + responseString);
                        mSuccess = true;
                    }
                    finally {
                        conn.disconnect();
                    }
                }
            } catch (IOException e) {}
            return responseString;
        }

        @Override
        protected void onPostExecute(String result) {
            super.onPostExecute(result);
            Log.d(TAG, "onpostexec:" + result);
            if (mSuccess) {
                mResponseProcessor.processResponse(result);
            } else {
                mResponseProcessor.processResponse(null);
            }
        }
    }

    interface ResponseProcessor {
        void processResponse(String response);
    }
}

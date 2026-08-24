package com.coffice;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import android.view.WindowManager;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;

import java.util.Collections;
import java.util.Set;
import java.util.WeakHashMap;

public class ScreenshotBlocker extends CordovaPlugin {
    private final Set<Activity> activities = Collections.newSetFromMap(
            new WeakHashMap<Activity, Boolean>());
    private Application application;
    private boolean screenshotsBlocked = false;
    private boolean policyWasSet = false;

    private final Application.ActivityLifecycleCallbacks activityLifecycleCallbacks =
            new Application.ActivityLifecycleCallbacks() {
                @Override
                public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                    activities.add(activity);
                    applyScreenshotPolicy(activity);
                }

                @Override
                public void onActivityStarted(Activity activity) {
                    activities.add(activity);
                    applyScreenshotPolicy(activity);
                }

                @Override
                public void onActivityResumed(Activity activity) {
                    activities.add(activity);
                    applyScreenshotPolicy(activity);
                }

                @Override
                public void onActivityPaused(Activity activity) {
                    // No-op.
                }

                @Override
                public void onActivityStopped(Activity activity) {
                    // Keep the weak reference so enable() can clear FLAG_SECURE before destruction.
                }

                @Override
                public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
                    // No-op.
                }

                @Override
                public void onActivityDestroyed(Activity activity) {
                    activities.remove(activity);
                }
            };

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        Activity activity = cordova.getActivity();
        activities.add(activity);
        application = activity.getApplication();
        application.registerActivityLifecycleCallbacks(activityLifecycleCallbacks);
    }

    @Override
    public boolean execute(String action, JSONArray data, final CallbackContext callbackContext)
            throws JSONException {
        if ("enable".equals(action)) {
            setScreenshotsBlocked(false, callbackContext);
            return true;
        }

        if ("disable".equals(action)) {
            setScreenshotsBlocked(true, callbackContext);
            return true;
        }

        return false;
    }

    private void setScreenshotsBlocked(final boolean blocked,
                                       final CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    screenshotsBlocked = blocked;
                    policyWasSet = true;
                    activities.add(cordova.getActivity());

                    Activity[] activitySnapshot = activities.toArray(new Activity[activities.size()]);
                    for (Activity activity : activitySnapshot) {
                        applyScreenshotPolicy(activity);
                    }

                    callbackContext.success("Success");
                } catch (Exception exception) {
                    callbackContext.error(exception.toString());
                }
            }
        });
    }

    private void applyScreenshotPolicy(Activity activity) {
        if (!policyWasSet || activity == null || activity.isFinishing()) {
            return;
        }

        if (screenshotsBlocked) {
            activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        } else {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
        }
    }

    @Override
    public void onDestroy() {
        if (application != null) {
            application.unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks);
            application = null;
        }
        activities.clear();
        super.onDestroy();
    }
}

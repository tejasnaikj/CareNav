package com.unity3d.player;

import android.content.Context;
import android.content.Intent;
import io.flutter.embedding.android.FlutterActivity;

public class FlutterLauncher {
    public static void launch(Context context) {
        // Use the ID defined in CapstoneApplication
        Intent intent = FlutterActivity
            .withCachedEngine(CapstoneApplication.ENGINE_ID)
            .build(context);
            
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        context.startActivity(intent);
    }
}
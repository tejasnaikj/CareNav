package com.unity3d.player;

import android.app.Application;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.dart.DartExecutor;

public class CapstoneApplication extends Application {
    public static final String ENGINE_ID = "my_cached_engine";
    
    @Override
    public void onCreate() {
        super.onCreate();
        
        // Initialize the engine immediately on app start
        FlutterEngine flutterEngine = new FlutterEngine(this);
        flutterEngine.getDartExecutor().executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        );
        
        // Cache it
        FlutterEngineCache
            .getInstance()
            .put(ENGINE_ID, flutterEngine);
    }
}
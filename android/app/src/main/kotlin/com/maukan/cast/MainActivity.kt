package com.maukan.cast

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    
    private lateinit var multicastLockManager: MulticastLockManager
    
    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.maukan/cast"
        private const val PERMISSION_REQUEST_CODE = 1001
        
        // Required permissions for network discovery
        private val REQUIRED_PERMISSIONS = arrayOf(
            "android.permission.ACCESS_NETWORK_STATE",
            "android.permission.ACCESS_WIFI_STATE",
            "android.permission.CHANGE_WIFI_STATE",
            "android.permission.CHANGE_WIFI_MULTICAST_STATE",
            "android.permission.INTERNET",
            "android.permission.ACCESS_FINE_LOCATION",
            "android.permission.ACCESS_COARSE_LOCATION"
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        multicastLockManager = MulticastLockManager(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    val success = multicastLockManager.acquire()
                    result.success(success)
                }
                
                "releaseMulticastLock" -> {
                    val success = multicastLockManager.release()
                    result.success(success)
                }
                
                "isMulticastLockHeld" -> {
                    result.success(multicastLockManager.isHeld())
                }
                
                "checkPermissions" -> {
                    val hasPermissions = checkRequiredPermissions()
                    result.success(hasPermissions)
                }
                
                "requestPermissions" -> {
                    requestRequiredPermissions()
                    result.success(true)
                }
                
                "hasLocationPermission" -> {
                    result.success(hasLocationPermission())
                }
                
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Check if all required permissions are granted.
     */
    private fun checkRequiredPermissions(): Boolean {
        for (permission in REQUIRED_PERMISSIONS) {
            if (ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "Missing permission: $permission")
                return false
            }
        }
        return true
    }

    /**
     * Check if location permission is granted (required for network discovery on Android 12+).
     */
    private fun hasLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, "android.permission.ACCESS_FINE_LOCATION") == PackageManager.PERMISSION_GRANTED
        } else {
            // Before Android 12, location permission might not be strictly required
            // but we still request it for compatibility
            ContextCompat.checkSelfPermission(this, "android.permission.ACCESS_FINE_LOCATION") == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, "android.permission.ACCESS_COARSE_LOCATION") == PackageManager.PERMISSION_GRANTED
        }
    }

    /**
     * Request all required permissions at runtime.
     * This is REQUIRED for Android 6.0+ (API 23+).
     */
    private fun requestRequiredPermissions() {
        val permissionsToRequest = REQUIRED_PERMISSIONS.filter { 
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED 
        }.toTypedArray()

        if (permissionsToRequest.isNotEmpty()) {
            Log.d(TAG, "Requesting ${permissionsToRequest.size} permissions")
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest,
                PERMISSION_REQUEST_CODE
            )
        } else {
            Log.d(TAG, "All permissions already granted")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            Log.d(TAG, "Permission request result: allGranted=$allGranted")
            
            if (!allGranted) {
                val denied = permissions.filterIndexed { index, _ -> 
                    grantResults[index] != PackageManager.PERMISSION_GRANTED 
                }
                Log.w(TAG, "Denied permissions: $denied")
            }
        }
    }

    override fun onDestroy() {
        // Release multicast lock when activity is destroyed
        if (::multicastLockManager.isInitialized) {
            multicastLockManager.release()
        }
        super.onDestroy()
    }
}

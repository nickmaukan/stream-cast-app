package com.maukan.cast

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log

/**
 * Manages MulticastLock for mDNS discovery.
 * Without this, Android silently drops all multicast packets (including mDNS for Chromecast).
 */
class MulticastLockManager(private val context: Context) {

    private var multicastLock: WifiManager.MulticastLock? = null
    private var acquired = false

    companion object {
        private const val TAG = "MulticastLockManager"
        private const val LOCK_TAG = "MaukanCastMDNS"
    }

    /**
     * Acquire the multicast lock.
     * MUST be called before starting mDNS discovery.
     */
    fun acquire(): Boolean {
        if (acquired && multicastLock?.isHeld == true) {
            Log.d(TAG, "MulticastLock already held")
            return true
        }

        try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
            multicastLock = wifiManager.createMulticastLock(LOCK_TAG)
            multicastLock?.setReferenceCounted(true)
            multicastLock?.acquire()
            
            acquired = multicastLock?.isHeld == true
            
            if (acquired) {
                Log.d(TAG, "MulticastLock acquired successfully")
            } else {
                Log.e(TAG, "Failed to acquire MulticastLock")
            }
            
            return acquired
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring MulticastLock: ${e.message}")
            return false
        }
    }

    /**
     * Release the multicast lock.
     * Should be called when discovery is complete.
     */
    fun release(): Boolean {
        if (!acquired) {
            Log.d(TAG, "MulticastLock not held, nothing to release")
            return true
        }

        try {
            multicastLock?.let { lock ->
                if (lock.isHeld) {
                    lock.release()
                    Log.d(TAG, "MulticastLock released")
                }
            }
            multicastLock = null
            acquired = false
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing MulticastLock: ${e.message}")
            return false
        }
    }

    /**
     * Check if multicast lock is currently held.
     */
    fun isHeld(): Boolean = acquired && multicastLock?.isHeld == true
}

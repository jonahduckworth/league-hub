package com.leaguehub.league_hub

import android.content.ComponentName
import android.content.pm.PackageManager
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val appIconChannelName = "league_hub/app_icon"
    private val appUpdateChannelName = "league_hub/app_update"
    private val immediateUpdateRequestCode = 7315
    private var appUpdateManager: AppUpdateManager? = null
    private val alternateIcons = mapOf(
        "AppIconJphl" to "com.leaguehub.league_hub.MainActivityJphl",
        "AppIconSoccer" to "com.leaguehub.league_hub.MainActivitySoccer",
        "AppIconBasketball" to "com.leaguehub.league_hub.MainActivityBasketball",
        "AppIconFootball" to "com.leaguehub.league_hub.MainActivityFootball",
        "AppIconBaseball" to "com.leaguehub.league_hub.MainActivityBaseball",
        "AppIconHockey" to "com.leaguehub.league_hub.MainActivityHockey",
        "AppIconTennis" to "com.leaguehub.league_hub.MainActivityTennis",
        "AppIconTrophy" to "com.leaguehub.league_hub.MainActivityTrophy",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appUpdateManager = AppUpdateManagerFactory.create(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appIconChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(true)
                    "getCurrentIconName" -> result.success(currentIconName())
                    "setIcon" -> {
                        val iconName = call.argument<String?>("iconName")
                        try {
                            setIcon(iconName)
                            result.success(null)
                        } catch (error: IllegalArgumentException) {
                            result.error("invalid_icon", error.message, null)
                        } catch (error: Exception) {
                            result.error("set_icon_failed", error.localizedMessage, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appUpdateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkForUpdate" -> checkForUpdate(result)
                    "startImmediateUpdate" -> startImmediateUpdate(result)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        appUpdateManager?.appUpdateInfo?.addOnSuccessListener { updateInfo ->
            if (
                updateInfo.updateAvailability() ==
                    UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
                updateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)
            ) {
                try {
                    appUpdateManager?.startUpdateFlowForResult(
                        updateInfo,
                        this,
                        AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                        immediateUpdateRequestCode,
                    )
                } catch (_: Exception) {
                    // Flutter keeps the blocking prompt visible so the user can retry.
                }
            }
        }
    }

    private fun checkForUpdate(result: MethodChannel.Result) {
        val manager = appUpdateManager
        if (manager == null) {
            result.error("update_unavailable", "Google Play update manager is unavailable", null)
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { updateInfo ->
                val availability = updateInfo.updateAvailability()
                val available = availability == UpdateAvailability.UPDATE_AVAILABLE ||
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                result.success(
                    mapOf(
                        "available" to available,
                        "immediateAllowed" to
                            updateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                        "availableVersionCode" to updateInfo.availableVersionCode(),
                    ),
                )
            }
            .addOnFailureListener { error ->
                result.error("update_check_failed", error.localizedMessage, null)
            }
    }

    private fun startImmediateUpdate(result: MethodChannel.Result) {
        val manager = appUpdateManager
        if (manager == null) {
            result.success(false)
            return
        }

        manager.appUpdateInfo
            .addOnSuccessListener { updateInfo ->
                val availability = updateInfo.updateAvailability()
                val available = availability == UpdateAvailability.UPDATE_AVAILABLE ||
                    availability == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                if (!available || !updateInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                    result.success(false)
                    return@addOnSuccessListener
                }

                try {
                    val started = manager.startUpdateFlowForResult(
                        updateInfo,
                        this,
                        AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                        immediateUpdateRequestCode,
                    )
                    result.success(started)
                } catch (error: Exception) {
                    result.error("update_start_failed", error.localizedMessage, null)
                }
            }
            .addOnFailureListener { result.success(false) }
    }

    private fun currentIconName(): String? {
        for ((iconName, className) in alternateIcons) {
            val state = packageManager.getComponentEnabledSetting(
                ComponentName(packageName, className)
            )
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return iconName
            }
        }
        return null
    }

    private fun setIcon(iconName: String?) {
        if (iconName != null && !alternateIcons.containsKey(iconName)) {
            throw IllegalArgumentException("Unknown app icon: $iconName")
        }

        val defaultComponent = ComponentName(this, MainActivity::class.java)
        val selectedAlias = iconName?.let { alternateIcons[it] }

        if (selectedAlias == null) {
            packageManager.setComponentEnabledSetting(
                defaultComponent,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        } else {
            packageManager.setComponentEnabledSetting(
                ComponentName(packageName, selectedAlias),
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        for (className in alternateIcons.values) {
            if (className != selectedAlias) {
                packageManager.setComponentEnabledSetting(
                    ComponentName(packageName, className),
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        }

        if (selectedAlias != null) {
            packageManager.setComponentEnabledSetting(
                defaultComponent,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}

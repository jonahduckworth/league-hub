package com.leaguehub.league_hub

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "league_hub/app_icon"
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
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

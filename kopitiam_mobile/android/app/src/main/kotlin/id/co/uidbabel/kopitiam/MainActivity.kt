package id.co.uidbabel.kopitiam

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "id.co.uidbabel.kopitiam/data_sync_service"
    private val notificationPermissionRequest = 4102
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureNotificationPermission" -> ensureNotificationPermission(result)
                    "start" -> {
                        val label = call.argument<String>("label") ?: "Memproses data"
                        val intent = Intent(this, DataSyncForegroundService::class.java)
                            .setAction(DataSyncForegroundService.ACTION_START)
                            .putExtra(DataSyncForegroundService.EXTRA_LABEL, label)
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    }
                    "update" -> {
                        val label = call.argument<String>("label") ?: "Memproses data"
                        val progress = call.argument<Int>("progress") ?: -1
                        startService(
                            Intent(this, DataSyncForegroundService::class.java)
                                .setAction(DataSyncForegroundService.ACTION_UPDATE)
                                .putExtra(DataSyncForegroundService.EXTRA_LABEL, label)
                                .putExtra(DataSyncForegroundService.EXTRA_PROGRESS, progress),
                        )
                        result.success(true)
                    }
                    "stop" -> {
                        startService(
                            Intent(this, DataSyncForegroundService::class.java)
                                .setAction(DataSyncForegroundService.ACTION_STOP),
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequest,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequest) {
            permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}

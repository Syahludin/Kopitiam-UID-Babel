package id.co.uidbabel.kopitiam

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class DataSyncForegroundService : Service() {
    companion object {
        const val ACTION_START = "kopitiam.dataSync.START"
        const val ACTION_UPDATE = "kopitiam.dataSync.UPDATE"
        const val ACTION_STOP = "kopitiam.dataSync.STOP"
        const val EXTRA_LABEL = "label"
        const val EXTRA_PROGRESS = "progress"
        private const val CHANNEL_ID = "kopitiam_data_sync"
        private const val NOTIFICATION_ID = 194
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                val label = intent.getStringExtra(EXTRA_LABEL) ?: "Memproses data"
                val progress = intent.getIntExtra(EXTRA_PROGRESS, -1)
                NotificationManagerCompat.from(this).notify(
                    NOTIFICATION_ID,
                    notification(label, progress),
                )
            }
            else -> {
                val label = intent?.getStringExtra(EXTRA_LABEL) ?: "Memproses data"
                val value = notification(label, -1)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        value,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
                    )
                } else {
                    startForeground(NOTIFICATION_ID, value)
                }
            }
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Sinkronisasi data Kopitiam",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Menampilkan proses download dan sinkronisasi yang berjalan"
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun notification(label: String, progress: Int): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(label)
            .setContentText("Kopitiam tetap memproses data di latar belakang")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setProgress(100, progress.coerceIn(0, 100), progress !in 0..100)
            .build()
    }
}

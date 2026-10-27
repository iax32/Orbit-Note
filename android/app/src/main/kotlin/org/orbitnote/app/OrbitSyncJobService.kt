package org.orbitnote.app

import android.accounts.Account
import android.app.job.JobInfo
import android.app.job.JobParameters
import android.app.job.JobScheduler
import android.app.job.JobService
import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

internal object OrbitBackgroundJobs {
    private const val id = 0x4f5242
    private fun scheduler(context: Context) = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
    private fun enabled(context: Context) = context.getSharedPreferences("orbit-background", Context.MODE_PRIVATE).getBoolean("enabled", false)
    fun configure(context: Context, enabled: Boolean) {
        check(context.getSharedPreferences("orbit-background", Context.MODE_PRIVATE).edit().putBoolean("enabled", enabled).commit())
        // The foreground activity will schedule onStop. Never start a second
        // engine while account/settings controls are being used in the UI.
        pause(context)
    }
    fun pause(context: Context) { scheduler(context).cancel(id) }
    fun schedule(context: Context) {
        if (!enabled(context)) return
        val job = JobInfo.Builder(id, ComponentName(context, OrbitSyncJobService::class.java))
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY).setPersisted(true)
            .setPeriodic(15 * 60 * 1000L)
            .setBackoffCriteria(60 * 1000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build()
        check(scheduler(context).schedule(job) == JobScheduler.RESULT_SUCCESS)
    }
}

/// Separate process: Linux advisory locks must not share the editor's process.
/// No Activity, consent prompts or browser can be started by this service.
class OrbitSyncJobService : JobService() {
    private var engine: FlutterEngine? = null
    private var parameters: JobParameters? = null
    override fun onStartJob(params: JobParameters): Boolean {
        if (engine != null) return false
        parameters = params
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            val created = FlutterEngine(applicationContext)
            engine = created
            MethodChannel(created.dartExecutor.binaryMessenger, "orbit_note/background_sync").setMethodCallHandler { call, result ->
                when (call.method) {
                    "finished" -> {
                        result.success(null)
                        val retry = call.argument<Boolean>("success") != true
                        Handler(Looper.getMainLooper()).post {
                            engine?.destroy(); engine = null
                            parameters?.let { jobFinished(it, retry) }; parameters = null
                            // A fresh process avoids stale encrypted preferences on the next job.
                            Handler(Looper.getMainLooper()).postDelayed({ android.os.Process.killProcess(android.os.Process.myPid()) }, 200)
                        }
                    }
                    "authorize" -> {
                        val email = call.argument<String>("email")
                        val scopes = call.argument<List<String>>("scopes")
                        val allowed = setOf("openid", "profile", "email", "https://www.googleapis.com/auth/drive.file")
                        if (email.isNullOrBlank() || scopes.isNullOrEmpty() || scopes.toSet() != allowed) {
                            result.error("reauth", "Reconnect Google Drive in Orbit.", null)
                        } else {
                            val authorization = Identity.getAuthorizationClient(applicationContext)
                            fun request() {
                                val request = AuthorizationRequest.builder().setAccount(Account(email, "com.google"))
                                    .setRequestedScopes(scopes.map { Scope(it) }).build()
                                authorization.authorize(request).addOnSuccessListener { grant ->
                                    if (grant.hasResolution() || grant.accessToken.isNullOrBlank()) result.error("reauth", "Open Orbit to approve access.", null)
                                    else result.success(grant.accessToken)
                                }.addOnFailureListener { result.error("reauth", "Reconnect Google Drive in Orbit.", null) }
                            }
                            val clear = call.argument<String>("clear")
                            if (clear.isNullOrEmpty()) request()
                            else authorization.clearToken(ClearTokenRequest.builder().setToken(clear).build())
                                .addOnSuccessListener { request() }
                                .addOnFailureListener { result.error("reauth", "Reconnect Google Drive in Orbit.", null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
            created.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "orbitBackgroundSync"))
            return true
        } catch (_: Exception) {
            engine?.destroy(); engine = null; parameters = null
            return false
        }
    }
    override fun onStopJob(params: JobParameters): Boolean {
        // Only the dedicated worker process stops. OS locks are released;
        // durable outbox/staging journals recover interrupted transfers.
        engine?.destroy(); engine = null; parameters = null
        android.os.Process.killProcess(android.os.Process.myPid())
        return true
    }
}

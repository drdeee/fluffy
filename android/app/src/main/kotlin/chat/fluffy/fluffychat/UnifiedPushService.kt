package chat.fluffy.fluffychat.dev

import org.unifiedpush.flutter.connector.UnifiedPushService

import chat.fluffy.fluffychat.dev.MainActivity

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.FlutterMain
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint
import org.unifiedpush.android.connector.MessagingReceiver

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.view.WindowManager

val receiverHandler = object : UnifiedPushService() {
    override fun getEngine(context: Context): FlutterEngine {
        return provideEngine(context)
    }

    fun provideEngine(context: Context): FlutterEngine {
        var engine = MainActivity.engine
        if (engine == null) {
            engine = MainActivity.provideEngine(context)
            engine.getLocalizationPlugin().sendLocalesToFlutter(
                context.getResources().getConfiguration())
            engine.getDartExecutor().executeDartEntrypoint(
                DartEntrypoint.createDefault())
        }
        return engine
    }
}

class UnifiedPushReceiver : MessagingReceiver(receiverHandler)

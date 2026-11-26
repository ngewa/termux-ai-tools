.class public Lcom/termux/devicebridge/Bridge;
.super Ljava/lang/Object;

.method public static main([Ljava/lang/String;)V
    .registers 6

    array-length v3, p0
    if-lez v3, :err_args

    const/4 v3, 0x0
    aget-object v0, p0, v3

    :try_start
    const-string v1, "vibrate"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :chk_notify
    invoke-static {p0}, Lcom/termux/devicebridge/Bridge;->doVibrate([Ljava/lang/String;)V
    return-void

    :chk_notify
    const-string v1, "notify"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :chk_toast
    invoke-static {p0}, Lcom/termux/devicebridge/Bridge;->doNotify([Ljava/lang/String;)V
    return-void

    :chk_toast
    const-string v1, "toast"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :chk_clip_get
    invoke-static {p0}, Lcom/termux/devicebridge/Bridge;->doToast([Ljava/lang/String;)V
    return-void

    :chk_clip_get
    const-string v1, "clipboard-get"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :chk_clip_set
    invoke-static {}, Lcom/termux/devicebridge/Bridge;->doClipboardGet()V
    return-void

    :chk_clip_set
    const-string v1, "clipboard-set"
    invoke-virtual {v1, v0}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :err_unknown
    invoke-static {p0}, Lcom/termux/devicebridge/Bridge;->doClipboardSet([Ljava/lang/String;)V
    return-void

    :err_unknown
    sget-object v1, Ljava/lang/System;->err:Ljava/io/PrintStream;
    const-string v2, "Unknown subcommand"
    invoke-virtual {v1, v2}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    const/4 v3, 0x1
    invoke-static {v3}, Ljava/lang/System;->exit(I)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :catch_all
    return-void

    :catch_all
    move-exception v0
    sget-object v1, Ljava/lang/System;->err:Ljava/io/PrintStream;
    invoke-virtual {v0, v1}, Ljava/lang/Throwable;->printStackTrace(Ljava/io/PrintStream;)V
    const/4 v3, 0x1
    invoke-static {v3}, Ljava/lang/System;->exit(I)V
    return-void

    :err_args
    sget-object v1, Ljava/lang/System;->err:Ljava/io/PrintStream;
    const-string v2, "Usage: Bridge <vibrate|notify|toast|clipboard-get|clipboard-set> [args...]"
    invoke-virtual {v1, v2}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    const/4 v3, 0x1
    invoke-static {v3}, Ljava/lang/System;->exit(I)V
    return-void
.end method

.method public static doVibrate([Ljava/lang/String;)V
    .registers 16

    const-wide/16 v6, 0x190
    array-length v2, p0
    const/4 v3, 0x1
    if-le v2, v3, :after_parse
    aget-object v0, p0, v3
    invoke-static {v0}, Ljava/lang/Long;->parseLong(Ljava/lang/String;)J
    move-result-wide v6

    :after_parse
    const-wide/16 v4, 0x1
    cmp-long v2, v6, v4
    if-gez v2, :dur_ok
    const-wide/16 v6, 0x190

    :dur_ok
    const-string v0, "vibrator_manager"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    invoke-static {v0}, Landroid/os/IVibratorManagerService$Stub;->asInterface(Landroid/os/IBinder;)Landroid/os/IVibratorManagerService;
    move-result-object v8

    invoke-static {}, Landroid/os/Process;->myUid()I
    move-result v9
    const-string v10, "com.termux"

    const/4 v2, -0x1
    invoke-static {v6, v7, v2}, Landroid/os/VibrationEffect;->createOneShot(JI)Landroid/os/VibrationEffect;
    move-result-object v0
    invoke-static {v0}, Landroid/os/CombinedVibration;->createParallel(Landroid/os/VibrationEffect;)Landroid/os/CombinedVibration;
    move-result-object v11

    const/16 v2, 0x11
    invoke-static {v2}, Landroid/os/VibrationAttributes;->createForUsage(I)Landroid/os/VibrationAttributes;
    move-result-object v12

    const-string v13, "termux-device"
    new-instance v14, Landroid/os/Binder;
    invoke-direct {v14}, Landroid/os/Binder;-><init>()V

    invoke-interface/range {v8 .. v14}, Landroid/os/IVibratorManagerService;->vibrate(ILjava/lang/String;Landroid/os/CombinedVibration;Landroid/os/VibrationAttributes;Ljava/lang/String;Landroid/os/IBinder;)V

    const-wide/16 v4, 0x3c
    add-long/2addr v6, v4
    invoke-static {v6, v7}, Ljava/lang/Thread;->sleep(J)V
    return-void
.end method

.method public static doNotify([Ljava/lang/String;)V
    .registers 16

    const-string v1, "Termux"
    const-string v2, ""
    const/4 v5, 0x1
    const/16 v12, 0x343a

    array-length v6, p0
    const/4 v7, 0x1
    if-le v6, v7, :args_done
    aget-object v1, p0, v7

    const/4 v7, 0x2
    if-le v6, v7, :args_done
    aget-object v2, p0, v7

    const/4 v7, 0x3
    if-le v6, v7, :args_done
    aget-object v0, p0, v7
    const-string v3, "false"
    invoke-virtual {v3, v0}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z
    move-result v7
    if-eqz v7, :chk_id
    const/4 v5, 0x0

    :chk_id
    const/4 v7, 0x4
    if-le v6, v7, :args_done
    aget-object v0, p0, v7
    invoke-static {v0}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v12

    :args_done
    invoke-static {}, Landroid/os/Looper;->prepareMainLooper()V
    invoke-static {}, Landroid/app/ActivityThread;->systemMain()Landroid/app/ActivityThread;
    move-result-object v0
    invoke-virtual {v0}, Landroid/app/ActivityThread;->getSystemContext()Landroid/app/ContextImpl;
    move-result-object v0
    const-string v9, "com.termux"
    const/4 v7, 0x0
    invoke-virtual {v0, v9, v7}, Landroid/content/Context;->createPackageContext(Ljava/lang/String;I)Landroid/content/Context;
    move-result-object v3

    const-string v0, "notification"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    invoke-static {v0}, Landroid/app/INotificationManager$Stub;->asInterface(Landroid/os/IBinder;)Landroid/app/INotificationManager;
    move-result-object v8

    invoke-static {}, Landroid/os/Process;->myUid()I
    move-result v6

    if-eqz v5, :silent_chan
    const-string v4, "termux_ai_notify"
    const-string v0, "Termux AI Notifications"
    const/4 v7, 0x4
    new-instance v10, Landroid/app/NotificationChannel;
    invoke-direct {v10, v4, v0, v7}, Landroid/app/NotificationChannel;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;I)V
    const/4 v7, 0x1
    invoke-virtual {v10, v7}, Landroid/app/NotificationChannel;->enableVibration(Z)V
    goto :register_chan

    :silent_chan
    const-string v4, "termux_ai_silent"
    const-string v0, "Termux AI Silent Notifications"
    const/4 v7, 0x2
    new-instance v10, Landroid/app/NotificationChannel;
    invoke-direct {v10, v4, v0, v7}, Landroid/app/NotificationChannel;-><init>(Ljava/lang/String;Ljava/lang/CharSequence;I)V
    const/4 v7, 0x0
    const/4 v0, 0x0
    invoke-virtual {v10, v0, v0}, Landroid/app/NotificationChannel;->setSound(Landroid/net/Uri;Landroid/media/AudioAttributes;)V
    invoke-virtual {v10, v7}, Landroid/app/NotificationChannel;->enableVibration(Z)V

    :register_chan
    new-instance v0, Ljava/util/ArrayList;
    invoke-direct {v0}, Ljava/util/ArrayList;-><init>()V
    invoke-virtual {v0, v10}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z
    new-instance v11, Landroid/content/pm/ParceledListSlice;
    invoke-direct {v11, v0}, Landroid/content/pm/ParceledListSlice;-><init>(Ljava/util/List;)V
    invoke-interface {v8, v9, v11}, Landroid/app/INotificationManager;->createNotificationChannels(Ljava/lang/String;Landroid/content/pm/ParceledListSlice;)V

    new-instance v0, Landroid/app/Notification$Builder;
    invoke-direct {v0, v3, v4}, Landroid/app/Notification$Builder;-><init>(Landroid/content/Context;Ljava/lang/String;)V
    const v7, 0x7f0700b6
    invoke-virtual {v0, v7}, Landroid/app/Notification$Builder;->setSmallIcon(I)Landroid/app/Notification$Builder;
    invoke-virtual {v0, v1}, Landroid/app/Notification$Builder;->setContentTitle(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;
    invoke-virtual {v0, v2}, Landroid/app/Notification$Builder;->setContentText(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;
    const/4 v7, 0x1
    invoke-virtual {v0, v7}, Landroid/app/Notification$Builder;->setAutoCancel(Z)Landroid/app/Notification$Builder;
    invoke-static {v0}, Lcom/termux/devicebridge/Bridge;->applyTimestamp(Landroid/app/Notification$Builder;)V

    new-instance v10, Landroid/app/Notification$BigTextStyle;
    invoke-direct {v10}, Landroid/app/Notification$BigTextStyle;-><init>()V
    invoke-virtual {v10, v2}, Landroid/app/Notification$BigTextStyle;->bigText(Ljava/lang/CharSequence;)Landroid/app/Notification$BigTextStyle;
    invoke-virtual {v0, v10}, Landroid/app/Notification$Builder;->setStyle(Landroid/app/Notification$Style;)Landroid/app/Notification$Builder;

    invoke-virtual {v0}, Landroid/app/Notification$Builder;->build()Landroid/app/Notification;
    move-result-object v13

    move-object v10, v9
    const-string v11, "termux_ai"
    const v7, 0x186a0
    div-int v14, v6, v7

    invoke-interface/range {v8 .. v14}, Landroid/app/INotificationManager;->enqueueNotificationWithTag(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;ILandroid/app/Notification;I)V
    return-void
.end method

.method private static applyTimestamp(Landroid/app/Notification$Builder;)V
    .registers 7

    invoke-static {}, Ljava/lang/System;->currentTimeMillis()J
    move-result-wide v0

    invoke-virtual {p0, v0, v1}, Landroid/app/Notification$Builder;->setWhen(J)Landroid/app/Notification$Builder;
    const/4 v2, 0x1
    invoke-virtual {p0, v2}, Landroid/app/Notification$Builder;->setShowWhen(Z)Landroid/app/Notification$Builder;

    new-instance v3, Ljava/text/SimpleDateFormat;
    const-string v4, "HH:mm:ss"
    invoke-static {}, Ljava/util/Locale;->getDefault()Ljava/util/Locale;
    move-result-object v5
    invoke-direct {v3, v4, v5}, Ljava/text/SimpleDateFormat;-><init>(Ljava/lang/String;Ljava/util/Locale;)V

    new-instance v4, Ljava/util/Date;
    invoke-direct {v4, v0, v1}, Ljava/util/Date;-><init>(J)V
    invoke-virtual {v3, v4}, Ljava/text/SimpleDateFormat;->format(Ljava/util/Date;)Ljava/lang/String;
    move-result-object v3

    invoke-virtual {p0, v3}, Landroid/app/Notification$Builder;->setSubText(Ljava/lang/CharSequence;)Landroid/app/Notification$Builder;
    return-void
.end method

.method public static doToast([Ljava/lang/String;)V
    .registers 16

    const-string v11, ""
    array-length v2, p0
    const/4 v3, 0x1
    if-le v2, v3, :msg_ready
    aget-object v11, p0, v3

    :msg_ready
    const-string v0, "notification"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    invoke-static {v0}, Landroid/app/INotificationManager$Stub;->asInterface(Landroid/os/IBinder;)Landroid/app/INotificationManager;
    move-result-object v8

    const-string v9, "com.termux"
    new-instance v10, Landroid/os/Binder;
    invoke-direct {v10}, Landroid/os/Binder;-><init>()V
    const/4 v12, 0x1
    const/4 v13, 0x0
    const/4 v14, 0x0

    invoke-interface/range {v8 .. v14}, Landroid/app/INotificationManager;->enqueueTextToast(Ljava/lang/String;Landroid/os/IBinder;Ljava/lang/CharSequence;IILandroid/app/ITransientNotificationCallback;)V
    return-void
.end method

.method public static doClipboardGet()V
    .registers 6

    const-string v0, "clipboard"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    invoke-static {v0}, Landroid/content/IClipboard$Stub;->asInterface(Landroid/os/IBinder;)Landroid/content/IClipboard;
    move-result-object v0

    invoke-static {}, Landroid/os/Process;->myUid()I
    move-result v4
    const v5, 0x186a0
    div-int/2addr v4, v5

    const-string v1, "com.termux"
    invoke-interface {v0, v1, v4}, Landroid/content/IClipboard;->getPrimaryClip(Ljava/lang/String;I)Landroid/content/ClipData;
    move-result-object v1
    if-eqz v1, :done

    const/4 v4, 0x0
    invoke-virtual {v1, v4}, Landroid/content/ClipData;->getItemAt(I)Landroid/content/ClipData$Item;
    move-result-object v1
    if-eqz v1, :done

    invoke-virtual {v1}, Landroid/content/ClipData$Item;->getText()Ljava/lang/CharSequence;
    move-result-object v1
    if-eqz v1, :done

    sget-object v2, Ljava/lang/System;->out:Ljava/io/PrintStream;
    invoke-interface {v1}, Ljava/lang/CharSequence;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v2, v1}, Ljava/io/PrintStream;->print(Ljava/lang/String;)V

    :done
    return-void
.end method

.method public static doClipboardSet([Ljava/lang/String;)V
    .registers 7

    const-string v1, ""
    array-length v4, p0
    const/4 v5, 0x1
    if-le v4, v5, :txt_ready
    aget-object v1, p0, v5

    :txt_ready
    const-string v0, "clipboard"
    invoke-static {v0}, Landroid/os/ServiceManager;->getService(Ljava/lang/String;)Landroid/os/IBinder;
    move-result-object v0
    invoke-static {v0}, Landroid/content/IClipboard$Stub;->asInterface(Landroid/os/IBinder;)Landroid/content/IClipboard;
    move-result-object v0

    const-string v2, "termux"
    invoke-static {v2, v1}, Landroid/content/ClipData;->newPlainText(Ljava/lang/CharSequence;Ljava/lang/CharSequence;)Landroid/content/ClipData;
    move-result-object v2

    invoke-static {}, Landroid/os/Process;->myUid()I
    move-result v4
    const v5, 0x186a0
    div-int/2addr v4, v5

    const-string v3, "com.termux"
    invoke-interface {v0, v2, v3, v4}, Landroid/content/IClipboard;->setPrimaryClip(Landroid/content/ClipData;Ljava/lang/String;I)V
    return-void
.end method

# Shipped with the AAR, so a consuming app gets these whether or not its own
# proguard-rules.pro is wired up. That matters: AGP 9 runs R8 on release by
# default, an app can reference no rules file at all without any build error,
# and the failure mode is a crash at launch in a release build that reviewers
# and CI never see.
-keep class com.inmobi.** { *; }
-keep public class com.google.android.gms.** { public *; }
-keep class kotlin.Metadata { *; }
-dontwarn com.squareup.okhttp.**
-dontwarn com.squareup.picasso.**
-dontwarn com.google.android.gms.**

# The plugin's own entry points, reached reflectively by the Flutter embedding.
-keep class com.illuminationdevelopment.inmobi_ads.** { *; }

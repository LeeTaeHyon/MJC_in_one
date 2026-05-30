-keepattributes Signature

# flutter_local_notifications uses Gson to load scheduled notifications.
# R8 can strip generic signatures, causing:
# "TypeToken must be created with a type argument..."
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

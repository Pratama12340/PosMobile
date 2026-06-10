# ProGuard/R8 rules to ignore missing slf4j logger binding classes in release build
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.LoggerFactory
-dontwarn org.slf4j.impl.**
-dontwarn org.slf4j.**

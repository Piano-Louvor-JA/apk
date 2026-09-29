# Regras adicionais de R8/ProGuard para release do LouvorJA PIANO.
# Flutter e plugins publicados fornecem as consumer rules necessarias.
# Adicione regras -keep apenas quando uma dependencia quebrar sob minify.

# Evita expor atributos de depuracao desnecessarios no artefato release.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Preserva classes chamadas por AndroidX/FileProvider durante a instalacao do APK.
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.core.content.FileProvider$PathStrategy { *; }

# MediaSession — R8 remove callbacks e BroadcastReceiver registrado dinamicamente.
-keep class com.louvorja.louvorja_piano_mobile.MediaSessionController { *; }
-keep class com.louvorja.louvorja_piano_mobile.MediaSessionController$** { *; }

# Widget 4x2
-keep class com.louvorja.louvorja_piano_mobile.LiturgyWidgetLargeProvider { *; }
-keep class com.louvorja.louvorja_piano_mobile.LiturgyWidgetLargeProvider$** { *; }

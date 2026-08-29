import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val isReleaseTask = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

// Sandi keystore tidak disimpan dalam bentuk teks polos. Nilai di bawah adalah
// hasil obfuscation (bukan enkripsi) sehingga tidak terbaca langsung di repo.
// PERHATIAN: ini hanya menyamarkan, bukan mengamankan. Repo wajib tetap privat.
val obfuscatedSecretPart1 = "RUJkb0hqWXBIZ3MyYnpJWEhCd3pGajBNTkc0Z0"
val obfuscatedSecretPart2 = "xCWnRPVEJwUHcwNE1od0tJeTQ1SFJBUllnPT0="

fun unobfuscateSecret(value: String): String {
    val inner = String(
        Base64.getDecoder().decode(value.trim()),
        Charsets.UTF_8,
    )
    val xored = Base64.getDecoder().decode(inner)
    val plain = ByteArray(xored.size) { index ->
        (xored[index].toInt() xor 0x5A).toByte()
    }
    return String(plain, Charsets.UTF_8)
}

android {
    namespace = "id.co.uidbabel.kopitiam"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "id.co.uidbabel.kopitiam"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                    ?: error("storeFile belum diisi pada android/key.properties")
                storeFile = rootProject.file(storeFilePath)
                storePassword = unobfuscateSecret(
                    obfuscatedSecretPart1 + obfuscatedSecretPart2,
                )
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: error("keyAlias belum diisi pada android/key.properties")
                keyPassword = unobfuscateSecret(
                    obfuscatedSecretPart1 + obfuscatedSecretPart2,
                )
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

if (isReleaseTask && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "Release signing Kopitiam belum dikonfigurasi. " +
            "Buat android/key.properties dan keystore release."
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.concurrent:concurrent-futures:1.2.0")
}

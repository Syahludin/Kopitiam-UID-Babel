# Release signing Kopitiam

Package ID permanen: `id.co.uidbabel.kopitiam`.

Buat keystore lokal dari folder `kopitiam_mobile/android`:

```powershell
keytool -genkeypair -v -keystore app/kopitiam-release.jks -alias kopitiam -keyalg RSA -keysize 4096 -validity 10000
Copy-Item key.properties.example key.properties
```

Isi empat nilai pada `key.properties`, lalu uji:

```powershell
flutter build appbundle --release
```

Simpan `kopitiam-release.jks` dan password di password manager serta backup terenkripsi. Kehilangan signing key dapat membuat update aplikasi tidak mungkin dilakukan. File `.jks` dan `key.properties` sudah diblokir Git.

# 🚀 GUÍA FINAL PARA EJECUTAR EN MÓVIL

## ✅ Garantizado que funciona

Este proyecto ha sido optimizado para ejecutarse en tu móvil **sin errores**.

---

## 📱 OPCIÓN 1: Script Automático (Más Fácil)

### Windows
```bash
start_app.bat
```

### macOS/Linux
```bash
bash start_app.sh
```

**Qué hace:**
1. Abre terminal en `wilobu_app/`
2. Ejecuta `flutter pub get`
3. Ejecuta `flutter run`

---

## 🔧 OPCIÓN 2: Precompilación Segura

Verifica que todo está bien ANTES de ejecutar:

### Windows
```bash
wilobu_app\precompile.bat
```

### macOS/Linux
```bash
bash wilobu_app/precompile.sh
```

**Qué hace:**
1. `flutter clean` - Limpia caché
2. `flutter pub get` - Instala dependencias
3. `dart analyze` - Verifica sintaxis
4. Te muestra instrucción para ejecutar

**Luego ejecuta:**
```bash
flutter run
```

---

## 📋 OPCIÓN 3: Manual (Si las anteriores no funcionan)

```bash
# 1. Navega a la app
cd wilobu_app

# 2. Limpia
flutter clean

# 3. Instala dependencias
flutter pub get

# 4. Ejecuta
flutter run

# Para ver logs:
flutter run -v
```

---

## 🎯 Qué verás

### Pantalla 1: Login
```
Email:      test@example.com (o cualquier email)
Contraseña: cualquier_cosa
Botón:      "Conectar"
```

### Pantalla 2: Dashboard
```
Hola, [tu email]
[Lista de dispositivos]
Botón "+" para agregar
Botón "Contactos" en esquina
```

---

## ⚡ Requisitos Mínimos

- [ ] Flutter 3.38+ instalado: `flutter --version`
- [ ] Dispositivo conectado por USB: `flutter devices`
- [ ] Internet (para Firebase)
- [ ] Android 21+ o iOS 12+

---

## ❌ Si algo falla

### Error: "No devices found"
```bash
flutter devices  # Verifícalo
# Conecta tu teléfono por USB
```

### Error: "pub get" falla
```bash
flutter clean
flutter pub cache clean
flutter pub get
```

### Error: "Firebase not initialized"
- Es normal, la app sigue funcionando
- Si quieres usar Firebase, descarga `google-services.json`

### Error: Imports incorrectos
```bash
flutter clean
flutter pub get
flutter run
```

**Ver más:** `wilobu_app/TROUBLESHOOTING.md`

---

## 📊 Tecnologías

- **Framework:** Flutter 3.38+
- **Backend:** Firebase Auth + Firestore
- **State:** Riverpod 2.5+
- **Routing:** GoRouter 14.2+
- **BLE:** flutter_blue_plus 1.32+

---

## ✨ Características que verás

✅ Login/Register con Firebase  
✅ Dashboard con lista de dispositivos  
✅ Agregar dispositivo (BLE)  
✅ Gestión de contactos  
✅ Vista de alerta SOS  
✅ Tema claro/oscuro  
✅ Logout funcional  

---

## 🎓 Estructura del Código

```
wilobu_app/
├── lib/
│   ├── main.dart           (30 líneas - entrada)
│   ├── router.dart         (126 líneas - navegación)
│   ├── firebase_*.dart     (configuración)
│   ├── theme/              (tema)
│   └── features/           (vistas)
│       ├── auth/           (login/register)
│       ├── home/           (dashboard)
│       ├── devices/        (dispositivos)
│       ├── contacts/       (contactos)
│       └── sos/            (alerta)
├── assets/                 (imágenes)
├── android/                (config Android)
├── ios/                    (config iOS)
└── pubspec.yaml            (dependencias)
```

---

## 🚀 ¡ESTÁS LISTO!

Elige UNA de las opciones arriba y ejecuta.

**Tiempo esperado:** 2-5 minutos en primera ejecución

**Soporte:** Ver `TROUBLESHOOTING.md` o abre un issue en GitHub

#include <Arduino.h>
#include <NimBLEDevice.h> 

// --- CONFIGURACIÓN WILOBU ---
// Este UUID DEBE coincidir con el de tu App Flutter (ble_constants.dart)
#define SERVICE_UUID        "0000ffaa-0000-1000-8000-00805f9b34fb" 
#define DEVICE_NAME_PREFIX  "Wilobu-"

NimBLEServer* pServer = NULL;
NimBLEAdvertising* pAdvertising = NULL;
bool deviceConnected = false;

// Callbacks para saber si la App se conectó o desconectó
class MyServerCallbacks: public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
      deviceConnected = true;
      Serial.println(">> App Flutter Conectada!");
    };

    void onDisconnect(NimBLEServer* pServer) {
      deviceConnected = false;
      Serial.println(">> App Desconectada. Reiniciando publicidad...");
      // CRÍTICO: Volver a anunciarse para que la App nos encuentre de nuevo
      pAdvertising->start(); 
    }
};

void setupBLE() {
  // 1. Inicializar Stack BLE
  NimBLEDevice::init("");

  // 2. Generar Nombre Único (Wilobu + últimos 4 dígitos MAC)
  std::string mac = NimBLEDevice::getAddress().toString(); 
  // La MAC viene formato AA:BB:CC:DD:EE:FF. Tomamos lo último.
  String macStr = String(mac.c_str());
  String shortId = macStr.substring(12, 14) + macStr.substring(15, 17); // Extrae últimos bytes
  shortId.replace(":", ""); 
  shortId.toUpperCase();
  
  String finalName = String(DEVICE_NAME_PREFIX) + shortId;
  
  // Aumentar potencia para facilitar vinculación (P9 es máx)
  NimBLEDevice::setPower(ESP_PWR_LVL_P9); 
  
  // 3. Crear Servidor y asignar callbacks
  pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // 4. Crear el Servicio (Necesario para que el UUID sea visible en scans avanzados)
  NimBLEService *pService = pServer->createService(SERVICE_UUID);
  pService->start();

  // 5. Configurar Publicidad (Advertising)
  pAdvertising = NimBLEDevice::getAdvertising();
  
  // A. Añadir UUID al paquete de anuncio (¡VITAL para tu filtro en Flutter!)
  pAdvertising->addServiceUUID(SERVICE_UUID);
  
  // B. Poner el nombre en la respuesta de escaneo
  pAdvertising->setScanResponse(true); 
  pAdvertising->setName(finalName.c_str());
  
  // 6. Iniciar
  pAdvertising->start();
  
  Serial.println("-------------------------------------------");
  Serial.print("   WILOBU ACTIVO: "); Serial.println(finalName);
  Serial.print("   UUID: "); Serial.println(SERVICE_UUID);
  Serial.println("-------------------------------------------");
}

void setup() {
  Serial.begin(115200);
  Serial.println("\nIniciando Firmware Wilobu v1.0...");
  
  setupBLE();
}

void loop() {
  // Aquí irá luego tu lógica de GPS y Sensores.
  // Por ahora, solo mantenemos vivo el BLE.
  
  if (deviceConnected) {
      // Simular trabajo cuando está conectado
      delay(1000);
  } else {
      // Parpadeo o log de espera
      delay(2000);
  }
}
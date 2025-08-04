#include <Arduino.h>
#include <WiFi.h>
#include <esp_now.h>
#include <WebSocketsServer.h>
#include <ArduinoJson.h>

// ======== HATA AYIKLAMA KONTROLÜ ========
#define DEBUG_MODE true

// ======== Wi-Fi & WebSocket AYARLARI ========
const char* ssid = "ESP32_Sensor_GW_AP";
const char* password = "vibrationsensor";
#define WEBSOCKET_PORT 81

WebSocketsServer webSocket = WebSocketsServer(WEBSOCKET_PORT);

// ======== ESP-NOW İLGİLİ SABİTLER VE DEĞİŞKENLER ========
#define NUM_TRANSMITTERS 4
uint8_t transmitterMacs[NUM_TRANSMITTERS][6] = {
  {0x00, 0x4B, 0x12, 0x3A, 0x20, 0xA4}, {0x00, 0x4B, 0x12, 0x3E, 0x32, 0x60},
  {0x08, 0xA6, 0xF7, 0x47, 0x3D, 0xA0}, {0xF4, 0x65, 0x0B, 0x47, 0x08, 0x6C}
};
esp_now_peer_info_t peerInfoTransmitters[NUM_TRANSMITTERS];

typedef struct struct_sensor_data {
    int sender_id; float ax; float ay; float az; float magnitude;
} struct_sensor_data;

typedef struct struct_request_data {
    char command[10]; 
} struct_request_data;
struct_request_data requestPayload;

// Veri işleme için Flag (İşaret)
volatile bool newDataAvailable = false;
struct_sensor_data dataToProcess;

// WebSocket olayları için callback (Değişiklik yok)
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_DISCONNECTED:
            if (DEBUG_MODE) Serial.printf("[%u] Baglanti koptu!\n", num);
            break;
        case WStype_CONNECTED: {
                IPAddress ip = webSocket.remoteIP(num);
                if (DEBUG_MODE) Serial.printf("[%u] Baglandi. IP: %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
            }
            break;
        case WStype_TEXT:
            if (DEBUG_MODE) Serial.printf("[%u] Gelen metin: %s\n", num, payload);
            break;
        default:
            break;
    }
}

// ESP-NOW gönderme callback'i (Değişiklik yok)
void OnDataSentToTransmitter(const uint8_t *mac_addr, esp_now_send_status_t status) { }

// ESP-NOW alma callback'i (Veriyi ana döngüye işaretler)
void OnDataReceivedFromTransmitter(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
  if (len != sizeof(struct_sensor_data) || newDataAvailable) {
    return;
  }
  memcpy(&dataToProcess, incomingData, sizeof(struct_sensor_data));
  newDataAvailable = true;
}

// Veri isteme fonksiyonu (Değişiklik yok)
void sendDataRequest(const uint8_t *targetMac) {
    esp_now_send(targetMac, (uint8_t *) &requestPayload, sizeof(requestPayload));
}

// ======== SETUP FONKSİYONU ========
void setup() {
    Serial.begin(115200);
    delay(100);
    if (DEBUG_MODE) Serial.println("Düzeltilmiş Gateway Başlatılıyor...");
    
    // Hem AP hem de İstasyon modunu etkinleştir
    WiFi.mode(WIFI_AP_STA);
    
    // *** DÜZELTME: KANAL BELİRTMEYİ KALDIRDIK. ***
    // Böylece varsayılan kanalı (genellikle 1) kullanacak ve vericilerle eşleşecek.
    WiFi.softAP(ssid, password);
    
    IPAddress myIP = WiFi.softAPIP();

    if (DEBUG_MODE) {
      Serial.print("AP Başlatıldı. SSID: "); Serial.println(ssid);
      Serial.print("IP Adresi: "); Serial.println(myIP);
    }

    webSocket.begin();
    webSocket.onEvent(webSocketEvent);
    
    if (esp_now_init() != ESP_OK) { Serial.println("ESP-NOW Hatası"); return; }
    esp_now_register_send_cb(OnDataSentToTransmitter);
    esp_now_register_recv_cb(OnDataReceivedFromTransmitter);
    
    for (int i = 0; i < NUM_TRANSMITTERS; ++i) {
        memcpy(peerInfoTransmitters[i].peer_addr, transmitterMacs[i], 6);
        // *** DÜZELTME: KANAL BELİRTMEYİ BURADAN DA KALDIRDIK ***
        // 0 değeri, varsayılan kanalı kullanmasını sağlar.
        peerInfoTransmitters[i].channel = 0;  
        peerInfoTransmitters[i].encrypt = false;
        if (esp_now_add_peer(&peerInfoTransmitters[i]) != ESP_OK){
          Serial.printf("Peer %d eklenemedi\n", i+1);
          return;
        }
    }
    strcpy(requestPayload.command, "GET"); 
}

// Zamanlayıcı değişkenleri
const unsigned long POLLING_INTERVAL_MS = 25;
unsigned long lastRequestTimeESP_NOW = 0;
int currentTransmitterIndex = 0;

// ======== LOOP FONKSİYONU (Stabil versiyon) ========
void loop() {
    webSocket.loop(); 

    if (newDataAvailable) {
        if (DEBUG_MODE) {
            Serial.printf("İşleniyor -> ID:%d | X:%.2f | Y:%.2f | Z:%.2f | Bileşke:%.2f\n", 
                dataToProcess.sender_id, dataToProcess.ax, dataToProcess.ay, dataToProcess.az, dataToProcess.magnitude);
        }

        StaticJsonDocument<200> jsonDoc;
        jsonDoc["id"] = dataToProcess.sender_id;
        jsonDoc["ax"] = dataToProcess.ax;
        jsonDoc["ay"] = dataToProcess.ay;
        jsonDoc["az"] = dataToProcess.az;
        jsonDoc["mag"] = dataToProcess.magnitude;
        
        String jsonString;
        serializeJson(jsonDoc, jsonString);
        webSocket.broadcastTXT(jsonString);
        
        newDataAvailable = false;
    }

    unsigned long currentMillis = millis();
    if (currentMillis - lastRequestTimeESP_NOW >= POLLING_INTERVAL_MS) {
        lastRequestTimeESP_NOW = currentMillis;
        sendDataRequest(transmitterMacs[currentTransmitterIndex]);
        currentTransmitterIndex = (currentTransmitterIndex + 1) % NUM_TRANSMITTERS; 
    }
}
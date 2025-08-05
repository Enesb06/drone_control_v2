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
    int sender_id; 
    float ax; 
    float ay; 
    float az; 
    float magnitude;
} struct_sensor_data;

typedef struct struct_request_data {
    char command[10]; 
} struct_request_data;
struct_request_data requestPayload;

// Veri işleme için Flag
volatile bool newDataAvailable = false;
struct_sensor_data dataToProcess;

// Zamanlayıcı değişkenleri
// Sabit 20ms'lik yoklama aralığı
const unsigned long POLLING_INTERVAL_MS = 5; 
unsigned long lastRequestTimeESP_NOW = 0;
int currentTransmitterIndex = 0;

// Boş veri gönderme kontrolü
unsigned long lastEmptyDataSent = 0;
const unsigned long EMPTY_DATA_INTERVAL = 100; // 100ms
bool hasRealData = false;
unsigned long lastRealDataTime = 0;
const unsigned long REAL_DATA_TIMEOUT = 2000; // 2 saniye

// ESP-NOW kontrol değişkenleri
bool espNowStarted = false;
bool webSocketClientConnected = false;
unsigned long firstClientConnectTime = 0;
const unsigned long ESP_NOW_DELAY = 3000; // WebSocket bağlantısından 3 saniye sonra başlat

// Geliştirme: Gönderim durumunu takip etmek için bayrak
volatile bool espNowSendInProgress = false;

// WebSocket olayları için callback
void webSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
    switch(type) {
        case WStype_DISCONNECTED:
            if (DEBUG_MODE) Serial.printf("[%u] WebSocket bağlantısı koptu!\n", num);
            webSocketClientConnected = false;
            break;
        case WStype_CONNECTED: {
            IPAddress ip = webSocket.remoteIP(num);
            if (DEBUG_MODE) Serial.printf("[%u] WebSocket bağlandı. IP: %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
            
            if (!webSocketClientConnected) {
                webSocketClientConnected = true;
                firstClientConnectTime = millis();
                if (DEBUG_MODE) Serial.println("İlk WebSocket bağlantısı - ESP-NOW zamanlayıcısı başlatıldı");
            }
        }
        break;
        case WStype_TEXT:
            if (DEBUG_MODE) Serial.printf("[%u] Gelen metin: %s\n", num, payload);
            break;
        default:
            break;
    }
}

// ESP-NOW gönderme callback'i
void OnDataSentToTransmitter(const uint8_t *mac_addr, esp_now_send_status_t status) {
    espNowSendInProgress = false;
    if (status != ESP_NOW_SEND_SUCCESS) {
        // Hata mesajlarını sınırla
        static unsigned long lastErrorLog = 0;
        if (millis() - lastErrorLog > 10000) {
            if (DEBUG_MODE) Serial.println("ESP-NOW: Vericiler yanıt vermiyor");
            lastErrorLog = millis();
        }
    }
}

// ESP-NOW alma callback'i
void OnDataReceivedFromTransmitter(const esp_now_recv_info_t *recv_info, const uint8_t *incomingData, int len) {
    if (len != sizeof(struct_sensor_data) || newDataAvailable) {
        return;
    }
    memcpy(&dataToProcess, incomingData, sizeof(struct_sensor_data));
    newDataAvailable = true;
}

// Veri isteme fonksiyonu
void sendDataRequest(const uint8_t *targetMac) {
    // Sadece daha önce bir gönderim devam etmiyorsa yeni bir istek gönder.
    if (!espNowSendInProgress) {
        esp_err_t result = esp_now_send(targetMac, (uint8_t *) &requestPayload, sizeof(requestPayload));
        if (result == ESP_OK) {
            espNowSendInProgress = true;
        } else {
            // Eğer gönderim fonksiyonu hata döndürürse, bloklama olmaz.
            // Sadece bir sonraki pollingde tekrar deneriz.
            if (DEBUG_MODE) Serial.println("ESP-NOW gönderim hatası, tekrar denenecek.");
        }
    }
}

// Boş veri gönder (sadece zaman ekseninin ilerlemesi için)
void sendEmptyData() {
    if (millis() - lastEmptyDataSent > EMPTY_DATA_INTERVAL) {
        lastEmptyDataSent = millis();
        
        StaticJsonDocument<50> jsonDoc;
        jsonDoc["timestamp"] = millis();
        jsonDoc["empty"] = true;
        
        String jsonString;
        serializeJson(jsonDoc, jsonString);
        
        if (webSocket.connectedClients() > 0) {
            webSocket.broadcastTXT(jsonString);
            
            static unsigned long lastLog = 0;
            if (millis() - lastLog > 5000) {
                if (DEBUG_MODE) Serial.println("Boş grafik akıyor - gerçek veri bekleniyor...");
                lastLog = millis();
            }
        }
    }
}

// ESP-NOW'u başlat (WebSocket bağlantısından sonra)
void startESPNow() {
    if (espNowStarted) return;
    
    if (DEBUG_MODE) Serial.println("ESP-NOW başlatılıyor...");
    
    if (esp_now_init() != ESP_OK) { 
        Serial.println("ESP-NOW başlatma hatası!"); 
        return; 
    }
    
    esp_now_register_send_cb(OnDataSentToTransmitter);
    esp_now_register_recv_cb(OnDataReceivedFromTransmitter);
    
    for (int i = 0; i < NUM_TRANSMITTERS; ++i) {
        memcpy(peerInfoTransmitters[i].peer_addr, transmitterMacs[i], 6);
        peerInfoTransmitters[i].channel = 0;
        peerInfoTransmitters[i].encrypt = false;
        
        if (esp_now_add_peer(&peerInfoTransmitters[i]) != ESP_OK){
            Serial.printf("Peer %d (V%d) eklenemedi\n", i, i+1);
        } else if (DEBUG_MODE) {
            Serial.printf("Peer %d (V%d) eklendi\n", i, i+1);
        }
    }
    
    strcpy(requestPayload.command, "GET");
    espNowStarted = true;
    
    if (DEBUG_MODE) Serial.println("ESP-NOW başarıyla başlatıldı - veri istekleri başlıyor");
}

// ======== SETUP FONKSİYONU ========
void setup() {
    Serial.begin(115200);
    delay(100);
    if (DEBUG_MODE) Serial.println("=== Hibrit Gateway Başlatılıyor ===");
    
    WiFi.mode(WIFI_AP_STA);
    
    bool apStarted = WiFi.softAP(ssid, password);
    IPAddress myIP = WiFi.softAPIP();

    if (DEBUG_MODE) {
        Serial.printf("AP Başlatıldı: %s\n", apStarted ? "BAŞARILI" : "HATA");
        Serial.printf("SSID: %s\n", ssid);
        Serial.printf("IP Adresi: %s\n", myIP.toString().c_str());
    }

    webSocket.begin();
    webSocket.onEvent(webSocketEvent);
    if (DEBUG_MODE) Serial.printf("WebSocket sunucu port %d'de başlatıldı\n", WEBSOCKET_PORT);
    
    if (DEBUG_MODE) {
        Serial.println("=== Gateway hazır! ===");
        Serial.println("WebSocket bekleniyor...");
        Serial.println("ESP-NOW henüz başlatılmadı");
        Serial.println("========================");
    }
}

// ======== LOOP FONKSİYONU ========
void loop() {
    webSocket.loop(); 

    if (webSocketClientConnected && !espNowStarted && 
        millis() - firstClientConnectTime > ESP_NOW_DELAY) {
        startESPNow();
    }

    if (newDataAvailable) {
        if (!hasRealData) {
            hasRealData = true;
            if (DEBUG_MODE) Serial.println("İlk gerçek veri alındı - boş veri modu durduruldu");
        }
        lastRealDataTime = millis();
        
        if (DEBUG_MODE) {
            Serial.printf("Gerçek veri -> ID:%d | X:%.2f | Y:%.2f | Z:%.2f | Mag:%.2f\n", 
                dataToProcess.sender_id, dataToProcess.ax, dataToProcess.ay, 
                dataToProcess.az, dataToProcess.magnitude);
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

    if (hasRealData && (millis() - lastRealDataTime > REAL_DATA_TIMEOUT)) {
        hasRealData = false;
        if (DEBUG_MODE) {
            Serial.println("Gerçek veri timeout - boş grafik moduna geçiliyor");
        }
    }

    // Gönderim işlemi devam etmiyorsa ve aralık dolduysa yeni istek gönder.
    if (espNowStarted && !espNowSendInProgress) {
        unsigned long currentMillis = millis();
        if (currentMillis - lastRequestTimeESP_NOW >= POLLING_INTERVAL_MS) {
            lastRequestTimeESP_NOW = currentMillis;
            sendDataRequest(transmitterMacs[currentTransmitterIndex]);
            currentTransmitterIndex = (currentTransmitterIndex + 1) % NUM_TRANSMITTERS; 
        }
    }
    
    if (!hasRealData && webSocket.connectedClients() > 0) {
        sendEmptyData();
    }
}

#include "csi_udp_sender.h"

#include <string.h>
#include "esp_log.h"
#include "lwip/sockets.h"
#include "sdkconfig.h"

static const char *TAG = "csi_udp";
static int s_sock = -1;
static struct sockaddr_in s_dest_addr;

// _parse_esp32_json() on the host reshapes the raw buffer into (N/2, 2)
// I/Q pairs, so we just forward data->buf verbatim as a flat int list --
// no amplitude/phase computation needed or wanted here.
//
// Cap chosen to stay under the ~2000-byte UDP MTU the host listens with:
// worst case each int8 value renders as up to 4 chars ("-128,"), so 256
// values -> ~1024 bytes of csi array plus ~60 bytes of surrounding JSON.
// If you set SHOULD_COLLECT_ONLY_LLTF=n (HT-LTF/STBC included, up to ~384
// bytes), raise CSI_UDP_JSON_BUF_SIZE accordingly and re-check this cap.
#define CSI_UDP_MAX_VALUES    256
#define CSI_UDP_JSON_BUF_SIZE 2048

void csi_udp_sender_init(void)
{
    s_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (s_sock < 0) {
        ESP_LOGE(TAG, "Unable to create UDP socket: errno %d", errno);
        return;
    }

    memset(&s_dest_addr, 0, sizeof(s_dest_addr));
    s_dest_addr.sin_family = AF_INET;
    s_dest_addr.sin_port = htons(CONFIG_UDP_TARGET_PORT);
    inet_pton(AF_INET, CONFIG_UDP_TARGET_IP, &s_dest_addr.sin_addr);

    ESP_LOGI(TAG, "UDP CSI sender targeting %s:%d",
             CONFIG_UDP_TARGET_IP, CONFIG_UDP_TARGET_PORT);
}

void csi_udp_sender_send(const wifi_csi_info_t *data)
{
    if (s_sock < 0) {
        return; // init() wasn't called or socket() failed
    }

    static char json_buf[CSI_UDP_JSON_BUF_SIZE];
    int offset = 0;

    int n = data->len;
    if (n > CSI_UDP_MAX_VALUES) {
        n = CSI_UDP_MAX_VALUES;
    }

    // type MUST start with "CSI" (case-insensitive) -- _parse_esp32_json
    // discards anything else. mac/rssi/len are read defensively via
    // obj.get() on the host so their exact presence isn't load-bearing,
    // but including them costs little and helps with debugging/logging.
    offset += snprintf(json_buf + offset, CSI_UDP_JSON_BUF_SIZE - offset,
        "{\"type\":\"CSI_DATA\",\"mac\":\"%02x:%02x:%02x:%02x:%02x:%02x\","
        "\"rssi\":%d,\"len\":%d,\"csi\":[",
        data->mac[0], data->mac[1], data->mac[2],
        data->mac[3], data->mac[4], data->mac[5],
        data->rx_ctrl.rssi,
        data->len);

    // Raw interleaved I/Q bytes, forwarded as-is -- the host does the
    // reshape-to-complex itself.
    for (int i = 0; i < n; i++) {
        offset += snprintf(json_buf + offset, CSI_UDP_JSON_BUF_SIZE - offset,
                            "%s%d", (i == 0 ? "" : ","), (int)data->buf[i]);
    }

    offset += snprintf(json_buf + offset, CSI_UDP_JSON_BUF_SIZE - offset, "]}");

    int err = sendto(s_sock, json_buf, offset, 0,
                      (struct sockaddr *)&s_dest_addr, sizeof(s_dest_addr));
    if (err < 0) {
        ESP_LOGE(TAG, "sendto failed: errno %d", errno);
    }
}
#ifndef CSI_UDP_SENDER_H
#define CSI_UDP_SENDER_H

#include <cstring>
#include "esp_log.h"
#include "esp_wifi_types.h"
#include "lwip/sockets.h"
#include "sdkconfig.h"

// Header-only by design, matching this project's existing _components
// pattern (csi_component.h, time_component.h, etc. all put function
// bodies directly in the header). This means no CMakeLists.txt edit is
// needed to add a source file -- it just gets #include'd into main.cc's
// single translation unit.
//
// `static` linkage is intentional: if this header is ever included from
// more than one .cc file, each translation unit gets its own private
// copy of these globals/functions rather than colliding at link time.

static const char *CSI_UDP_TAG = "csi_udp";
static int csi_udp_sock = -1;
static struct sockaddr_in csi_udp_dest_addr;

// _parse_esp32_json() on the wifi-3d-fusion host reshapes the raw buffer
// into (N/2, 2) I/Q pairs itself -- we forward data->buf verbatim as a
// flat int list, no amplitude/phase computation here.
//
// Cap chosen to stay under the ~2000-byte UDP MTU the host listens with.
// If SHOULD_COLLECT_ONLY_LLTF=n (HT-LTF/STBC included, larger buffers),
// raise CSI_UDP_JSON_BUF_SIZE and re-check this cap.
#define CSI_UDP_MAX_VALUES    256
#define CSI_UDP_JSON_BUF_SIZE 2048

static inline void csi_udp_sender_init(void) {
    if (csi_udp_sock >= 0) {
        close(csi_udp_sock);
        csi_udp_sock = -1;
    }

    csi_udp_sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_IP);
    if (csi_udp_sock < 0) {
        ESP_LOGE(CSI_UDP_TAG, "Unable to create UDP socket: errno %d", errno);
        return;
    }

    memset(&csi_udp_dest_addr, 0, sizeof(csi_udp_dest_addr));
    csi_udp_dest_addr.sin_family = AF_INET;
    csi_udp_dest_addr.sin_port = htons(CONFIG_UDP_TARGET_PORT);
    inet_pton(AF_INET, CONFIG_UDP_TARGET_IP, &csi_udp_dest_addr.sin_addr);

    ESP_LOGI(CSI_UDP_TAG, "UDP CSI sender targeting %s:%d",
             CONFIG_UDP_TARGET_IP, CONFIG_UDP_TARGET_PORT);
}

static inline void csi_udp_sender_send(const wifi_csi_info_t *data) {
    if (csi_udp_sock < 0) {
        return; // init() wasn't called yet, or socket() failed
    }

    static char json_buf[CSI_UDP_JSON_BUF_SIZE];
    int offset = 0;

    int n = data->len;
    if (n > CSI_UDP_MAX_VALUES) {
        n = CSI_UDP_MAX_VALUES;
    }

    // type MUST start with "CSI" (case-insensitive) -- the host's
    // _parse_esp32_json discards anything else.
    offset += snprintf(json_buf + offset, CSI_UDP_JSON_BUF_SIZE - offset,
        "{\"type\":\"CSI_DATA\",\"mac\":\"%02x:%02x:%02x:%02x:%02x:%02x\","
        "\"rssi\":%d,\"len\":%d,\"csi\":[",
        data->mac[0], data->mac[1], data->mac[2],
        data->mac[3], data->mac[4], data->mac[5],
        data->rx_ctrl.rssi,
        data->len);

    for (int i = 0; i < n; i++) {
        offset += snprintf(json_buf + offset, CSI_UDP_JSON_BUF_SIZE - offset,
                            "%s%d", (i == 0 ? "" : ","), (int) data->buf[i]);
    }

    offset += snprintf(json_buf + offset, CSI_UDP_JSON_BUF_SIZE - offset, "]}");

    int err = sendto(csi_udp_sock, json_buf, offset, 0,
                      (struct sockaddr *) &csi_udp_dest_addr, sizeof(csi_udp_dest_addr));
    if (err < 0) {
        ESP_LOGE(CSI_UDP_TAG, "sendto failed: errno %d", errno);
    }
}

#endif // CSI_UDP_SENDER_H
#ifndef CSI_UDP_SENDER_H
#define CSI_UDP_SENDER_H

#include "esp_wifi_types.h"

#ifdef __cplusplus
extern "C" {
#endif

void csi_udp_sender_init(void);
void csi_udp_sender_send(const wifi_csi_info_t *data);

#ifdef __cplusplus
}
#endif

#endif // CSI_UDP_SENDER_H
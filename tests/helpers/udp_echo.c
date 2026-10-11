/* UDP fixture without stream EOF semantics or forked receivers. */
#include <sys/socket.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
    int s = socket(AF_INET, SOCK_DGRAM, 0);
    struct sockaddr_in a = {.sin_family = AF_INET, .sin_port = htons(18081)};
    char b[65536];
    if (s < 0) { perror("socket"); return 1; }
    if (argc == 1) {
        if (bind(s, (void *)&a, sizeof(a))) { perror("bind"); return 1; }
        for (;;) {
            struct sockaddr_in p; socklen_t l = sizeof(p);
            ssize_t n = recvfrom(s, b, sizeof(b), 0, (void *)&p, &l);
            if (n < 0 || sendto(s, b, n, 0, (void *)&p, l) != n) { perror("echo"); return 1; }
        }
    }
    if (argc != 3 || inet_pton(AF_INET, argv[1], &a.sin_addr) != 1) return 2;
    struct timeval timeout = {.tv_sec = 3};
    if (setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)) ||
        connect(s, (void *)&a, sizeof(a))) { perror("connect"); return 1; }
    /* Repeated requests on one socket, including a valid empty datagram. */
    for (int i = 0; i < 4; i++) {
        size_t len = i == 3 ? 0 : strlen(argv[2]);
        if (send(s, argv[2], len, 0) != (ssize_t)len) { perror("send"); return 1; }
        ssize_t n = recv(s, b, sizeof(b), 0);
        if (n != (ssize_t)len || memcmp(b, argv[2], len)) {
            fprintf(stderr, "UDP echo mismatch/timeout: %zd\n", n); return 1;
        }
    }
    puts(argv[2]);
    close(s);
    return 0;
}

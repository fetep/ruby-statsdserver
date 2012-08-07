#include <stdio.h>
#include <stdlib.h>
#include <netinet/ip.h>

int main(int argc, char **argv, char **envp) {
    char *buffer = "stress:1|c";
    struct sockaddr_in dst;
    int s, ret, i;

    s = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (s < 0) {
        printf("socket() returned=%d\n", s);
        return EXIT_FAILURE;
    }

    dst.sin_family = AF_INET;
    dst.sin_addr.s_addr = inet_addr("127.0.0.1");
    dst.sin_port = htons(8125);

    // for (i = 0; i < 50000; i++) {
    for (;;) {
        ret = sendto(s, buffer, 10 /* length of buffer */, 0,
                     (struct sockaddr *) &dst, sizeof(dst));
        if (ret < 0) {
            printf("sendto() returned=%d\n", ret);
            return EXIT_FAILURE;
        }
    }
}

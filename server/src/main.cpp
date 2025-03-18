#include <iostream>
#include <thread>

#include <docopt.h>

#include "server.h"

static const char USEAGE[] =
R"(The Balls Server
    Usage:
        example [options]

    Options:
        -h --help                 Show this screen.
        -V --version                 Show version.
        -p --port=<port>          Listen on port <port> [default: 8800].
        --timeout=<seconds>       Set timeout to <seconds> [default: 10].
)";

int main(int argc, const char **argv) {
    docopt::Options args =
            docopt::docopt(USEAGE, {argv + 1, argv + argc}, true, "theballs-server 0.1.0");
    return 0;
}

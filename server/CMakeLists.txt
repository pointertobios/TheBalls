cmake_minimum_required(VERSION 3.10)
project(server)

set(CMAKE_BUILD_PARALLEL_LEVEL 20)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(deps/docopt)
set(INCLUDE_PATHS
    ${CMAKE_CURRENT_SOURCE_DIR}/deps/docopt
)

add_executable(theballs-server
    src/main.cpp
    src/server.cpp
)
target_include_directories(theballs-server PRIVATE ${INCLUDE_PATHS})
target_link_libraries(theballs-server PRIVATE docopt)

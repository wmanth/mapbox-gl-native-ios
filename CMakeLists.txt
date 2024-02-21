cmake_minimum_required(VERSION 3.24)

add_subdirectory(./vendor/mapbox-gl-native)

project (mbgl)

include(${PROJECT_SOURCE_DIR}/platform/macos.cmake)

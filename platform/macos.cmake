include(${PROJECT_SOURCE_DIR}/platform/darwin.cmake)

set(MACOS_FRAMEWORK_VERSION "0.0.0" CACHE STRING "Framework version number")
set(MACOS_SIGNING_IDENTITY "-" CACHE STRING "CodeSign signing identity") 

message(STATUS "Framework version: ${MACOS_FRAMEWORK_VERSION}")
message(STATUS "CodeSign signing identity: ${MACOS_SIGNING_IDENTITY}")

set(MACOS_SRC
    ${DARWIN_SRC}
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLAnnotationImage.m
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLAttributionButton.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLCompassCell.m
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapView+IBAdditions.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapView+Impl.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapView+OpenGL.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapView.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLOpenGLLayer.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/NSColor+MGLAdditions.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/NSImage+MGLAdditions.mm
    ${PROJECT_SOURCE_DIR}/platform/macos/src/NSProcessInfo+MGLAdditions.m
)

set(MACOS_PUBLIC_HEADER
    ${DARWIN_PUBLIC_HEADER}
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLAnnotationImage.h
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapView.h
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapViewDelegate.h
    ${PROJECT_SOURCE_DIR}/platform/macos/src/MGLMapView+IBAdditions.h
    ${PROJECT_SOURCE_DIR}/platform/macos/src/Mapbox.h
)

set(MACOS_RESOURCES
    ${PROJECT_SOURCE_DIR}/platform/macos/sdk/mapbox.pdf
    ${PROJECT_SOURCE_DIR}/platform/macos/sdk/mapbox_helmet.pdf
    ${PROJECT_SOURCE_DIR}/platform/macos/sdk/default_marker.pdf
)

add_library(framework SHARED ${MACOS_SRC})

target_sources(framework
    PUBLIC
    ${MACOS_PUBLIC_HEADER}
    ${MACOS_RESOURCES}
)

target_compile_options(framework PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-std=c++14>
    $<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>
    -fobjc-arc -fno-rtti -fvisibility=hidden
    -fmodule-name=Mapbox
    -Werror -Wall
    -Wno-unused-property-ivar
    -Wno-deprecated-declarations
    -Wno-compare-distinct-pointer-types
)

target_link_libraries(framework
    mbgl-core
    mbgl-vendor-icu
    mbgl-vendor-parsedate
    mbgl-vendor-csscolorparser
    "-framework CoreImage"
    "-framework QuartzCore"
)

set_target_properties(framework PROPERTIES
    OUTPUT_NAME Mapbox
    FRAMEWORK TRUE
    FRAMEWORK_VERSION A
    MACOSX_FRAMEWORK_IDENTIFIER "com.mapbox.Mapbox"
    MACOSX_FRAMEWORK_BUNDLE_VERSION "${MACOS_FRAMEWORK_VERSION}"
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING "${MACOS_FRAMEWORK_VERSION}"
    RESOURCE "${MACOS_RESOURCES}"
    PUBLIC_HEADER "${MACOS_PUBLIC_HEADER}"
)

add_custom_command(TARGET framework POST_BUILD
    COMMENT "Copying content $<PATH:RELATIVE_PATH,$<TARGET_FILE_DIR:framework>/Modules,${PROJECT_BINARY_DIR}>"
    COMMAND ${CMAKE_COMMAND} -E make_directory $<TARGET_FILE_DIR:framework>/Modules
    COMMAND ${CMAKE_COMMAND} -E create_symlink Versions/Current/Modules $<TARGET_FILE_DIR:framework>/../../Modules
    COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/platform/macos/module.modulemap $<TARGET_FILE_DIR:framework>/Modules
)

add_custom_command(TARGET framework POST_BUILD
    COMMENT "CodeSign $<PATH:RELATIVE_PATH,$<TARGET_FILE:framework>,${PROJECT_BINARY_DIR}>"
    COMMAND codesign --sign "${MACOS_SIGNING_IDENTITY}" --timestamp=none --generate-entitlement-der $<TARGET_FILE:framework>
)

target_include_directories(
    framework PUBLIC
    ${PROJECT_SOURCE_DIR}/platform/darwin/src
    ${PROJECT_SOURCE_DIR}/platform/macos/src
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/src
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/platform/default/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/platform/darwin/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/deps/variant/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/deps/geometry.hpp/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/deps/geojson.hpp/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/deps/optional
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/extras/rapidjson/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/mapbox-base/extras/expected-lite/include
    ${PROJECT_SOURCE_DIR}/vendor/mapbox-gl-native/vendor/polylabel/include
)

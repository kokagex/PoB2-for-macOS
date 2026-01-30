cmake_minimum_required(VERSION 3.16)
project(SimpleGraphicMacOS VERSION 1.0.0 LANGUAGES C CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

# Platform detection
if(NOT APPLE)
    message(FATAL_ERROR "This project is macOS-only")
endif()

# Graphics backend selection
set(SG_BACKEND "metal" CACHE STRING "Graphics backend (metal or opengl)")
set_property(CACHE SG_BACKEND PROPERTY STRINGS metal opengl)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Graphics backend: ${SG_BACKEND}")

# Find dependencies
find_package(PkgConfig REQUIRED)

# GLFW for window management
pkg_check_modules(GLFW REQUIRED glfw3)

# FreeType for text rendering
pkg_check_modules(FREETYPE REQUIRED freetype2)

# Lua (prefer LuaJIT, fallback to Lua 5.1)
pkg_check_modules(LUA luajit)
if(NOT LUA_FOUND)
    pkg_check_modules(LUA REQUIRED lua5.1)
endif()

# zlib for compression
find_package(ZLIB REQUIRED)

# Metal/Cocoa frameworks (macOS)
if(SG_BACKEND STREQUAL "metal")
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(QUARTZCORE_FRAMEWORK QuartzCore REQUIRED)
    find_library(COCOA_FRAMEWORK Cocoa REQUIRED)
    find_library(IOKIT_FRAMEWORK IOKit REQUIRED)
    find_library(COREVIDEO_FRAMEWORK CoreVideo REQUIRED)

    message(STATUS "Metal framework: ${METAL_FRAMEWORK}")
    message(STATUS "MetalKit framework: ${METALKIT_FRAMEWORK}")
endif()

# OpenGL (fallback)
if(SG_BACKEND STREQUAL "opengl")
    find_package(OpenGL REQUIRED)
    message(STATUS "OpenGL libraries: ${OPENGL_LIBRARIES}")
endif()

# Source files
set(SG_CORE_SOURCES
    src/core/sg_core.cpp
    src/core/sg_state.cpp
)

set(SG_WINDOW_SOURCES
    src/window/sg_window.cpp
    src/window/sg_input.cpp
)

set(SG_RENDERING_SOURCES
    src/rendering/sg_renderer.cpp
    src/rendering/sg_draw.cpp
    src/rendering/sg_image.cpp
    src/rendering/sg_text.cpp
)

set(SG_UTILITIES_SOURCES
    src/utilities/sg_filesystem.cpp
    src/utilities/sg_compression.cpp
    src/utilities/sg_clipboard.cpp
    src/utilities/sg_console.cpp
    src/utilities/sg_module.cpp
)

set(SG_LUA_SOURCES
    src/lua/sg_lua_bindings.cpp
)

# Backend-specific sources
if(SG_BACKEND STREQUAL "metal")
    set(SG_BACKEND_SOURCES
        src/backend/metal/metal_backend.mm
        src/backend/metal/metal_pipeline.mm
    )

    # Note: Metal shaders will be compiled at runtime
    # No pre-compilation needed
else()
    set(SG_BACKEND_SOURCES
        src/backend/opengl/gl_backend.cpp
        src/backend/opengl/gl_shaders.cpp
    )
endif()

# Build shared library
add_library(simplegraphic SHARED
    ${SG_CORE_SOURCES}
    ${SG_WINDOW_SOURCES}
    ${SG_RENDERING_SOURCES}
    ${SG_UTILITIES_SOURCES}
    ${SG_LUA_SOURCES}
    ${SG_BACKEND_SOURCES}
)

# Include directories
target_include_directories(simplegraphic
    PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
        $<INSTALL_INTERFACE:include>
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
        ${GLFW_INCLUDE_DIRS}
        ${FREETYPE_INCLUDE_DIRS}
        ${LUA_INCLUDE_DIRS}
)

# Compile definitions
target_compile_definitions(simplegraphic PRIVATE
    SG_BACKEND_${SG_BACKEND}
)

if(SG_BACKEND STREQUAL "metal")
    target_compile_definitions(simplegraphic PRIVATE SG_USE_METAL)
else()
    target_compile_definitions(simplegraphic PRIVATE SG_USE_OPENGL)
endif()

# Compiler flags
target_compile_options(simplegraphic PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    $<$<CONFIG:Debug>:-g -O0>
    $<$<CONFIG:Release>:-O3>
)

# Link libraries
target_link_libraries(simplegraphic
    ${GLFW_LIBRARIES}
    ${FREETYPE_LIBRARIES}
    ${LUA_LIBRARIES}
    ZLIB::ZLIB
)

if(SG_BACKEND STREQUAL "metal")
    target_link_libraries(simplegraphic
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${QUARTZCORE_FRAMEWORK}
        ${COCOA_FRAMEWORK}
        ${IOKIT_FRAMEWORK}
        ${COREVIDEO_FRAMEWORK}
    )
else()
    target_link_libraries(simplegraphic
        ${OPENGL_LIBRARIES}
    )
endif()

# Set library output name
set_target_properties(simplegraphic PROPERTIES
    OUTPUT_NAME "SimpleGraphic"
    PREFIX "lib"
    SUFFIX ".dylib"
    MACOSX_RPATH ON
    BUILD_WITH_INSTALL_RPATH ON
    INSTALL_RPATH "@loader_path"
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
)

# Installation
install(TARGETS simplegraphic
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES include/simplegraphic.h
    DESTINATION include
)

# Testing
enable_testing()

# Print configuration summary
message(STATUS "=================================")
message(STATUS "SimpleGraphic Configuration")
message(STATUS "=================================")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "Graphics backend: ${SG_BACKEND}")
message(STATUS "GLFW: ${GLFW_VERSION}")
message(STATUS "FreeType: ${FREETYPE_VERSION}")
message(STATUS "Lua: ${LUA_VERSION}")
message(STATUS "Install prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "=================================")

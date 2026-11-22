cmake_minimum_required(VERSION 3.10)
project(runner LANGUAGES CXX)

set(BINARY_NAME "ani_mobile")
set(APPLICATION_ID "com.animobile.ani_mobile")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "$ORIGIN/lib")

# Configure build options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "MinSizeRel" "RelWithDebInfo")
endif()

# Compilation flags
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Required GTK and Flutter dependencies
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

# Optional libmpv for media_kit
pkg_check_modules(MPV IMPORTED_TARGET mpv)

add_subdirectory("flutter")

# Application binary
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
)

# Apply compilation flags.
target_compile_options(${BINARY_NAME} PRIVATE -Wall -Werror)

# Target dependencies
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
if(TARGET PkgConfig::MPV)
  target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::MPV)
endif()

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

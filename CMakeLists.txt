cmake_minimum_required(VERSION 3.21)

project(video-trimmer VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 OpenGL)
include(GNUInstallDirs)

# pkg-config only supplies hints: under MSYS2 it can report POSIX paths such as
# /ucrt64/include that a native Windows CMake cannot use directly.
find_package(PkgConfig QUIET)
if(PKG_CONFIG_FOUND)
    pkg_check_modules(PC_MPV QUIET mpv)
endif()
find_path(MPV_INCLUDE_DIR mpv/client.h HINTS ${PC_MPV_INCLUDE_DIRS})
find_library(MPV_LIBRARY NAMES mpv libmpv HINTS ${PC_MPV_LIBRARY_DIRS})
if(NOT MPV_INCLUDE_DIR OR NOT MPV_LIBRARY)
    message(FATAL_ERROR "libmpv was not found. Install its development package.")
endif()
add_library(mpv::mpv UNKNOWN IMPORTED)
set_target_properties(mpv::mpv PROPERTIES
    IMPORTED_LOCATION "${MPV_LIBRARY}"
    INTERFACE_INCLUDE_DIRECTORIES "${MPV_INCLUDE_DIR}"
)

qt_standard_project_setup()

qt_add_executable(video-trimmer
    src/main.cpp
)

qt_add_qml_module(video-trimmer
    URI Trimmer
    VERSION 1.0
    RESOURCE_PREFIX /
    QML_FILES
        qml/Main.qml
        qml/Scrubber.qml
        qml/FileSidebar.qml
        qml/QueuePanel.qml
    SOURCES
        src/MpvItem.h src/MpvItem.cpp
        src/TrimJob.h src/TrimJob.cpp
        src/ExportQueue.h src/ExportQueue.cpp
        src/VideoFolderModel.h src/VideoFolderModel.cpp
)

target_link_libraries(video-trimmer PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::OpenGL
    mpv::mpv
)

target_include_directories(video-trimmer PRIVATE src)

set_target_properties(video-trimmer PROPERTIES
    WIN32_EXECUTABLE ON
    MACOSX_BUNDLE ON
)

install(TARGETS video-trimmer
    BUNDLE DESTINATION .
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

option(BUILD_TESTING "Build tests" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

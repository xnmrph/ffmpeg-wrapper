find_package(Qt6 REQUIRED COMPONENTS Test)

# The core classes, built once for every test.
add_library(trimmer_core STATIC
    ../src/TrimJob.h ../src/TrimJob.cpp
    ../src/ExportQueue.h ../src/ExportQueue.cpp
    ../src/VideoFolderModel.h ../src/VideoFolderModel.cpp
)
set_target_properties(trimmer_core PROPERTIES AUTOMOC ON)
target_include_directories(trimmer_core PUBLIC ../src)
target_link_libraries(trimmer_core PUBLIC Qt6::Core Qt6::Qml)

foreach(test tst_trimjob tst_exportqueue tst_videofoldermodel)
    qt_add_executable(${test} ${test}.cpp testclip.h)
    target_link_libraries(${test} PRIVATE trimmer_core Qt6::Test)
    add_test(NAME ${test} COMMAND ${test})
endforeach()

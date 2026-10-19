find_package(Qt6 REQUIRED COMPONENTS Test)

qt_add_executable(tst_trimjob
    tst_trimjob.cpp
    ../src/TrimJob.h ../src/TrimJob.cpp
)
target_include_directories(tst_trimjob PRIVATE ../src)
target_link_libraries(tst_trimjob PRIVATE Qt6::Core Qt6::Qml Qt6::Test)

add_test(NAME tst_trimjob COMMAND tst_trimjob)

set(CONSUMER_VERSION "${VERSION_A}")
include("${CMAKE_CURRENT_LIST_DIR}/../consumer.cmake")

if(NESTED_CONFLICT)
    add_subdirectory(child)
endif()

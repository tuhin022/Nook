cmake_minimum_required(VERSION 3.21)
project(NookDesktop LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(Qt6 REQUIRED COMPONENTS Widgets WebEngineWidgets)
qt_standard_project_setup()
qt_add_executable(NookDesktop main.cpp)
target_link_libraries(NookDesktop PRIVATE Qt6::Widgets Qt6::WebEngineWidgets)
add_custom_command(TARGET NookDesktop POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:NookDesktop>/web"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/../web/nook.html" "$<TARGET_FILE_DIR:NookDesktop>/web/nook.html"
  COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/../web/config.js" "$<TARGET_FILE_DIR:NookDesktop>/web/config.js"
)
if(WIN32)
  set_target_properties(NookDesktop PROPERTIES WIN32_EXECUTABLE TRUE)
endif()

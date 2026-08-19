cmake_minimum_required(VERSION 3.18)

project(pmpp LANGUAGES CXX CUDA)

# Keep CUDA include directories visible in compile_commands.json. CMake uses
# response files for these by default, but several clangd/LSP clients do not
# inspect the referenced .rsp file and consequently cannot resolve wb.h.
set(CMAKE_CUDA_USE_RESPONSE_FILE_FOR_INCLUDES OFF)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 11)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(FetchContent)
include(CTest)

# libwb is the course helper library used by every MP. Pin the revision so
# local builds stay reproducible, and apply a small modern-GCC compatibility
# fix while FetchContent prepares it.
FetchContent_Declare(
  libwb_source
  GIT_REPOSITORY https://github.com/abduld/libwb.git
  GIT_TAG 5b93896ec8fe55f4d9e19c0a864ef4a750ff3aac
  GIT_SHALLOW TRUE
  PATCH_COMMAND
    ${CMAKE_COMMAND}
    -DSOURCE_DIR=<SOURCE_DIR>
    -DPATCH_FILE=${CMAKE_CURRENT_SOURCE_DIR}/patches/libwb-gcc.patch
    -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/PatchLibwb.cmake
)
FetchContent_GetProperties(libwb_source)
if(NOT libwb_source_POPULATED)
  FetchContent_Populate(libwb_source)
endif()

file(GLOB LIBWB_SOURCES CONFIGURE_DEPENDS
  "${libwb_source_SOURCE_DIR}/*.cpp"
)
list(FILTER LIBWB_SOURCES EXCLUDE REGEX "_test\\.cpp$")
list(APPEND LIBWB_SOURCES "${libwb_source_SOURCE_DIR}/vendor/json11.cpp")

add_library(wb SHARED ${LIBWB_SOURCES})
target_include_directories(wb PUBLIC "${libwb_source_SOURCE_DIR}")
target_compile_definitions(wb PRIVATE WB_USE_COURSERA WB_USE_JSON11=0)
target_link_libraries(wb PRIVATE m)
if(UNIX AND NOT APPLE)
  target_link_libraries(wb PRIVATE rt)
endif()

function(add_mp number)
  set(target "mp${number}")
  add_executable(${target} "MP${number}/template.cu")
  target_link_libraries(${target} PRIVATE wb)
  set_target_properties(${target} PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/MP${number}"
    OUTPUT_NAME "template"
  )
endfunction()

foreach(number RANGE 0 8)
  add_mp(${number})
endforeach()

# MP0 has no input datasets.
add_test(NAME mp0-device-info COMMAND mp0)

function(add_vector_test mp dataset inputs extension)
  set(test_name "mp${mp}-dataset-${dataset}")
  add_test(
    NAME "${test_name}"
    COMMAND "${CMAKE_BINARY_DIR}/MP${mp}/template"
      -e "${CMAKE_CURRENT_SOURCE_DIR}/MP${mp}/data/${dataset}/output.${extension}"
      -i "${inputs}"
      -t vector
  )
  set_tests_properties("${test_name}" PROPERTIES
    FAIL_REGULAR_EXPRESSION "Solution is NOT correct"
  )
endfunction()

foreach(dataset RANGE 0 9)
  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP1/data/${dataset}")
  add_vector_test(1 ${dataset} "${base}/input0.raw,${base}/input1.raw" raw)

  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP2/data/${dataset}")
  add_vector_test(2 ${dataset} "${base}/input0.raw,${base}/input1.raw" raw)

  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP3/data/${dataset}")
  add_vector_test(3 ${dataset} "${base}/input0.raw,${base}/input1.raw" raw)

  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP5/data/${dataset}")
  add_vector_test(5 ${dataset} "${base}/input0.raw" raw)

  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP6/data/${dataset}")
  add_vector_test(6 ${dataset} "${base}/input.raw" raw)

  add_test(
    NAME "mp7-dataset-${dataset}"
    COMMAND "${CMAKE_BINARY_DIR}/MP7/template"
      -e "${CMAKE_CURRENT_SOURCE_DIR}/MP7/data/${dataset}/output.ppm"
      -i "${CMAKE_CURRENT_SOURCE_DIR}/MP7/data/${dataset}/input.ppm"
      -t image
  )
  set_tests_properties("mp7-dataset-${dataset}" PROPERTIES
    FAIL_REGULAR_EXPRESSION "Solution is NOT correct"
  )
endforeach()

foreach(dataset RANGE 0 5)
  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP4/data/${dataset}")
  add_vector_test(4 ${dataset} "${base}/input.dat,${base}/kernel.dat" dat)
endforeach()

foreach(dataset RANGE 0 6)
  set(base "${CMAKE_CURRENT_SOURCE_DIR}/MP8/data/${dataset}")
  add_vector_test(8 ${dataset}
    "${base}/col.raw,${base}/row.raw,${base}/data.raw,${base}/vec.raw" raw)
endforeach()

foreach(number RANGE 0 8)
  add_custom_target("run-mp${number}"
    COMMAND ${CMAKE_CTEST_COMMAND} --test-dir "${CMAKE_BINARY_DIR}"
      --verbose -R "^mp${number}-"
    DEPENDS "mp${number}"
    USES_TERMINAL
  )
endforeach()

# Most clangd-based editors discover this conventional source-root path.
file(CREATE_LINK
  "${CMAKE_BINARY_DIR}/compile_commands.json"
  "${CMAKE_CURRENT_SOURCE_DIR}/compile_commands.json"
  SYMBOLIC
)

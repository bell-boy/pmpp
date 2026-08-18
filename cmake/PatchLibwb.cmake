file(READ "${SOURCE_DIR}/vendor/json11.cpp" json11_source)
string(FIND "${json11_source}" "Ordering two null values is always false" patch_position)

if(patch_position EQUAL -1)
  execute_process(
    COMMAND git apply "${PATCH_FILE}"
    WORKING_DIRECTORY "${SOURCE_DIR}"
    RESULT_VARIABLE patch_result
    ERROR_VARIABLE patch_error
  )
  if(NOT patch_result EQUAL 0)
    message(FATAL_ERROR "Could not patch libwb: ${patch_error}")
  endif()
endif()

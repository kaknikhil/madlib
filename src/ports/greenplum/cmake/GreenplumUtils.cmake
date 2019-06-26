# Define Greenplum feature macros
#
function(define_greenplum_features IN_VERSION OUT_FEATURES)
    if(NOT ${IN_VERSION} VERSION_LESS "4.1")
        list(APPEND ${OUT_FEATURES} __HAS_ORDERED_AGGREGATES__)
    endif()

    if(NOT ${IN_VERSION} VERSION_LESS "4.3")
        list(APPEND ${OUT_FEATURES} __HAS_FUNCTION_PROPERTIES__)
    endif()

    if(${IN_VERSION} VERSION_GREATER "4.3")
        list(APPEND ${OUT_FEATURES} __HAS_BOOL_TO_TEXT_CAST__)
    endif()

    # Pass values to caller
    set(${OUT_FEATURES} "${${OUT_FEATURES}}" PARENT_SCOPE)
endfunction(define_greenplum_features)

function(add_gppkg GPDB_VERSION GPDB_VARIANT GPDB_VARIANT_SHORT UPGRADE_SUPPORT)
    # TODO make ubuntu gppkg
        # 1. pass OS_TYPE
        # 2. IF OS_TYPE == UBUNTU, then use the target `deb_gppkg` which is a new dir under deploy
        # 3. IF OS_TYPE == RHEL, do the same as before

    string(TOLOWER ${GPDB_VERSION} GPDB_VERSION_LC)
    string(REPLACE "." "_" VERSION_ "${GPDB_VERSION}")

    # Get information about the rhel version
    rh_version(RH_VERSION)
    string(REGEX MATCH "([0-9])" RH_MAJOR_VERSION "${RH_VERSION}")

    file(WRITE "${CMAKE_BINARY_DIR}/deploy/gppkg/${GPDB_VARIANT}_${VERSION_}_gppkg.cmake" "
    file(MAKE_DIRECTORY
        \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}/BUILD\"
        \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}/SPECS\"
        \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}/RPMS\"
        \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}/gppkg\"
    )

    set(GPDB_VERSION \"${GPDB_VERSION}\")
    set(GPDB_VERSION_LC \"${GPDB_VERSION_LC}\")
    set(GPDB_VARIANT \"${GPDB_VARIANT}\")
    set(GPDB_VARIANT_SHORT \"${GPDB_VARIANT_SHORT}\")
    set(UPGRADE_SUPPORT \"${UPGRADE_SUPPORT}\")
    set(RH_MAJOR_VERSION \"${RH_MAJOR_VERSION}\")
    string(TOLOWER \"${GPDB_VARIANT}\" PORT_NAME)

    configure_file(
        madlib.spec.in
        \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}/SPECS/madlib.spec\"
    )
    configure_file(
        gppkg_spec.yml.in
        \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}/gppkg/gppkg_spec.yml\"
    )

    if(GPPKG_BINARY)
        if(RHEL AND RPMBUILD_BINARY) # depend on RPMBUILD_BINARY only for rhel
            add_custom_target(gppkg_${GPDB_VARIANT}_${VERSION_}
                COMMAND cmake -E create_symlink \"\${MADLIB_GPPKG_RPM_SOURCE_DIR}\"
                    \"\${CPACK_PACKAGE_FILE_NAME}-gppkg\"
                COMMAND \"\${RPMBUILD_BINARY}\" -bb SPECS/madlib.spec
                COMMAND cmake -E rename \"RPMS/\${MADLIB_GPPKG_RPM_FILE_NAME}\"
                    \"gppkg/\${MADLIB_GPPKG_RPM_FILE_NAME}\"
                COMMAND \"\${GPPKG_BINARY}\" --build gppkg
                DEPENDS \"${CMAKE_BINARY_DIR}/\${CPACK_PACKAGE_FILE_NAME}.rpm\"
                WORKING_DIRECTORY \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}\"
                COMMENT \"Generating ${GPDB_VARIANT} ${GPDB_VERSION} gppkg installer...\"
                VERBATIM
            )
        else(UBUNTU)
            add_custom_target(gppkg_${GPDB_VARIANT}_${VERSION_}
                #TODO
                # Somehow call make package on the DEB_gppkg folder
                # move the deb file and the new gppkg spec file to the same folder i.e. build-dir/deploy/gppkg/gpdb_version/gppkg/.
                # Something similar to list(APPEND CPACK_GENERATOR(DEB)) in GreenplumUtils.cmake
                # set flag to indicate to make package that the deb is to be compiled for gppkg
                COMMAND make package -C /build/madlib/build_madlib_debug/
                COMMAND \"\${GPPKG_BINARY}\" --build gppkg
                WORKING_DIRECTORY \"\${CMAKE_CURRENT_BINARY_DIR}/${GPDB_VERSION}\"
                COMMENT \"Generating ${GPDB_VARIANT} ${GPDB_VERSION} gppkg installer...\"
                VERBATIM
            )
    else(GPPKG_BINARY)
        add_custom_target(gppkg_${GPDB_VARIANT}_${VERSION_}
            COMMAND cmake -E echo \"Could not find gppkg and/or rpmbuild.\"
                \"Please rerun cmake.\"
        )
    endif(GPPKG_BINARY)

    # Unfortunately, we cannot set a dependency to the built-in package target,
    # i.e., the following does not work:
    # add_dependencies(gppkg package)

    add_dependencies(gppkg gppkg_${GPDB_VARIANT}_${VERSION_})
    ")
endfunction(add_gppkg)


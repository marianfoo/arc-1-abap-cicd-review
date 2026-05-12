*"* use this source file for your ABAP unit test classes
class ltc_validation definition deferred.
class zcl_arc1_task_service definition local friends ltc_validation.

class ltc_validation definition final
  for testing
  duration short
  risk level harmless.

  private section.
    methods cut_returns_id_for_valid_title for testing.
    methods empty_title_raises             for testing.
endclass.


class ltc_validation implementation.

  method cut_returns_id_for_valid_title.
    data lo_cut type ref to zcl_arc1_task_service.
    create object lo_cut.

    try.
        lo_cut->validate_title( |My new task| ).
      catch cx_parameter_invalid_range.
        cl_abap_unit_assert=>fail( msg = |validate_title raised for a valid title| ).
    endtry.
  endmethod.

  method empty_title_raises.
    data lo_cut type ref to zcl_arc1_task_service.
    create object lo_cut.

    try.
        lo_cut->validate_title( || ).
        cl_abap_unit_assert=>fail( msg = |Empty title should raise| ).
      catch cx_parameter_invalid_range.
        " expected
    endtry.
  endmethod.

endclass.

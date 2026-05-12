class zcl_arc1_test_helpers definition
  public
  final
  create public
  for testing
  duration short
  risk level harmless.

  public section.
    "! Normalise free-form status text to the ZARC1_E_STATUS domain.
    "! Unknown values default to 'A' (active / open).
    class-methods normalize_status
      importing iv_raw         type clike
      returning value(rv_norm) type zarc1_e_status.

    "! Test whether a status code represents an OPEN task.
    class-methods is_open_status
      importing iv_status         type zarc1_e_status
      returning value(rv_is_open) type abap_bool.

  protected section.

  private section.
    methods normalize_active_uppercase for testing.
    methods normalize_active_lowercase for testing.
    methods normalize_done             for testing.
    methods normalize_unknown_defaults for testing.
    methods is_open_true               for testing.
    methods is_open_false              for testing.
    methods is_open_cancelled          for testing.
endclass.


class zcl_arc1_test_helpers implementation.

  method normalize_status.
    case to_upper( iv_raw ).
      when 'A' or 'ACTIVE' or 'OPEN'.   rv_norm = 'A'.
      when 'D' or 'DONE' or 'CLOSED'.   rv_norm = 'D'.
      when 'X' or 'CANCELLED'.          rv_norm = 'X'.
      when others.                       rv_norm = 'A'.
    endcase.
  endmethod.

  method is_open_status.
    rv_is_open = xsdbool( iv_status = 'A' ).
  endmethod.

  method normalize_active_uppercase.
    cl_abap_unit_assert=>assert_equals(
      exp = 'A'
      act = zcl_arc1_test_helpers=>normalize_status( 'ACTIVE' ) ).
  endmethod.

  method normalize_active_lowercase.
    cl_abap_unit_assert=>assert_equals(
      exp = 'A'
      act = zcl_arc1_test_helpers=>normalize_status( 'active' ) ).
  endmethod.

  method normalize_done.
    cl_abap_unit_assert=>assert_equals(
      exp = 'D'
      act = zcl_arc1_test_helpers=>normalize_status( 'DONE' ) ).
  endmethod.

  method normalize_unknown_defaults.
    cl_abap_unit_assert=>assert_equals(
      exp = 'A'
      act = zcl_arc1_test_helpers=>normalize_status( 'foobar' ) ).
  endmethod.

  method is_open_true.
    cl_abap_unit_assert=>assert_true(
      act = zcl_arc1_test_helpers=>is_open_status( 'A' ) ).
  endmethod.

  method is_open_false.
    cl_abap_unit_assert=>assert_false(
      act = zcl_arc1_test_helpers=>is_open_status( 'D' ) ).
  endmethod.

  method is_open_cancelled.
    cl_abap_unit_assert=>assert_false(
      act = zcl_arc1_test_helpers=>is_open_status( 'X' ) ).
  endmethod.

endclass.

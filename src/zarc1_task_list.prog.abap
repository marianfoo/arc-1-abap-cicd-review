*&---------------------------------------------------------------------*
*& Report ZARC1_TASK_LIST
*&---------------------------------------------------------------------*
*& ARC-1 demo: list tasks from ZARC1_T_TASK with optional status filter.
*&---------------------------------------------------------------------*
report zarc1_task_list.

" -- Seeded lint issue: chained DATA: BEGIN OF ... obsolete style ----- "
" -- Modern equivalent: use a TYPES declaration + a separate DATA stmt. "
types:
  begin of ty_filter,
    status type zarc1_e_status,
  end of ty_filter.

data gs_filter   type ty_filter.
data gt_tasks    type standard table of zarc1_t_task.
data go_service  type ref to zif_arc1_task_service.

selection-screen begin of block b1 with frame title text-001.
parameters: p_status type zarc1_e_status.
selection-screen end of block b1.

start-of-selection.

  go_service = new zcl_arc1_task_service( ).

  break-point.                "#EC NOOP — leftover debug breakpoint

  try.
      data(lt_result) = go_service->list_tasks( iv_status = p_status ).

    catch cx_root into data(lx_err).
      message lx_err->get_text( ) type 'I'.
      return.
  endtry.

  if lt_result is initial.
    message s001(00) with 'No tasks found'.
    return.
  endif.

  cl_salv_table=>factory(
    importing
      r_salv_table = data(lo_alv)
    changing
      t_table      = lt_result ).

  lo_alv->get_functions( )->set_all( ).
  lo_alv->display( ).

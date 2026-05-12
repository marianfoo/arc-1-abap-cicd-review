class zcl_arc1_task_service definition
  public
  final
  create public.

  public section.
    interfaces zif_arc1_task_service.

  protected section.

  private section.
    methods generate_task_id
      returning value(rv_task_id) type zarc1_t_task-task_id.

    methods validate_title
      importing iv_title type zarc1_t_task-title
      raising   cx_parameter_invalid_range.
endclass.


class zcl_arc1_task_service implementation.

  method zif_arc1_task_service~create_task.
    validate_title( iv_title ).

    data(lv_task_id) = generate_task_id( ).
    data ls_task type zarc1_t_task.

    ls_task-client     = sy-mandt.
    ls_task-task_id    = lv_task_id.
    ls_task-title      = iv_title.
    ls_task-status     = 'A'.
    ls_task-created_by = sy-uname.
    ls_task-created_at = cl_abap_tstmp=>utclong2tstmp_short( utclong_current( ) ).

    insert zarc1_t_task from @ls_task.
    if sy-subrc <> 0.
      raise exception type cx_sy_create_data_error.
    endif.

    rv_task_id = lv_task_id.
  endmethod.

  method zif_arc1_task_service~get_task.
    select single task_id, title, status, created_by, created_at
      from zarc1_t_task
      where task_id = @iv_task_id
      into corresponding fields of @rs_task.
    if sy-subrc <> 0.
      raise exception type cx_sy_itab_line_not_found.
    endif.
  endmethod.

  method zif_arc1_task_service~list_tasks.
    if iv_status is not initial.
      select task_id, title, status, created_by, created_at
        from zarc1_t_task
        where status = @iv_status
        order by created_at descending
        into corresponding fields of table @rt_tasks.
    else.
      select task_id, title, status, created_by, created_at
        from zarc1_t_task
        order by created_at descending
        into corresponding fields of table @rt_tasks.
    endif.
  endmethod.

  method zif_arc1_task_service~close_task.
    update zarc1_t_task
      set status = 'D'
      where task_id = @iv_task_id.
    if sy-subrc <> 0.
      raise exception type cx_sy_itab_line_not_found.
    endif.
  endmethod.

  method generate_task_id.
    try.
        data(lv_uuid) = cl_system_uuid=>create_uuid_c22_static( ).
        rv_task_id = lv_uuid+0(10).
      catch cx_uuid_error.
        rv_task_id = |T{ sy-datum }{ sy-uzeit }|.
    endtry.
  endmethod.

  method validate_title.
    if iv_title is initial.
      raise exception type cx_parameter_invalid_range
        exporting parameter = 'IV_TITLE'.
    endif.
  endmethod.

endclass.

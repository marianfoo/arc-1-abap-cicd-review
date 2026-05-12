interface zif_arc1_task_service public.

  types:
    begin of ty_task,
      task_id    type zarc1_t_task-task_id,
      title      type zarc1_t_task-title,
      status     type zarc1_e_status,
      created_by type zarc1_t_task-created_by,
      created_at type zarc1_t_task-created_at,
    end of ty_task,
    ty_tasks type standard table of ty_task with key task_id.

  methods create_task
    importing iv_title          type zarc1_t_task-title
    returning value(rv_task_id) type zarc1_t_task-task_id
    raising   cx_static_check.

  methods get_task
    importing iv_task_id      type zarc1_t_task-task_id
    returning value(rs_task)  type ty_task
    raising   cx_static_check.

  methods list_tasks
    importing iv_status        type zarc1_e_status optional
    returning value(rt_tasks)  type ty_tasks.

  methods close_task
    importing iv_task_id type zarc1_t_task-task_id
    raising   cx_static_check.

endinterface.

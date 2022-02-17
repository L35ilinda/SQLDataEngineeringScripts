SELECT
session_id,
start_time,
[status],
command,
blocking_session_id,
wait_type,
wait_time,
open_transaction_count,
transaction_id,
total_elapsed_time,
Definition = CAST(text AS VARCHAR(MAX))
FROM
SYS.DM_EXEC_REQUESTS
CROSS APPLY sys.dm_exec_sql_text(sql_handle)
WHERE blocking_session_id != 0

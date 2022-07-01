create or replace trigger omp_adm.test_event_log before insert or update of task_code on omp_adm.eventlog for each row 
DECLARE
    CONN         UTL_TCP.CONNECTION;
    RETVAL       BINARY_INTEGER;
    L_RESPONSE   VARCHAR2(1000) := '';
    L_TEXT  VARCHAR2(1000);    
    L_IP_HOST VARCHAR(30);
begin
if :new.task_code = 9000002 then
  SELECT UTL_INADDR.get_host_address(:new.computername) into l_ip_host FROM dual;
     --OPEN THE CONNECTION
    CONN := UTL_TCP.OPEN_CONNECTION(
        REMOTE_HOST   => l_ip_host,
        REMOTE_PORT   => 9898,
        TX_TIMEOUT    => 10
    );
    
    L_TEXT := 'Start 9000002';
    --WRITE TO SOCKET
    RETVAL := UTL_TCP.WRITE_LINE(CONN,L_TEXT);
    UTL_TCP.FLUSH(CONN);
 
    DBMS_OUTPUT.PUT_LINE('Response from Socket Server : ' || L_RESPONSE);
    UTL_TCP.CLOSE_CONNECTION(CONN);
end if;
end;
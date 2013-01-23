-- Script By Ivan Acosta
-- Version 1.0 

whenever sqlerror exit
set verify off
set echo off

declare
inp_par varchar2(1000):='&&1';
tst varchar2(1000);
qty number :=0;
begin
    select USERNAME into tst from dba_users where username=inp_par;
  if tst is null then
     raise_application_error(-20777,'Usuario no existe');
  end if;

  if inp_par is null then
     raise_application_error(-20778,'El parametro no puede ser nulo');
  end if;

select count(*) into qty from v$session where username=inp_par;
if qty = 0  then
      raise_application_error(-20779,'Este usuario no tiene session activas: '||to_char(inp_par));
end if;
end;
/

col sid for 999999
col serial# for 999999
col username for a12 trun
col program for a15 trun
col osuser for a8 trun
col spid for 99999
col status for a10 trun
select s.sid, s.serial#, s.username, s.osuser, s.program ,s.status
from v$session s
where s.username='&&1';

prompt Realmente desea terminar la session del usuario? (responder y para proceder)
accept zz
set serveroutput on
declare
answer varchar2(10):=substr('&&zz',1,1);
inst_name v$instance.instance_name%type;
inp_user v$session.username%type:='&&1';
sid v$session.sid%type;
ser v$session.serial#%type;
cursor c1 is
select s.sid, s.serial# into sid, ser  from v$session s where s.username='&&1';
--sqlStmt VARCHAR2(1000);
kill_it c1%ROWTYPE;
sep varchar2(100):= '=================================================================';
begin
select lower(instance_name) into inst_name from v$instance where rownum=1;

if answer='y' then
 OPEN c1;
 LOOP
    FETCH c1 INTO kill_it;
    EXIT WHEN c1%NOTFOUND;
    BEGIN
    dbms_output.put_line(sep);
    execute IMMEDIATE 'alter system kill session '''||kill_it.sid||','||kill_it.serial#||''''||'immediate'; 
    exception when others then 
    dbms_output.put_line('Alter session realizado');
    --dbms_output.put_line(sep);
    end;
end LOOP;
close c1;
else
  dbms_output.put_line(sep);
  dbms_output.put_line('No se realizo nada');
  dbms_output.put_line(sep);
end if;
end;
/
exit


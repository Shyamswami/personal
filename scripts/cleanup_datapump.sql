-- Script By Ivan Acosta
-- Version 1.0 

whenever sqlerror exit
set verify off
set echo off

declare
qty number :=0;
begin
select count(*) into qty from dba_datapump_jobs where state='NOT RUNNING'; 
if qty = 0  then
      raise_application_error(-20779,'No hay Procesos Huerfanos de Datapump');
end if;
end;
/

set linesize 200
set pagesize 100
col owner_name for a12 trun
col job_name for a20 trun
col operation for a10 trun
col job_mode for a7 trun
col state for a10 trun
col attached_sessions for 99999
select owner_name,job_name,operation,job_mode,state,attached_sessions from dba_datapump_jobs where state='NOT RUNNING';

set serveroutput on
declare
cursor c1 is
select owner_name,job_name from dba_datapump_jobs where state='NOT RUNNING';
borrado c1%ROWTYPE;
sep varchar2(100):= '=================================================================';
begin
dbms_output.put_line(sep);
 OPEN c1;
 LOOP
    FETCH c1 INTO borrado;
    EXIT WHEN c1%NOTFOUND;
    BEGIN
      dbms_output.put_line('La tabla '||borrado.job_name||' sera borrada y purgada..');
      execute immediate ('drop table ' || borrado.owner_name||'.'||borrado.job_name|| ' purge');
      dbms_output.put_line('Proceso Exitoso.....');
      exception when others then 
      dbms_output.put_line('Error de Ejecuccion por Favor verificar...!!'||sqlerrm);
    end;
  end LOOP;
close c1;
dbms_output.put_line(sep);
end;
/
exit


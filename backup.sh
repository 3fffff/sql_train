#!/bin/bash

# Usage: export.sh login/password@tnsalias table {table}
# Exports DDL statement, control file for SQL*Loader and the data itself

#=== SETTINGS ===

# quotation mark
_ENC=
#_ENC=\"
#_ENC=\~

# field separator (should be character or hexadecimal code with leading zero)
_SEP=09
#_SEP="|"

# max row count
#_ROWS=
#_ROWS=100000

# end-of-line (for character fields with linefeed)
_EOL=
#_EOL=@@@

RESERVED="'ACCESS','ADD','ALL','ALTER','AND','ANY','AS','ASC','AUDIT','BETWEEN','BY','CHAR','CHECK','CLUSTER','COLUMN','COMMENT','COMPRESS','CONNECT','CREATE','CURRENT','DATE','DECIMAL','DEFAULT','DELETE','DESC','DISTINCT','DROP','ELSE','EXCLUSIVE','EXISTS','FILE','FLOAT','FOR','FROM','GRANT','GROUP','HAVING','IDENTIFIED','IMMEDIATE','IN','INCREMENT','INDEX','INITIAL','INSERT','INTEGER','INTERSECT','INTO','IS','LEVEL','LIKE','LOCK','LONG','MAXEXTENTS','MINUS','MLSLABEL','MODE','MODIFY','NOAUDIT','NOCOMPRESS','NOT','NOWAIT','NULL','NUMBER','OF','OFFLINE','ON','ONLINE','OPTION','OR','ORDER','PCTFREE','PRIOR','PRIVILEGES','PUBLIC','RAW','RENAME','RESOURCE','REVOKE','ROW','ROWID','ROWNUM','ROWS','SELECT','SESSION','SET','SHARE','SIZE','SMALLINT','START','SUCCESSFUL','SYNONYM','SYSDATE','TABLE','THEN','TO','TRIGGER','UID','UNION','UNIQUE','UPDATE','USER','VALIDATE','VALUES','VARCHAR','VARCHAR2','VIEW','WHENEVER','WHERE','WITH'"
#=== SETTINGS ===



IFS="
"
login=$1
shift 1
__UNAME=`uname`


if [[ $_ENC != "" ]]
then
  sql_left_quote="'''${_ENC}''||replace('||"
  sql_right_quote="||',''${_ENC}'',''${_ENC}${_ENC}'')||''${_ENC}'''"
  ldr_quote=" enclosed by ''${_ENC}''"
fi
if [[ $_ROWS != "" ]]
then
  stop_cond=" where rownum<=${_ROWS}"
fi
if [[ "${_SEP#0}" != "${_SEP}" ]]
then
  sql_sep="'chr(to_number(''${_SEP}'',''XX''))'"
  ldr_sep="X'${_SEP}'"
else
  sql_sep="'''${_SEP}'''"
  ldr_sep="'${_SEP}'"
fi
if [[ $_EOL != "" ]]
then
  sql_eol="||'${_EOL}'"
  if [[ ${OSTYPE} == "cygwin" ]]
  then
    ldr_eol=" \"str '${_EOL}\\r\\n'\""
  else
    ldr_eol=" \"str '${_EOL}\\n'\""
  fi
fi

for t
do
  # table definition
  echo "create table $t (" >$t.sql
  sqlplus -s -L $login <<EOF >>$t.sql
set newpage none pagesize 0 linesize 128 underline off feedback off head off timing off tab off
select
  decode(column_id,1,'   ','  ,')||
  case when 
    upper(t.column_name)<>t.column_name or upper(t.column_name) in (${RESERVED})
    then '"'||t.column_name||'"'
    else lower(t.column_name)
  end || ' ' ||
  lower(t.data_type 
    ||decode(decode(t.data_type,'VARCHAR2','C','CHAR','C'),'C','('||t.data_length||')')
    ||decode(decode(t.data_type,'NUMBER','N','FLOAT','N'),'N',decode(nvl(t.data_precision,t.data_scale),null,null,'('||nvl(to_char(t.data_precision),'*')
    ||decode(t.data_scale,null,null,','||t.data_scale)||')'))) ||
  decode(t.nullable,'Y',null,'N',' not null') as field
from all_tab_columns t
where t.data_type in ('CHAR','VARCHAR2','DATE','NUMBER','FLOAT') 
  and (t.owner,t.table_name) in (
    select 
      min(owner) keep (dense_rank first order by priority),
      min(table_name) keep (dense_rank first order by priority)
    from
      (  
        select 
          1 as priority, owner, table_name
        from all_tables
        where
          owner=nvl(substr(upper('$t'),1,instr(upper('$t'),'.',1)-1),user)
          and table_name=substr(upper('$t'),instr(upper('$t'),'.',1)+1)
        union all
        select 
          2 as priority, owner, view_name
        from all_views
        where
          owner=nvl(substr(upper('$t'),1,instr(upper('$t'),'.',1)-1),user)
          and view_name=substr(upper('$t'),instr(upper('$t'),'.',1)+1)
        union all
        select case owner when user then 3 else 4 end as priority, table_owner, table_name 
        from all_synonyms 
        where synonym_name=upper('$t') and owner in (user,'PUBLIC')
      )
    )
order by column_id;
EOF
  echo ");" >>$t.sql

  #SQL*Loader control file
  cat <<EOF >$t.ctl
options (DIRECT=TRUE, STREAMSIZE=8388608, COLUMNARRAYROWS=16384)
LOAD DATA
CHARACTERSET ${NLS_LANG##*.} 
INFILE '$t.txt'${ldr_eol} BADFILE '$t.bad'
TRUNCATE INTO TABLE $t fields terminated by ${ldr_sep} trailing nullcols (
EOF
  sqlplus -s -L $login <<EOF >>$t.ctl
set newpage none pagesize 0 linesize 128 underline off feedback off head off timing off tab off
select
  decode(column_id,1,'   ','  ,')||
  decode(upper(t.column_name),t.column_name,lower(t.column_name),'"'||t.column_name||'"') || ' ' ||
  case 
    when data_type in ('CHAR','VARCHAR2') then 
      case when data_length>255 then 'char('||data_length||')' else 'char' end ||'${ldr_quote}'
    when data_type='NUMBER' then 
      case 
        when data_scale>=0 then 'integer external'
        else 'float external'
      end
    when data_type='FLOAT' then 'float external'
    when data_type='DATE' then 'date ''dd.mm.yyyy hh24:mi:ss'''
  end
from all_tab_columns t
where t.data_type in ('CHAR','VARCHAR2','DATE','NUMBER','FLOAT') 
  and (t.owner,t.table_name) in (
    select 
      min(owner) keep (dense_rank first order by priority),
      min(table_name) keep (dense_rank first order by priority)
    from
      (  
        select 
          1 as priority, owner, table_name
        from all_tables
        where
          owner=nvl(substr(upper('$t'),1,instr(upper('$t'),'.',1)-1),user)
          and table_name=substr(upper('$t'),instr(upper('$t'),'.',1)+1)
        union all
        select 
          2 as priority, owner, view_name
        from all_views
        where
          owner=nvl(substr(upper('$t'),1,instr(upper('$t'),'.',1)-1),user)
          and view_name=substr(upper('$t'),instr(upper('$t'),'.',1)+1)
        union all
        select case owner when user then 3 else 4 end as priority, table_owner, table_name 
        from all_synonyms 
        where synonym_name=upper('$t') and owner in (user,'PUBLIC')
      )
    )
order by column_id;
EOF
  echo ")" >>$t.ctl

  #data
  unset sel
  for c in `sqlplus -s -L $login <<EOF
set newpage none pagesize 0 linesize 128 underline off feedback off head off timing off tab off
select
  decode(column_id,1,null,'||'||${sql_sep}||'||')||
  case 
    when data_type='CHAR' or data_type='VARCHAR2' then ${sql_left_quote}case when upper(t.column_name)<>t.column_name or upper(t.column_name) in (${RESERVED}) then '"'||t.column_name||'"' else lower(t.column_name) end${sql_right_quote}
    when data_type='NUMBER' or data_type='FLOAT' then 'to_char('||case when upper(t.column_name)<>t.column_name or upper(t.column_name) in (${RESERVED}) then '"'||t.column_name||'"' else lower(t.column_name) end||',''TM'',''NLS_NUMERIC_CHARACTERS = ''''. '''''')'
    when data_type='DATE' then 'to_char('||case when upper(t.column_name)<>t.column_name or upper(t.column_name) in (${RESERVED}) then '"'||t.column_name||'"' else lower(t.column_name) end||',''dd.mm.yyyy hh24:mi:ss'')'
  end
from all_tab_columns t
where t.data_type in ('CHAR','VARCHAR2','DATE','NUMBER','FLOAT') 
  and (t.owner,t.table_name) in (
    select 
      min(owner) keep (dense_rank first order by priority),
      min(table_name) keep (dense_rank first order by priority)
    from
      (  
        select 
          1 as priority, owner, table_name
        from all_tables
        where
          owner=nvl(substr(upper('$t'),1,instr(upper('$t'),'.',1)-1),user)
          and table_name=substr(upper('$t'),instr(upper('$t'),'.',1)+1)
        union all
        select 
          2 as priority, owner, view_name
        from all_views
        where
          owner=nvl(substr(upper('$t'),1,instr(upper('$t'),'.',1)-1),user)
          and view_name=substr(upper('$t'),instr(upper('$t'),'.',1)+1)
        union all
        select case owner when user then 3 else 4 end as priority, table_owner, table_name 
        from all_synonyms 
        where synonym_name=upper('$t') and owner in (user,'PUBLIC')
      )
    )
order by column_id;
EOF
`
  do
    sel=$sel$c"\n"
  done

#  sqlplus -s -L $login <<EOF >$t.txt
#  sqlplus -s -L $login <<EOF | gzip >$t.txt.gz
#  cat <<EOF >$t.txt
  sqlplus -s -L $login <<EOF | gzip >$t.txt.gz
set newpage none pagesize 0 linesize 16384 underline off feedback off head off timing off tab off
set recsep off
set arraysize 4096
select
`if [[ ${__UNAME} != AIX ]]; then echo -e ${sel}; else echo ${sel}; fi`${sql_eol}
from
${t}${stop_cond};
EOF

done

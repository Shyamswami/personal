--
-- getvers18.sql
-- SQL script to retrieve installed Banner Products version numbers.
--
-- -------------------------------------------------------------------------------------------------
-- Release 18.1   JAR  2020-APR-21
-- -------------------------------------------------------------------------------------------------
-- 1. The previous version was using UTL_INADDR liberary to get the server's HOST and IP, but if no
--    ACL has been detected then only will use the HOST_NAME from v$instance.
-- -------------------------------------------------------------------------------------------------
-- Release 18.0   JAR  2020-APR-16
-- -------------------------------------------------------------------------------------------------
-- 1. This script is no longer asking for the title for the output report.
-- 2. Localizations/Features may be registered in GVRLDIL, type = 'ACC' (Accelerator), and not only
--    in GVRLOCV.
-- 3. MODs may be registered in GVRLDIL with another types ([WS] Web Services, [ARG] Argos).
-- 4. Added:
--    a. Institution information section.
--    b. DB Parameters subsection.
--    c. SGA Components subsection.
-- 5. Expanded:
--    a. Database information subsection
-- 6. Changed:
--    a. Some columns widht in order to allow a better search for package names.
-- -------------------------------------------------------------------------------------------------
-- Release 17.0   JA/JAR  2018-NOV-15
-- -------------------------------------------------------------------------------------------------
-- 1. In the pBannerLocVersions procedure, variables were enlarged to support Brazil versions.
--    Variables vPackage and vLocalisation were changed to VARCHAR2(100)
-- 2. The line length has been set to 140 characters.
-- 3. In some environments, the white spaces were being discarded. Now the SERVEROUTPUT command has
--    been modified to use the FORMAT WRAPPED parameter.
-- -------------------------------------------------------------------------------------------------
-- Release 16.1   JAR 2018-JUL-13
-- -------------------------------------------------------------------------------------------------
-- In the pBannerSCVersions procedure, there is a vSQL2 variable that stores a SQL command to query
-- the GVRVERS table, but it was making reference to the SURVERS table.  It has been corrected.
-- -------------------------------------------------------------------------------------------------
-- Release 16.0   JAR 2018-JUN-23
-- -------------------------------------------------------------------------------------------------
-- The whole code has been re-written due the following requirements:
--   * Maximum versions for Banner 9 Applications were not correctly reported.
--   * Extra DB parameters were required to be shown.
--   * A new way to sort sections.
--   * Better layout to make easier to read.
-- -------------------------------------------------------------------------------------------------
--
-- Previous versions:
-- Special thanks to ENC, RFM, LLH, EMS, IAC, DTC, RFG
--
--
-- Ellucian - PS ModCenter
-- PUEBLA, Mexico
--
-- Usage:
--  From the command prompt:
--    1. Make sure you are in the folder containing this script.
--    2. From a SQLPLUS session, as Baninst1 type:
--       @getvers18
--    3. Fill-in the appropriate values when prompted to do so.

SET ECHO OFF
SET VERIFY OFF
SET SERVEROUTPUT ON SIZE UNL FORMAT WRAPPED
SET LINES 130
CLEAR SCREEN
SPOOL 'getvers18.log'

DECLARE
  vDummy    VARCHAR2(4000);

  cLineSize NUMBER := 130;

  FUNCTION f_Convert( vVersion VARCHAR2,
                      vDepth   NUMBER
                    ) RETURN VARCHAR2 IS

    iPos NUMBER;
    iCount NUMBER;
    pPrvVersion VARCHAR2(4000);
    pVersion VARCHAR2(4000);
  BEGIN
    pPrvVersion := vVersion;
    pVersion    := '';

    FOR iCount IN 1..vDepth LOOP
      iPos := INSTR( pPrvVersion, '.' );

      IF iPos <> 0 THEN
        IF iCount > 1 THEN
          pVersion := pVersion || '.';
        END IF;
        pVersion := pVersion || LPAD( SUBSTR( pPrvVersion, 1, iPos -1 ), 3, '0' );
        pPrvVersion := SUBSTR( pPrvVersion, iPos + 1 );
      ELSE
        IF pPrvVersion IS NOT NULL THEN
          IF iCount = 1 THEN
            pVersion := pVersion || LPAD( pPrvVersion, 3, '0' );
          ELSE
            pVersion := pVersion || '.' || LPAD( pPrvVersion, 3, '0' );
          END IF;
          pPrvVersion := '';
        ELSE
          pVersion := pVersion || '.000';
        END IF;
      END IF;
    END LOOP;

    RETURN pVersion;
  END f_Convert;

  FUNCTION fGetMaxVersion( pSQL      VARCHAR2,
                           pDate OUT DATE
                         ) RETURN VARCHAR2 IS
    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     SYS_REFCURSOR;
    vCounter    NUMBER;

    vVersion    VARCHAR2(4000);
    vDate       DATE;
    vMaxVersion VARCHAR2(4000);

  BEGIN
    -- Verificamos que exista la tabla GVRVERS
    vSQL := pSQL;

    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);

    vMaxVersion := '1';
    pDate       := NULL;

    LOOP
      FETCH vCursor INTO vVersion, vDate;

      EXIT WHEN vCursor%NOTFOUND;

      IF f_Convert( vVersion, 5 ) > f_Convert( vMaxVersion, 5 ) THEN
        vMaxVersion := vVersion;
        pDate       := vDate;
      END IF;

      vCounter := vCounter + 1;
    END LOOP;
    CLOSE vCursor;

    RETURN vMaxVersion;
  END fGetMaxVersion;

  FUNCTION fOneValueCursor( pCursorName VARCHAR2 ) RETURN VARCHAR2 IS
    TYPE EmpCurTyp IS REF CURSOR;
    vCursor   EmpCurTyp;
    vResult VARCHAR2(4000);
    vSQL    VARCHAR2(4000);

    vErrNum NUMBER;
  BEGIN
    IF pCursorName = 'GET_DATE_C' THEN
      vSQL := 'SELECT TO_CHAR( SYSDATE, ''DD/MM/YYYY HH24:MI:SS'' ) FROM DUAL';
    ELSIF pCursorName = 'GET_DB_NAME_C' THEN
      vSQL := 'SELECT UPPER( DB_UNIQUE_NAME ) FROM v$database';
    ELSIF pCursorName = 'GET_BANNER_INST_TYPE_C' THEN
      vSQL := 'SELECT ''United States Baseline'' FROM DUAL WHERE NOT EXISTS( SELECT ''x'' FROM DBA_OBJECTS WHERE OBJECT_NAME = ''JLOC2ORA'' AND OWNER = ''NLSUSER'' )
               UNION
               SELECT ''Solution Center Baseline'' FROM DUAL WHERE EXISTS( SELECT ''x'' FROM DBA_OBJECTS WHERE OBJECT_NAME = ''JLOC2ORA'' AND OWNER = ''NLSUSER'' )';
    ELSIF pCursorName = 'GET_LANG_C' THEN
      vSQL := 'SELECT ''Database: '' || A.VALUE || '' | Instance: '' || B.VALUE FROM NLS_DATABASE_PARAMETERS A, V$NLS_PARAMETERS B WHERE B.PARAMETER = A.PARAMETER AND A.PARAMETER = ''NLS_LANGUAGE''';
    ELSIF pCursorName = 'GET_CHARSET_C' THEN
      vSQL := 'SELECT ''Database: '' || A.VALUE || '' | Instance: '' || B.VALUE FROM NLS_DATABASE_PARAMETERS A, V$NLS_PARAMETERS B WHERE B.PARAMETER = A.PARAMETER AND A.PARAMETER = ''NLS_CHARACTERSET''';
    ELSIF pCursorName = 'GET_LEN_SEMANTICS_C' THEN
      vSQL := 'SELECT ''Database: '' || A.VALUE || '' | Instance: '' || B.VALUE FROM NLS_DATABASE_PARAMETERS A, V$NLS_PARAMETERS B WHERE B.PARAMETER = A.PARAMETER AND A.PARAMETER = ''NLS_LENGTH_SEMANTICS''';
    ELSIF pCursorName = 'GET_TERRITORY_C' THEN
      vSQL := 'SELECT ''Database: '' || A.VALUE || '' | Instance: '' || B.VALUE FROM NLS_DATABASE_PARAMETERS A, V$NLS_PARAMETERS B WHERE B.PARAMETER = A.PARAMETER AND A.PARAMETER = ''NLS_TERRITORY''';
    ELSIF pCursorName = 'GET_DBEU_STATUS_C' THEN
      vSQL := 'SELECT ''INSTALADO'' FROM ALL_TAB_COLUMNS WHERE TABLE_NAME = ''GUBINST'' AND COLUMN_NAME IN ( ''GUBINST_SURROGATE_ID'', ''GUBINST_VERSION'', ''GUBINST_DATA_ORIGIN'', ''GUBINST_VPDI_CODE'' ) HAVING COUNT(*) = 4
               UNION
               SELECT ''NO INSTALADO'' FROM ALL_TAB_COLUMNS WHERE TABLE_NAME = ''GUBINST'' AND COLUMN_NAME IN ( ''GUBINST_SURROGATE_ID'', ''GUBINST_VERSION'', ''GUBINST_DATA_ORIGIN'', ''GUBINST_VPDI_CODE'' ) HAVING COUNT(*) < 4';
    ELSIF pCursorName = 'GET_MEP_STATUS_C' THEN
      vSQL := 'SELECT DECODE( STATUS, ''DISABLED'', ''NO ACTIVADO'' , ''ACTIVADO'' ) FROM ALL_TRIGGERS WHERE TRIGGER_NAME LIKE ''GT_LOGIN_SET_VPDI_CONTEXT''';
    ELSIF pCursorName = 'GET_WORKING_MEP_C' THEN
      vSQL := 'SELECT DISTINCT ''IMPLEMENTADO'' FROM GTVVPDI WHERE ''ENABLED'' = ( SELECT STATUS FROM ALL_TRIGGERS WHERE TRIGGER_NAME LIKE ''GT_LOGIN_SET_VPDI_CONTEXT'' )';
    ELSIF pCursorName = 'COUNT_INVALID_C' THEN
      vSQL := 'SELECT COUNT(*) FROM ALL_OBJECTS  WHERE STATUS = ''INVALID''';
    ELSIF pCursorName = 'GET_HOST_NAME_C' THEN
      vSQL := 'SELECT UTL_INADDR.get_host_name(UTL_INADDR.get_host_address) || '' ['' || UTL_INADDR.get_host_address || '']'' FROM DUAL';
    ELSIF pCursorName = 'GET_PLATFORM_NAME_C' THEN
      vSQL := 'SELECT PLATFORM_NAME FROM v$database';
    END IF;

    BEGIN
      OPEN vCURSOR FOR vSQL;
      FETCH vCursor INTO vResult;
      CLOSE vCursor;
      EXCEPTION
        WHEN OTHERS THEN
          IF ( pCursorName = 'GET_HOST_NAME_C' ) AND ( SQLCODE = -24247 ) THEN
            vSQL := 'SELECT HOST_NAME FROM v$instance';
            CLOSE vCursor;

            OPEN vCURSOR FOR vSQL;
            FETCH vCursor INTO vResult;
            CLOSE vCursor;
          ELSE
            vResult := '<NO INFO>';
          END IF;
    END;

    RETURN vResult;
  END fOneValueCursor;

  PROCEDURE pPrntDiv( pCharacter VARCHAR2 DEFAULT '=',
                      pLineSize  NUMBER   DEFAULT cLineSize
                    ) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE( LPAD( pCharacter, pLineSize, pCharacter ) );
  END pPrntDiv;

  PROCEDURE pPrntItem( pString  VARCHAR2,
                       pString2 VARCHAR2 DEFAULT NULL,
                       pMaxLen  NUMBER   DEFAULT 0
                     ) IS
    vString VARCHAR2(4000);
    vMaxLen NUMBER;
  BEGIN
    vString := pString;
    vMaxLen := pMaxLen;

    IF vMaxLen <> 0 THEN
      IF vMaxLen < LENGTH( pString ) THEN
        vMaxLen := LENGTH( pString );
      END IF;

      vString := RPAD( vString, vMaxLen, ' ' ) || ':';
    END IF;

    DBMS_OUTPUT.PUT_LINE( vString || ' ' || pString2 );
  END pPrntItem;

  PROCEDURE pPrntLn( pString        VARCHAR2,
                     pJustification VARCHAR2 DEFAULT 'LEFT',
                     pLineSize      NUMBER   DEFAULT cLineSize
                   ) IS

    vSpaces    VARCHAR2(200);
    vNumSpaces NUMBER;
    vString    VARCHAR2(4000);
  BEGIN
    vString := pString;

    IF UPPER( pJustification ) = 'CENTER' THEN
      vNumSpaces := ( ( pLineSize - LENGTH( vString ) ) / 2 ) + LENGTH( vString );
      DBMS_OUTPUT.PUT_LINE( LPAD( vString, vNumSpaces, ' ' ) );
    ELSIF UPPER( pJustification ) = 'RIGHT' THEN
      DBMS_OUTPUT.PUT_LINE( LPAD( vString, pLineSize, ' ' ) );
    ELSE
      DBMS_OUTPUT.PUT_LINE( vString );
    END IF;
  END pPrntLn;

  PROCEDURE pInstitutionInfo IS

    CURSOR GET_20_BIGGEST_TABLESS_C IS
      SELECT OWNER, TABLE_NAME, NUM_ROWS, TRIM( TO_CHAR( NUM_ROWS, '999,999,999,990' ) ) AS vNUM_ROWS
        FROM ALL_TABLES
       WHERE NUM_ROWS IS NOT NULL
         AND OWNER IN ('ALUMNI','BAN_ETHOS_BULK','BAN_SS_USER','BANIMGR','BANINST1','BANSECR',
                       'BANSSO','BSACMGR','CDCADMIN','FAISMGR','FIMSMGR','GENERAL','NLSUSER',
                       'PAYROLL','POSNCTL','SATURN','TAISMGR','WTAILOR')
       ORDER BY 3 DESC
       FETCH FIRST 20 ROWS ONLY;

    CURSOR GET_MAX_CONCURRENCY_C IS
      SELECT COUNT( DISTINCT( SFRSTCA_PIDM ) ),
             TO_CHAR(SFRSTCA_ACTIVITY_DATE,'DD-MON-YYYY HH24:MI')
        FROM SFRSTCA
       WHERE SFRSTCA_ACTIVITY_DATE BETWEEN SYSDATE - 365 AND SYSDATE
         AND SFRSTCA_RMSG_CDE NOT IN ('FING','MIDG')
         AND (    SFRSTCA_USER LIKE ('WWW%')
               OR SFRSTCA_USER LIKE ('BXE%')
               OR SFRSTCA_USER LIKE ('BAN_SS_USER')
               OR SFRSTCA_USER LIKE ('W:%')
               OR SFRSTCA_USER LIKE ('WEB_BAN_%')
               OR SFRSTCA_USER LIKE ('OWS_USER')
             )
       GROUP BY TO_CHAR( SFRSTCA_ACTIVITY_DATE, 'DD-MON-YYYY HH24:MI')
       ORDER BY 1 DESC, 2 DESC;

    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     sys_refcursor;

    vInstName   VARCHAR2(30);
    vNation     VARCHAR2(30);
    vBaseCurr   VARCHAR2(4);

    vMaxConcurrency NUMBER;
    vLastTime       VARCHAR2(100);

  BEGIN
    pPrntDiv( '-' );
    pPrntLn( '* Informacion de la Institucion *', 'center' );
    pPrntDiv( '-' );

    vSQL        := 'SELECT GUBINST_NAME, UPPER( STVNATN_NATION ), GUBINST_BASE_CURR_CODE
                      FROM GUBINST, STVNATN
                     WHERE STVNATN_CODE = GUBINST_NATN_CODE';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore     := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor     := dbms_sql.to_refcursor(vSrceCursor);

    FETCH vCursor
     INTO vInstName,
          vNation,
          vBaseCurr;
    CLOSE vCursor;

    pPrntItem( 'Institucion', vInstName, 30 );
    pPrntItem( 'País', vNation, 30 );
    pPrntItem( 'Moneda Base', vBaseCurr, 30 );

    pPrntLn('');
    OPEN GET_MAX_CONCURRENCY_C;
    FETCH GET_MAX_CONCURRENCY_C
     INTO vMaxConcurrency, vLastTime;
    CLOSE GET_MAX_CONCURRENCY_C;

    pPrntItem( 'Concurrencia máxima en el último año', vMaxConcurrency, 37 );
    pPrntItem( 'Última fecha de concurrencia máxima', vLastTime, 37 );

    pPrntLn('');
    pPrntItem( 'Tablas (20) con más registros', '', 3 );
    FOR iRec IN GET_20_BIGGEST_TABLESS_C LOOP
      pPrntItem( '  ' || RPAD( iRec.OWNER, 15, ' ' ) || RPAD( iRec.TABLE_NAME, 15, ' ' ) || LPAD( iRec.vNUM_ROWS, 16, ' ' ) || ' registros' );
    END LOOP;

    pPrntDiv( '-' );
  END pInstitutionInfo;

  PROCEDURE pPrintOracleVersion IS
    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;

    vCursor sys_refcursor;
    vResult varchar2(4000);
  BEGIN
    pPrntDiv( ' ' );
    pPrntLn( '* Informacion de Oracle *', 'center' );
    pPrntDiv( '-' );

    vSQL        := 'SELECT BANNER FROM V$VERSION';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore     := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor     := dbms_sql.to_refcursor(vSrceCursor);

    LOOP
      FETCH vCursor INTO vResult;
      EXIT WHEN vCursor%NOTFOUND;

      dbms_output.put_line('  ' || REPLACE( vResult, CHR(9), CHR(32) ) );
    END LOOP;
    CLOSE vCursor;
    pPrntDiv( '-' );
  END pPrintOracleVersion;

  PROCEDURE pOracleInfo IS

    CURSOR GET_PARAMETERS_C IS
      SELECT RPAD( NAME, 20, ' ' ) || ' [' || DECODE( TYPE,
                                                      1, 'boolean',
                                                      2, 'string',
                                                      3, 'int',
                                                      4, 'parm file',
                                                      5, 'reserved',
                                                      6, 'bigint',
                                                      'Unknown'
                                                    ) || ']' vName,
            CASE
              WHEN VALUE > 1024 * 1024 THEN TRIM( TO_CHAR( VALUE / 1024 / 1024, '999990' ) ) || ' MB'
              ELSE VALUE
            END  vSize
       FROM V$PARAMETER
      WHERE NAME IN ( 'sga_max_size',
                      'sga_target',
                      'cpu_count',
                      'processes',
                      'sessions'
                    )
         OR NAME LIKE 'pga%'
      ORDER BY CASE
        WHEN NAME = 'sga_max_size'         THEN 1
        WHEN NAME = 'sga_target'           THEN 2
        WHEN NAME = 'pga_aggregate_limit'  THEN 3
        WHEN NAME = 'pga_aggregate_target' THEN 4
        ELSE 5
      END;

    CURSOR GET_SGAINFO_C IS
      SELECT NAME vName,
             TRIM( TO_CHAR( ROUND( BYTES / 1024 / 1024 ), '999990' ) ) || ' MB' vSize
        FROM V$SGAINFO
       ORDER BY NAME ASC;

    CURSOR GET_DB_SIZE_C IS
      SELECT ROUND( ( SELECT SUM( BYTES ) / 1024 / 1024 / 1024 DATA_SIZE
                        FROM DBA_DATA_FILES
                    ) +
                    ( SELECT NVL( SUM( BYTES ), 0 ) / 1024 / 1024 / 1024 TEMP_SIZE
                        FROM DBA_TEMP_FILES
                    ) +
                    ( SELECT SUM( BYTES ) / 1024 / 1024 / 1024 REDO_SIZE
                        FROM SYS.V_$LOG
                    ) +
                    ( SELECT SUM( BLOCK_SIZE * FILE_SIZE_BLKS ) / 1024 / 1024 / 1024 CONTROLFILE_SIZE
                        FROM V$CONTROLFILE
                    ), 2
                  )
             FROM DUAL;

    vDBSize         NUMBER;

  BEGIN
    OPEN GET_DB_SIZE_C;
    FETCH GET_DB_SIZE_C
     INTO vDBSize;
    CLOSE GET_DB_SIZE_C;

    pPrntDiv( ' ' );
    pPrntLn( '* Informacion de la Base de Datos *', 'center' );
    pPrntDiv( '-' );
    pPrntItem( 'Nombre de la Base de Datos', fOneValueCursor('GET_DB_NAME_C' ), 30 );
    pPrntItem( '  Tamaño de la base de datos', vDBSize || ' GB', 30 );
    pPrntItem( '  Host', fOneValueCursor('GET_HOST_NAME_C'), 30 );
    pPrntItem( '  Tipo de Instalacion', fOneValueCursor('GET_BANNER_INST_TYPE_C'), 30 );
    pPrntItem( '  Nombre de la Plataforma', fOneValueCursor('GET_PLATFORM_NAME_C'), 30 );
    pPrntLn('');
    pPrntItem( '  NLS_LANGUAGE', fOneValueCursor('GET_LANG_C'), 30 );
    pPrntItem( '  NLS_CHARACTERSET', fOneValueCursor('GET_CHARSET_C'), 30 );
    pPrntItem( '  NLS_LENGTH_SEMANTICS', fOneValueCursor('GET_LEN_SEMANTICS_C'), 30 );
    pPrntItem( '  NLS_TERRITORY', fOneValueCursor('GET_TERRITORY_C'), 30 );

    pPrntLn('');
    pPrntItem( '  DBEU (Status)', fOneValueCursor('GET_DBEU_STATUS_C'), 30 );
    vDummy := fOneValueCursor('GET_MEP_STATUS_C');
    pPrntItem( '  MEP (Status)', vDummy, 30 );
    IF vDummy <> 'NO ACTIVADO' THEN
      pPrntItem( '    Utilizacion', NVL( fOneValueCursor('GET_WORKING_MEP_C'), 'NO IMPLEMENTADO - Se recomienda desactivar el trigger ''GT_LOGIN_SET_VPDI_CONTEXT''') , 30 );
    END IF;

    pPrntLn('');
    pPrntItem( 'Parametros', '', 3 );
    FOR iRec IN GET_PARAMETERS_C LOOP
      pPrntItem( '  ' || iRec.vName, LPAD( iRec.vSize, 10, ' ' ), 31 );
    END LOOP;

    pPrntLn('');
    pPrntItem( 'Componentes SGA', '', 3 );
    FOR iRec IN GET_SGAINFO_C LOOP
      pPrntItem( '  ' || iRec.vName, LPAD( iRec.vSize, 10, ' ' ), 33 );
    END LOOP;

    pPrntDiv( '-' );
  END pOracleInfo;

  PROCEDURE pBanner8Versions IS
    CURSOR GET_ALL_TABLES_C IS
      SELECT DECODE( INSTR( COMMENTS, 'Version' ),
                     0, COMMENTS,
                     SUBSTR( COMMENTS, 1, INSTR( COMMENTS, 'Version' ) - 2 )
                   ) AS MY_COMMENTS,
             TABLE_NAME,
             DECODE( TABLE_NAME,
                     'GURVERS', 'G',
                     'SURVERS', 'S',
                     'TURVERS', 'T',
                     'FURVERS', 'F',
                     'AURVERS', 'A',
                     'PURVERS', 'P',
                     'NURVERS', 'N',
                     '?'
                   ) AS ENABLED
        FROM ALL_TAB_COMMENTS
       WHERE TABLE_TYPE = 'TABLE'
         AND COMMENTS IS NOT NULL
         AND TABLE_NAME IN ( 'GURVERS', 'SURVERS', 'TURVERS', 'FURVERS', 'AURVERS', 'PURVERS', 'NURVERS',
                             'BWGVERS', 'BWSVERS', 'BWLVERS', 'BWFVERS', 'BWAVERS', 'BWPVERS', 'TWGRVERS',
                             'GKURVERS' )
       ORDER BY CASE
                  WHEN TABLE_NAME = 'GURVERS' THEN 1
                  WHEN TABLE_NAME = 'SURVERS' THEN 2
                  WHEN TABLE_NAME = 'TURVERS' THEN 3
                  WHEN TABLE_NAME = 'FURVERS' THEN 4
                  WHEN TABLE_NAME = 'AURVERS' THEN 5
                  WHEN TABLE_NAME = 'PURVERS' THEN 6
                  WHEN TABLE_NAME = 'NURVERS' THEN 7
                  WHEN TABLE_NAME = 'BWGVERS' THEN 8
                  WHEN TABLE_NAME = 'BWSVERS' THEN 9
                  WHEN TABLE_NAME = 'BWLVERS' THEN 10
                  WHEN TABLE_NAME = 'BWFVERS' THEN 11
                  WHEN TABLE_NAME = 'BWAVERS' THEN 12
                  WHEN TABLE_NAME = 'BWPVERS' THEN 13
                  WHEN TABLE_NAME = 'TWGRVERS' THEN 14
                  WHEN TABLE_NAME = 'GKURVERS' THEN 15
                  ELSE 16
                END;

    vRel       VARCHAR2(4000);
    vDate      DATE;
    vMaxLength NUMBER;
    vCounter   NUMBER;
  BEGIN
    pPrntDiv( ' ' );
    pPrntLn( '* Informacion de Productos de Banner *', 'center' );
    pPrntDiv( '-' );

    vMaxLength := 0;
    FOR iRec IN GET_ALL_TABLES_C LOOP
      IF LENGTH( iRec.MY_COMMENTS ) > vMaxLength THEN
        vMaxLength := LENGTH( iRec.MY_COMMENTS );
      END IF;
    END LOOP;

    vCounter := 1;
    FOR iRec IN GET_ALL_TABLES_C LOOP
      IF vCounter = 1 THEN
        DBMS_OUTPUT.PUT_LINE( RPAD( 'Producto', vMaxLength ) || ' ' || 'GUAINST' || ' ' || RPAD( 'Version', 10 ) || ' ' || 'Fecha' );
        DBMS_OUTPUT.PUT_LINE( RPAD( '-', vMaxLength, '-' ) || ' ' || RPAD( '-', 7, '-' ) || ' ' || RPAD( '-', 10, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
      END IF;

      vCounter := vCounter + 1;

      vRel := fGetMaxVersion( 'SELECT ' || iRec.TABLE_NAME || '_RELEASE, ' || iRec.TABLE_NAME || '_STAGE_DATE FROM ' || iRec.TABLE_NAME, vDate );

      DBMS_OUTPUT.PUT_LINE( RPAD( iRec.MY_COMMENTS, vMaxLength ) || ' ' || LPAD( RPAD( genutil.product_installed(iRec.ENABLED), 4 ), 7 ) || ' ' || RPAD( vRel, 10 ) || ' ' || TO_CHAR( vDate, 'DD-MON-YYYY' ) );
    END LOOP;

    pPrntDiv( '-' );
  END pBanner8Versions;

  PROCEDURE pBanner9Versions IS
    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     SYS_REFCURSOR;
    vCounter    NUMBER;

    vAppName    VARCHAR2(255);
    vProduct    VARCHAR2(255);
    vRelease    VARCHAR2(255);
    vStageDate  DATE;
  BEGIN
    vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GURWADB''';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);
    FETCH vCursor INTO vAppName;
    CLOSE vCursor;

    IF vAppName IS NOT NULL THEN
      vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GURWAPP''';
      vSrceCursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
      vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
      vCursor := dbms_sql.to_refcursor(vSrceCursor);
      FETCH vCursor INTO vAppName;
      CLOSE vCursor;

      IF vAppName IS NOT NULL THEN
        vSQL := 'SELECT GURWADB_PRODUCT AS PRODUCT, GURWADB_APPLICATION_NAME AS APP_NAME FROM GURWADB
                 UNION
                 SELECT GURWAPP_PRODUCT AS PRODUCT, GURWAPP_APPLICATION_NAME AS APP_NAME FROM GURWAPP ORDER BY 1';
        vSrceCursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
        vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
        vCursor := dbms_sql.to_refcursor(vSrceCursor);

        vCounter := 1;

        LOOP
          FETCH vCursor
           INTO vProduct, vAppName;
          EXIT WHEN vCursor%NOTFOUND;

          IF vCounter = 1 THEN
            pPrntDiv( ' ' );
            pPrntLn( '* Informacion de Productos de Banner 9 *', 'center' );
            pPrntDiv( '-' );

            DBMS_OUTPUT.PUT_LINE( RPAD( 'Producto', 15 ) || ' ' || RPAD( 'Aplicacion', 50 ) || ' ' || RPAD( 'Version', 20 ) || ' ' || 'Fecha' );
            DBMS_OUTPUT.PUT_LINE( RPAD( '-', 15, '-' ) || ' ' || RPAD( '-', 50, '-' ) || ' ' || RPAD( '-', 20, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
          END IF;

          vRelease := fGetMaxVersion( 'SELECT GURWADB_RELEASE, GURWADB_STAGE_DATE FROM GURWADB WHERE GURWADB_APPLICATION_NAME = ''' || vAppName || ''' ' ||
                                        'UNION ' ||
                                        'SELECT GURWAPP_RELEASE, GURWAPP_STAGE_DATE FROM GURWAPP WHERE GURWAPP_APPLICATION_NAME = ''' || vAppName || '''',
                                      vStageDate
                                     );

          DBMS_OUTPUT.PUT_LINE( RPAD( vProduct, 15 ) || ' ' || RPAD( vAppName, 50 ) || ' ' || RPAD( vRelease, 20 ) || ' ' || TO_CHAR( vStageDate, 'DD-MON-YYYY' ) );

          vCounter := vCounter + 1;
        END LOOP;
        CLOSE vCursor;

        pPrntDiv( '-' );
      ELSE
        vSQL := 'SELECT GURWADB_PRODUCT AS PRODUCT, GURWADB_APPLICATION_NAME AS APP_NAME FROM GURWADB';
        vSrceCursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
        vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
        vCursor := dbms_sql.to_refcursor(vSrceCursor);

        vCounter := 1;

        LOOP
          FETCH vCursor
           INTO vProduct, vAppName;
          EXIT WHEN vCursor%NOTFOUND;

          IF vCounter = 1 THEN
            pPrntDiv( ' ' );
            pPrntLn( '* Informacion de Productos de Banner del Solution Center [GVRVERS] *', 'center' );
            pPrntDiv( '-' );

            DBMS_OUTPUT.PUT_LINE( RPAD( 'Producto', 15 ) || ' ' || RPAD( 'Aplicacion', 50 ) || ' ' || RPAD( 'Version', 20 ) || ' ' || 'Fecha' );
            DBMS_OUTPUT.PUT_LINE( RPAD( '-', 15, '-' ) || ' ' || RPAD( '-', 50, '-' ) || ' ' || RPAD( '-', 20, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
          END IF;

          vRelease := fGetMaxVersion( 'SELECT GURWADB_RELEASE, GURWADB_STAGE_DATE FROM GURWADB WHERE GURWADB_APPLICATION_NAME = ''' || vAppName || '''', vStageDate );

          DBMS_OUTPUT.PUT_LINE( RPAD( vProduct, 15 ) || ' ' || RPAD( vAppName, 50 ) || ' ' || RPAD( vRelease, 20 ) || ' ' || TO_CHAR( vStageDate, 'DD-MON-YYYY' ) );

          vCounter := vCounter + 1;
        END LOOP;
        CLOSE vCursor;

        pPrntDiv( '-' );
      END IF;
    ELSE
      vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GURWAPP''';
      vSrceCursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
      vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
      vCursor := dbms_sql.to_refcursor(vSrceCursor);
      FETCH vCursor INTO vAppName;
      CLOSE vCursor;

      IF vAppName IS NOT NULL THEN
        vSQL := 'SELECT GURWAPP_PRODUCT AS PRODUCT, GURWAPP_APPLICATION_NAME AS APP_NAME FROM GURWAPP ORDER BY 1';
        vSrceCursor := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
        vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
        vCursor := dbms_sql.to_refcursor(vSrceCursor);

        vCounter := 1;

        LOOP
          FETCH vCursor
           INTO vProduct, vAppName;
          EXIT WHEN vCursor%NOTFOUND;

          IF vCounter = 1 THEN
            pPrntDiv( ' ' );
            pPrntLn( '* Informacion de Productos de Banner del Solution Center [GVRVERS] *', 'center' );
            pPrntDiv( '-' );

            DBMS_OUTPUT.PUT_LINE( RPAD( 'Producto', 15 ) || ' ' || RPAD( 'Aplicacion', 50 ) || ' ' || RPAD( 'Version', 20 ) || ' ' || 'Fecha' );
            DBMS_OUTPUT.PUT_LINE( RPAD( '-', 15, '-' ) || ' ' || RPAD( '-', 50, '-' ) || ' ' || RPAD( '-', 20, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
          END IF;

          vRelease := fGetMaxVersion( 'SELECT GURWAPP_RELEASE, GURWAPP_STAGE_DATE FROM GURWAPP WHERE GURWAPP_APPLICATION_NAME = ''' || vAppName || '''', vStageDate );

          DBMS_OUTPUT.PUT_LINE( RPAD( vProduct, 15 ) || ' ' || RPAD( vAppName, 50 ) || ' ' || RPAD( vRelease, 20 ) || ' ' || TO_CHAR( vStageDate, 'DD-MON-YYYY' ) );

          vCounter := vCounter + 1;
        END LOOP;
        CLOSE vCursor;

        pPrntDiv( '-' );
      END IF;
    END IF;
  END pBanner9Versions;

  PROCEDURE pBannerSCVersions IS
    vSQL        CLOB;
    vSQL2       CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     SYS_REFCURSOR;
    vCounter    NUMBER;

    vProject    VARCHAR2(30);
    vReleaseNum VARCHAR2(30);
    vDate       DATE;
  BEGIN
    -- Verificamos que exista la tabla GVRVERS
    vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GVRVERS''';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);
    FETCH vCursor INTO vProject;
    CLOSE vCursor;

    IF vProject IS NOT NULL THEN
      vSQL := 'SELECT GVRVERS_PROJECT FROM GVRVERS';
      vSrceCursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
      vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
      vCursor := dbms_sql.to_refcursor(vSrceCursor);

      vSQL2 := 'SELECT GVRVERS_RELEASE_NUMBER, GVRVERS_ACTIVITY_DATE
                  FROM GVRVERS
                 WHERE GENUTIL.SRELEASE( GENUTIL.LRELEASE(GVRVERS_RELEASE_NUMBER ) ) =
                       ( SELECT GENUTIL.SRELEASE( MAX( GENUTIL.LRELEASE( GVRVERS_RELEASE_NUMBER ) ) )
                           FROM GVRVERS
                       )
                   AND GVRVERS_PROJECT = :vProject';
      vCounter := 1;

      LOOP
        FETCH vCursor
         INTO vProject;
        EXIT WHEN vCursor%NOTFOUND;

        IF vCounter = 1 THEN
          pPrntDiv( ' ' );
          pPrntLn( '* Informacion de Productos de Banner del Solution Center [GVRVERS] *', 'center' );
          pPrntDiv( '-' );

          DBMS_OUTPUT.PUT_LINE( RPAD( 'Producto', 30 ) || ' ' || RPAD( 'Version', 10 ) || ' ' || 'Fecha' );
          DBMS_OUTPUT.PUT_LINE( RPAD( '-', 30, '-' ) || ' ' || RPAD( '-', 10, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
        END IF;

        EXECUTE IMMEDIATE vSQL2
         INTO vReleaseNum, vDate USING vProject;

        DBMS_OUTPUT.PUT_LINE( RPAD( vProject, 30 ) || ' ' || RPAD( vReleaseNum, 10 ) || ' ' || TO_CHAR( vDate, 'DD-MON-YYYY' ) );

        vCounter := vCounter + 1;
      END LOOP;
      CLOSE vCursor;

      pPrntDiv( '-' );
    END IF;
  END pBannerSCVersions;

  PROCEDURE pBannerLocVersions IS
    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     SYS_REFCURSOR;
    vCounter    NUMBER;

    vPackage      VARCHAR2(100);
    vFound1       VARCHAR2(100);
    vFound2       VARCHAR2(100);
    vLocalisation VARCHAR2(100);
    vStatus       VARCHAR2(2);
    vVersion      VARCHAR2(21);
    vInitDate     DATE;
    vComments     VARCHAR2(1001);
  BEGIN
    -- Verificamos que exista la tabla GVRLOCV
    vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GVRLOCV''';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);
    FETCH vCursor INTO vFound1;
    CLOSE vCursor;

    -- Verificamos que exista la tabla GVRLDIL
    vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GVRLDIL''';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);
    FETCH vCursor INTO vFound2;
    CLOSE vCursor;

    IF ( vFound1 IS NOT NULL ) AND ( vFound2 IS NULL ) THEN
      vSQL := 'SELECT SUBSTR( GVRLOCV_PACKAGE, 1, 40 ), SUBSTR( GVRLOCV_LOCALISATION, 1, 45 ), GVRLOCV_STATUS, GVRLOCV_VERSION, TO_CHAR( GVRLOCV_INIT_DATE, ''DD-MON-YYYY'' ), GVRLOCV_COMMENTS FROM GVRLOCV ORDER BY GVRLOCV_REF_NUMBER';
    ELSIF ( vFound1 IS NULL ) AND ( vFound2 IS NOT NULL ) THEN
      vSQL := 'SELECT SUBSTR( GVRLDIL_PACKAGE_NAME, 1, 40 ), SUBSTR( GVRLDIL_PACKAGE_DESC, 1, 45 ), GVRLDIL_STATUS, GVRLDIL_PACKAGE_VERSION, TO_CHAR( GVRLDIL_INIT_DATE, ''DD-MON-YYYY'' ), SUBSTR( GVRLDIL_COMMENTS, 1, 36 )
                 FROM GVRLDIL
                WHERE GVRLDIL_DEVL_TYPE = ''ACC''
                ORDER BY GVRLDIL_INIT_DATE';
    ELSIF vFound1 IS NOT NULL AND vFound2 IS NOT NULL THEN
      vSQL := 'SELECT SUBSTR( GVRLOCV_PACKAGE, 1, 40 ), SUBSTR( GVRLOCV_LOCALISATION, 1, 45 ), GVRLOCV_STATUS, GVRLOCV_VERSION, TO_CHAR( GVRLOCV_INIT_DATE, ''DD-MON-YYYY'' ), GVRLOCV_COMMENTS FROM GVRLOCV' || ' UNION ' ||
              'SELECT SUBSTR( GVRLDIL_PACKAGE_NAME, 1, 40 ), SUBSTR( GVRLDIL_PACKAGE_DESC, 1, 45 ), GVRLDIL_STATUS, GVRLDIL_PACKAGE_VERSION, TO_CHAR( GVRLDIL_INIT_DATE, ''DD-MON-YYYY'' ), SUBSTR( GVRLDIL_COMMENTS, 1, 36 )
                 FROM GVRLDIL
                WHERE GVRLDIL_DEVL_TYPE = ''ACC''
                ORDER BY 1';
    ELSE
      vSQL := 'X';
    END IF;

    IF vSQL <> 'X' THEN
      vSrceCursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
      vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
      vCursor := dbms_sql.to_refcursor(vSrceCursor);

      vCounter := 1;

      LOOP
        FETCH vCursor
         INTO vPackage,
              vLocalisation,
              vStatus,
              vVersion,
              vInitDate,
              vComments;
        EXIT WHEN vCursor%NOTFOUND;

        IF vCounter = 1 THEN
          pPrntDiv( ' ' );
          IF ( vFound1 IS NOT NULL ) AND ( vFound2 IS NULL ) THEN
            pPrntLn( '* Informacion de Localizaciones de Banner [GVRLOCV] *', 'center' );
          ELSIF ( vFound1 IS NULL ) AND ( vFound2 IS NOT NULL ) THEN
            pPrntLn( '* Informacion de Localizaciones de Banner [GVRLDIL] *', 'center' );
          ELSIF vFound1 IS NOT NULL AND vFound2 IS NOT NULL THEN
            pPrntLn( '* Informacion de Localizaciones de Banner [GVRLOCV + GVRLDIL] *', 'center' );
          ELSE
            pPrntLn( '* Informacion de Localizaciones no encontrada *', 'center' );
          END IF;
          pPrntDiv( '-' );

          DBMS_OUTPUT.PUT_LINE( RPAD( 'Paquete', 40 ) || ' ' || RPAD( 'Localizacion', 45 ) || ' ' || RPAD( 'Status', 6 ) || ' ' || RPAD( 'Version', 20 ) || ' ' || RPAD( 'Fecha', 11 ) );
          DBMS_OUTPUT.PUT_LINE( RPAD( '-', 40, '-' ) || ' ' || RPAD( '-', 45, '-' ) || ' ' || RPAD( '-', 6, '-' ) || ' ' || RPAD( '-', 20, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
        END IF;

        DBMS_OUTPUT.PUT_LINE( RPAD( vPackage, 40 ) || ' ' || RPAD( vLocalisation, 45 ) || ' ' || RPAD( vStatus, 6 ) || ' ' || RPAD( vVersion, 20 ) || ' ' || RPAD( TO_CHAR( vInitDate, 'DD-MON-YYYY' ), 11 ) );

        vCounter := vCounter + 1;
      END LOOP;
      CLOSE vCursor;

      pPrntDiv( '-' );
    END IF;
  END pBannerLocVersions;

  PROCEDURE pBannerPatchesVersions IS
    CURSOR GET_ALL_PATCHES_C IS
      SELECT GURPOST_PATCH,
             GURPOST_COMMENT,
             GURPOST_APPLIED_DATE
        FROM GURPOST
       ORDER BY GURPOST_APPLIED_DATE;

    vCounter   NUMBER;
  BEGIN
    vCounter := 1;
    FOR iRec IN GET_ALL_PATCHES_C LOOP
      IF vCounter = 1 THEN
        pPrntDiv( ' ' );
        pPrntLn( '* Informacion de Parches de Banner [GURPOST] *', 'center' );
        pPrntDiv( '-' );

        DBMS_OUTPUT.PUT_LINE( RPAD( 'Parche', 30 ) || ' ' || RPAD( 'Comentario', 85 ) || ' ' || 'Fecha' );
        DBMS_OUTPUT.PUT_LINE( RPAD( '-', 30, '-' ) || ' ' || RPAD( '-', 85, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
      END IF;

      vCounter := vCounter + 1;

      DBMS_OUTPUT.PUT_LINE( RPAD( iRec.GURPOST_PATCH, 30 ) || ' ' || RPAD( iRec.GURPOST_COMMENT, 85 ) || ' ' || TO_CHAR( iRec.GURPOST_APPLIED_DATE, 'DD-MON-YYYY' ));
    END LOOP;

    IF vCounter > 1 THEN
      pPrntDiv( '-' );
    END IF;
  END pBannerPatchesVersions;

  PROCEDURE pBannerTransVersions IS
    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     SYS_REFCURSOR;
    vCounter    NUMBER;

    vProject    VARCHAR2(20);
    vReleaseNum VARCHAR2(20);
    vDate       DATE;
  BEGIN
    -- Verificamos que exista la tabla GVRVERS
    vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GKRVERS''';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);
    FETCH vCursor INTO vProject;
    CLOSE vCursor;

    IF vProject IS NOT NULL THEN
      vSQL := 'SELECT A.GKRVERS_PROD_CODE, A.GKRVERS_RELEASE, A.GKRVERS_STAGE_DATE
                 FROM GKRVERS A
                WHERE A.GKRVERS_RELEASE =
                      ( SELECT MAX( B.GKRVERS_RELEASE )
                          FROM GKRVERS B
                         WHERE B.GKRVERS_PROD_CODE = A.GKRVERS_PROD_CODE
                           AND B.GKRVERS_STAGE_DATE =
                               ( SELECT MAX( C.GKRVERS_STAGE_DATE )
                                   FROM GKRVERS C WHERE C.GKRVERS_PROD_CODE = B.GKRVERS_PROD_CODE
                               )
                      )';
      vSrceCursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
      vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
      vCursor := dbms_sql.to_refcursor(vSrceCursor);

      vCounter := 1;

      LOOP
        FETCH vCursor
         INTO vProject,
              vReleaseNum,
              vDate;

        EXIT WHEN vCursor%NOTFOUND;

        IF vCounter = 1 THEN
          pPrntDiv( ' ' );
          pPrntLn( '* Informacion de Productos Traducidos de Banner del Solution Center [GKRVERS] *', 'center' );
          pPrntDiv( '-' );

          DBMS_OUTPUT.PUT_LINE( RPAD( 'Producto', 20 ) || ' ' || RPAD( 'Version', 20 ) || ' ' || 'Fecha' );
          DBMS_OUTPUT.PUT_LINE( RPAD( '-', 20, '-' ) || ' ' || RPAD( '-', 20, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
        END IF;

        DBMS_OUTPUT.PUT_LINE( RPAD( vProject, 20 ) || ' ' || RPAD( vReleaseNum, 20 ) || ' ' || TO_CHAR( vDate, 'DD-MON-YYYY' ) );

        vCounter := vCounter + 1;
      END LOOP;
      CLOSE vCursor;

      pPrntDiv( '-' );
    END IF;
  END pBannerTransVersions;

  PROCEDURE pBannerMODsVersions IS
    vSQL        CLOB;
    vIgnore     NUMBER;
    vSrceCursor NUMBER;
    vCursor     SYS_REFCURSOR;
    vCounter    NUMBER;

    vPackageName    VARCHAR2(100);
    vPackageDesc    VARCHAR2(100);
    vStatus         VARCHAR2(1);
    vPackageVersion VARCHAR2(100);
    vInitDate       VARCHAR2(100);

  BEGIN
    -- Verificamos que exista la tabla GVRVERS
    vSQL := 'SELECT 1 FROM ALL_TABLES WHERE TABLE_NAME = ''GVRLDIL''';
    vSrceCursor := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
    vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
    vCursor := dbms_sql.to_refcursor(vSrceCursor);
    FETCH vCursor INTO vPackageName;
    CLOSE vCursor;

    IF vPackageName IS NOT NULL THEN
      vSQL := 'SELECT SUBSTR( GVRLDIL_PACKAGE_NAME, 1, 40 ), SUBSTR( GVRLDIL_PACKAGE_DESC, 1, 38 ), GVRLDIL_STATUS, SUBSTR( GVRLDIL_PACKAGE_VERSION, 1, 30 ), TO_CHAR( GVRLDIL_INIT_DATE, ''DD/MON/YYYY'' )
                 FROM GVRLDIL
                WHERE GVRLDIL_DEVL_TYPE IN ( ''MOD'', ''WS'', ''ARG'' )
                ORDER BY GVRLDIL_INIT_DATE';
      vSrceCursor := DBMS_SQL.OPEN_CURSOR;
      DBMS_SQL.PARSE(vSrceCursor, vSQL, DBMS_SQL.NATIVE);
      vIgnore := DBMS_SQL.EXECUTE(vSrceCursor);
      vCursor := dbms_sql.to_refcursor(vSrceCursor);

      vCounter := 1;

      LOOP
        FETCH vCursor
         INTO vPackageName,
              vPackageDesc,
              vStatus,
              vPackageVersion,
              vInitDate;
        EXIT WHEN vCursor%NOTFOUND;

        IF vCounter = 1 THEN
          pPrntDiv( ' ' );
          pPrntLn( '* Informacion de Modificaciones de Banner del ModCenter [GVRLDIL] *', 'center' );
          pPrntDiv( '-' );

          DBMS_OUTPUT.PUT_LINE( RPAD( 'Paquete', 40 ) || ' ' || RPAD( 'Descripcion', 38 ) || ' ' || RPAD( 'Status', 6 ) || ' ' || RPAD( 'Version', 30 ) || ' ' || RPAD( 'Fecha', 11 ) );
          DBMS_OUTPUT.PUT_LINE( RPAD( '-', 40, '-' ) || ' ' || RPAD( '-', 38, '-' ) || ' ' || RPAD( '-', 6, '-' ) || ' ' || RPAD( '-', 30, '-' ) || ' ' || RPAD( '-', 11, '-' ) );
        END IF;

          DBMS_OUTPUT.PUT_LINE( RPAD( vPackageName, 40 ) || ' ' || RPAD( vPackageDesc, 38 ) || ' ' || RPAD( vStatus, 6 ) || ' ' || RPAD( vPackageVersion, 30 ) || ' ' || RPAD( vInitDate, 11 ) );

        vCounter := vCounter + 1;
      END LOOP;
      CLOSE vCursor;

      pPrntDiv( '-' );
    END IF;
  END pBannerMODsVersions;

  PROCEDURE pBannerInvalidObjects IS
    CURSOR GET_ALL_INVALID_C IS
      SELECT OWNER,
             OBJECT_NAME,
             OBJECT_TYPE,
             STATUS
        FROM ALL_OBJECTS
       WHERE STATUS = 'INVALID'
       ORDER BY OWNER, OBJECT_NAME, OBJECT_TYPE;

    vCounter   NUMBER;
  BEGIN
    vCounter := 1;
    FOR iRec IN GET_ALL_INVALID_C LOOP
      IF vCounter = 1 THEN
        pPrntDiv( ' ' );
        pPrntLn( '* Informacion de Objetos Invalidos [' || TO_NUMBER( fOneValueCursor('COUNT_INVALID_C') ) || '] *', 'center' );
        pPrntDiv( '-' );

        DBMS_OUTPUT.PUT_LINE( RPAD( 'Propietario', 30 ) || ' ' || RPAD( 'Objeto', 30 ) || ' ' || RPAD( 'Tipo', 19 ) || ' ' || RPAD( 'Status', 7 ) );
        DBMS_OUTPUT.PUT_LINE( RPAD( '-', 30, '-' ) || ' ' || RPAD( '-', 30, '-' ) || ' ' || RPAD( '-', 19, '-' ) || ' ' || RPAD( '-', 7, '-' ) );
      END IF;

      vCounter := vCounter + 1;

      DBMS_OUTPUT.PUT_LINE( RPAD( iRec.OWNER, 30 ) || ' ' || RPAD( iRec.OBJECT_NAME, 30 ) || ' ' || RPAD( iRec.OBJECT_TYPE, 19 ) || ' ' || RPAD( iRec.STATUS, 7 ) );
    END LOOP;

    IF vCounter > 1 THEN
      pPrntDiv( '-' );
    END IF;
  END pBannerInvalidObjects;

BEGIN
  pPrntDiv;
  pPrntLn( 'Productos Banner instalados','center');
  pPrntLn( 'al ' || fOneValueCursor( 'GET_DATE_C' ), 'center' );
  pPrntDiv;

  pInstitutionInfo;
  pPrintOracleVersion;
  pOracleInfo;
  pBanner8Versions;
  pBanner9Versions;
  pBannerSCVersions;
  pBannerLocVersions;
  pBannerMODsVersions;
  pBannerInvalidObjects;
  pBannerPatchesVersions;
  pBannerTransVersions;

  pPrntLn( ' GetVers 18.1                                         PS LAC ModCenter ', 'center' );
  pPrntLn( '                                                                       ', 'center' );
  pPrntLn( ' Copyright 2015-2020 Ellucian Company L.P. and its affiliates          ', 'center' );
  pPrntLn( '                                                                       ', 'center' );
  pPrntLn( ' This software contains confidential and proprietary information of    ', 'center' );
  pPrntLn( ' Ellucian or its subsidiaries. Use of this software is limited to      ', 'center' );
  pPrntLn( ' Ellucian licensees, and is subject to the terms and conditions of one ', 'center' );
  pPrntLn( ' or more written license agreements between Ellucian and such          ', 'center' );
  pPrntLn( ' licensees.                                                            ', 'center' );

  pPrntDiv;
END;
/

SPOOL OFF;

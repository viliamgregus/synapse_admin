/****** Object:  StoredProcedure [dbo].[Effective_Rep_Tables]    Script Date: 29-Nov-22 18:21:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[Effective_Rep_Tables] AS
--rebuild all tables in DB that are not in import schema or dont start with "s_" and have less then 60mil rows to be HEAP Replicated tables

SET NOCOUNT ON
--drop #Incorrect_Tables table if exists
IF OBJECT_ID('tempdb..#Incorrect_Tables') IS NOT NULL
DROP TABLE #Incorrect_Tables
 
--identify incorrectly configured tables
SELECT	*
INTO	#Incorrect_Tables
FROM	(
		SELECT s.name+'.'+t.name AS [Schema_Table]
			  ,s.name AS [Schema_Name]
			  ,t.name AS [Table_Name]
			  ,ROW_NUMBER() OVER(ORDER BY s.name+'.'+t.name) [rn]
		FROM sys.tables t
		LEFT JOIN sys.schemas s ON t.schema_id = s.schema_id
		LEFT JOIN sys.pdw_table_distribution_properties d ON s.name+t.name = OBJECT_SCHEMA_NAME( d.object_id )+OBJECT_NAME( d.object_id )
		LEFT JOIN sys.indexes i  ON t.object_id = I.object_id
		WHERE (s.name <> 'Import'
		AND	t.name not like 's_%')
		and (d.distribution_policy_desc NOT IN ('REPLICATE')
		OR	i.type_desc NOT IN ('HEAP','NONCLUSTERED'))
		) h1

DECLARE @RN int = 1
DECLARE @st varchar(4000)
DECLARE @tn varchar(4000)
DECLARE @sn varchar(4000)
DECLARE @tn_backup varchar(4000)
DECLARE @st_backup varchar(4000)
DECLARE @typ varchar(4000)
DECLARE @rowcount bigint
DECLARE @SQL varchar(4000)

WHILE @RN <= (SELECT MAX(RN) 
				FROM #Incorrect_Tables)

BEGIN
	
	SET @st =	(SELECT	[Schema_Table]
				 FROM	#Incorrect_Tables
				 WHERE	rn = @RN)
	--------------
	--Calculate rowcount
	EXEC('
	SELECT	*
	INTO	#temp_rowcount
	FROM	(
			SELECT COUNT(*) as [rc]
			FROM '+@st+'
			)h1
		')

	SET @rowcount = (SELECT rc FROM #temp_rowcount)

	DROP TABLE #temp_rowcount
	---------------

	IF @rowcount > 60000000 
	
	BEGIN 
	
	SET @RN = @RN +1
	
	END
	
	ELSE
	
	BEGIN	
		SET @tn =  (SELECT	[Table_Name]
				FROM	#Incorrect_Tables
				WHERE	rn = @RN)

		SET @sn =  (SELECT	[Schema_Name]
				FROM	#Incorrect_Tables
				WHERE	rn = @RN)

		SET @tn_backup = @tn+'_backup'

		SET @st_backup = @st+'_backup'

		--CTAS, best performance query
		EXEC('
		RENAME OBJECT '+@st+' TO '+@tn_backup+'

		CREATE TABLE '+@st+'
		WITH
		(
			DISTRIBUTION = REPLICATE,
			HEAP
		)
		AS
			SELECT   *
			FROM     '+@st_backup+'

		--drop table if exists
		IF OBJECT_ID('''+@st_backup+''') IS NOT NULL
		AND  OBJECT_ID('''+@st+''') IS NOT NULL
		DROP TABLE '+@st_backup+'
		')

		SET @RN = @RN +1
	END
END

--drop #Incorrect_Tables table if exists
IF OBJECT_ID('tempdb..#Incorrect_Tables') IS NOT NULL
DROP TABLE #Incorrect_Tables

GO



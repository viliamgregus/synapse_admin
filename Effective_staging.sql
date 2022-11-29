/****** Object:  StoredProcedure [dbo].[Effective_Staging]    Script Date: 29-Nov-22 18:22:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[Effective_Staging] AS
--Change all tables in Import schema (used for staging) or tables with names starting with "s_" to HEAPs with ROUND_ROBIN distribution

--drop #Incorrect_Staging_Tables table if exists
IF OBJECT_ID('tempdb..#Incorrect_Staging_Tables') IS NOT NULL
DROP TABLE #Incorrect_Staging_Tables
 
 --identify incorrectly configured staging tables
SELECT	*
INTO	#Incorrect_Staging_Tables
FROM	(
		SELECT s.name+'.'+t.name AS [Schema_Table]
			  ,s.name AS [Schema_Name]
			  ,t.name AS [Table_Name]
			  ,ROW_NUMBER() OVER(ORDER BY s.name+'.'+t.name) [rn]
		FROM sys.tables t
		LEFT JOIN sys.schemas s ON t.schema_id = s.schema_id
		LEFT JOIN sys.pdw_table_distribution_properties d ON s.name+t.name = OBJECT_SCHEMA_NAME( d.object_id )+OBJECT_NAME( d.object_id )
		LEFT JOIN sys.indexes i  ON t.object_id = I.object_id
		WHERE (s.name = 'Import'
		OR	t.name like 's_%')
		and (d.distribution_policy_desc NOT IN ('ROUND_ROBIN')
		OR	i.type_desc NOT IN ('HEAP'))
		) h1

DECLARE @RN int = 1
DECLARE @st varchar(4000)
DECLARE @tn varchar(4000)
DECLARE @sn varchar(4000)
DECLARE @tn_backup varchar(4000)
DECLARE @st_backup varchar(4000)

WHILE @RN <= (SELECT MAX(RN) 
				FROM #Incorrect_Staging_Tables)

BEGIN
	
	SET @st =	(SELECT	[Schema_Table]
			FROM	#Incorrect_Staging_Tables
			WHERE	rn = @RN)
	
	SET @tn =  (SELECT	[Table_Name]
			FROM	#Incorrect_Staging_Tables
			WHERE	rn = @RN)

	SET @sn =  (SELECT	[Schema_Name]
			FROM	#Incorrect_Staging_Tables
			WHERE	rn = @RN)

	SET @tn_backup = @tn+'_backup'

	SET @st_backup = @st+'_backup'

	--CTAS, best performance query
	EXEC('
	RENAME OBJECT '+@st+' TO '+@tn_backup+'

	CREATE TABLE '+@st+'
	WITH
	(
		DISTRIBUTION = ROUND_ROBIN,
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

--drop #Incorrect_Staging_Tables table if exists
IF OBJECT_ID('tempdb..#Incorrect_Staging_Tables') IS NOT NULL
DROP TABLE #Incorrect_Staging_Tables

GO



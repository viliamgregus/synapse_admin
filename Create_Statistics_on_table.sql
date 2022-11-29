/****** Object:  StoredProcedure [dbo].[stat]    Script Date: 29-Nov-22 18:22:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[stat] @tab [varchar](255) AS
--Create statistics on all columns of the input table
SET NOCOUNT ON

DECLARE @tabname varchar(max) = ''+RIGHT(@tab,(LEN(@tab)-CHARINDEX('.',@tab)))+''
DECLARE @schema varchar(max) = ''+LEFT(@tab,CHARINDEX('.',@tab)-1)+''
DECLARE @COLID int = 0
DECLARE @col varchar(max)
DECLARE @stat varchar(max)

WHILE @COLID < (SELECT MAX(RN) FROM (	SELECT	COLUMN_NAME
											   ,[RN]= ROW_NUMBER() OVER(PARTITION BY TABLE_NAME,TABLE_SCHEMA ORDER BY TABLE_NAME,TABLE_SCHEMA)
										FROM	INFORMATION_SCHEMA.COLUMNS
										WHERE	TABLE_NAME = @tabname
										AND		TABLE_SCHEMA = @schema
										)h1)
BEGIN
	BEGIN TRY
	SET @COLID = @COLID + 1

	IF OBJECT_ID('tempdb..#h1') IS NOT NULL
	DROP TABLE #h1

	CREATE TABLE #h1 (cn varchar(4000)
	,rn int)

	INSERT INTO #h1
	(cn,rn)
	SELECT	 COLUMN_NAME as [cn]
			,[RN]= ROW_NUMBER() OVER(PARTITION BY TABLE_NAME,TABLE_SCHEMA ORDER BY TABLE_NAME,TABLE_SCHEMA)
	FROM	 INFORMATION_SCHEMA.COLUMNS
	WHERE	 TABLE_NAME = @tabname
	AND		 TABLE_SCHEMA = @schema
	SET @col =  (
				SELECT	cn
				FROM	#h1
				where	rn=@colid
				)

	IF OBJECT_ID('tempdb..#h1') IS NOT NULL
	DROP TABLE #h1

	SET @stat = 'stat_'+REPLACE(@col,':','')
	EXEC('CREATE STATISTICS '+@stat+' ON '+@tab+'(['+@COL+']) WITH FULLSCAN')
	END TRY
	BEGIN CATCH
	PRINT ERROR_MESSAGE() 
	END CATCH
END

GO



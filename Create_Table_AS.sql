/****** Object:  StoredProcedure [dbo].[CTAS]    Script Date: 29-Nov-22 18:21:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[CTAS] @SQL [varchar](MAX),@tab [varchar](255),@idx [varchar](255),@typ [varchar](4) AS
--Creates table based on SQL statement, replaces the already existing table if such exists.
--works for temp tables as well
--for hash distributed table and replicated tables creates index based on input
--3 options for @typ variable: 
--	'hash' : Creates hash distributed table with ordered clustered columnstore index (CCI) on column from @idx field
--  'rep'  : for heap replicated table
--  'rr'   : for Round-robin heap table
--known limitations: ordered CCI column datatype must be suitable
SET NOCOUNT ON

DECLARE @SQL1 varchar(max)
DECLARE @SQL12 varchar(max)
DECLARE @SQL13 varchar(max)
DECLARE @SQL2 varchar(max)
DECLARE @SQL3 varchar(max)
DECLARE @SQL4 varchar(max)
DECLARE @order_and_option varchar(max) = 'ORDER BY '+@IDX+'
										  OPTION (MAXDOP 1)
										 '
DECLARE @table_property varchar(max)

IF @typ NOT IN ('hash','rep','rr') 
BEGIN
PRINT('Not recognized or missing @typ. Please specify @typ as hash OR rep OR rr')
END

IF @typ = 'hash' AND @IDX IS NOT NULL BEGIN SET @table_property =  '   CLUSTERED COLUMNSTORE INDEX ORDER('+@IDX+'),
													    DISTRIBUTION = HASH('+@IDX+')
													  ' 
										END
IF @typ = 'rep' AND @IDX IS NOT NULL BEGIN SET @table_property =  '   HEAP,
													    DISTRIBUTION = REPLICATE
													  '
										SET @order_and_option = ''
										END
IF @typ = 'rr' AND @IDX IS NOT NULL BEGIN SET @table_property =  '   HEAP,
													    DISTRIBUTION = ROUND_ROBIN
													  '
									     SET @order_and_option = ''
										 END

IF @typ = 'hash'  AND	CHARINDEX ('SELECT TOP',@SQL)=0
BEGIN
SET @SQL = REPLACE (@SQL,'SELECT','SELECT TOP(999999999999999999) ')
END


SET @SQL1 =
'IF OBJECT_ID(N'''+@tab+''', N''U'') IS NOT NULL  
 DROP TABLE '+@tab+''
SET @SQL12 =
'IF OBJECT_ID(N'''+'tempdb..'+@tab+''', N''U'') IS NOT NULL  
 DROP TABLE '+@tab+''
SET @SQL13 =
'if object_id('''+@tab+''',''v'') is not null
drop view '+@tab+''



SET @SQL2 =
'

CREATE TABLE '+@tab+'
WITH('+@table_property+')
AS
    '+@sql+' '+@order_and_option+'

'



SET @SQL3 =
'
CREATE INDEX '+@IDX+' ON '+@tab+'('+@IDX+')
'


EXEC(@SQL1)
EXEC(@SQL12)
EXEC(@SQL13)
EXEC(@SQL2)
IF @typ IN ('hash','rep') 
BEGIN
EXEC(@SQL3)
END

GO



/****** Object:  StoredProcedure [dbo].[AT]    Script Date: 29-Nov-22 18:21:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[AT] @tab [varchar](255),@idx [varchar](255),@typ [varchar](255) AS
--changes properties of already existing table
--3 options for @typ variable: 
--	'hash' : Creates hash distributed table with ordered clustered columnstore index (CCI) on column from @idx field
--  'rep'  : for heap replicated table
--  'rr'   : for Round-robin heap table
--known limitations: ordered CCI column datatype must be suitable
SET NOCOUNT ON

DECLARE @SQL varchar(max)
DECLARE @SQL1 varchar(max)
DECLARE @SQL2 varchar(max)
DECLARE @SQL3 varchar(max)
DECLARE @SQL4 varchar(max)
DECLARE @SQL5 varchar(max)
DECLARE @order_and_option varchar(max) = 'ORDER BY '+@IDX+'
										  OPTION (MAXDOP 1)
										 '
DECLARE @table_property varchar(max)
DECLARE @tn varchar(4000) = RIGHT(@tab,(LEN(@tab) - CHARINDEX('.',@tab)))
DECLARE @tn_backup varchar(4000) = @tn + '_backup'
DECLARE @tab_backup varchar(4000) = @tab + '_backup'


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

SET @SQL = 'SELECT * FROM '+@tab_backup

IF @typ = 'hash' 
BEGIN
SET @SQL = REPLACE (@SQL,'SELECT','SELECT TOP(999999999999999999) ')
END


SET @SQL1 =
'IF OBJECT_ID(N'''+@tab+''', N''U'') IS NOT NULL  
 RENAME OBJECT '+@tab+' TO '+@tn_backup

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

SET @SQL4 =
'
exec stat @tab = '''+@tab+'''
'

SET @SQL5 =
'
--drop table if exists
IF OBJECT_ID('''+@tab_backup+''') IS NOT NULL
AND  OBJECT_ID('''+@tab+''') IS NOT NULL
DROP TABLE '+@tab_backup

EXEC(@SQL1)
EXEC(@SQL2)
IF @typ IN ('hash','rep') 
BEGIN
EXEC(@SQL3)
--EXEC(@SQL4)
EXEC(@SQL5)
END

GO



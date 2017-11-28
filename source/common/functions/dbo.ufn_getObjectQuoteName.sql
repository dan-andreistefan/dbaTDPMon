RAISERROR('Create function: [dbo].[ufn_getObjectQuoteName]', 10, 1) WITH NOWAIT
GO
IF  EXISTS (SELECT * FROM sysobjects WHERE id = OBJECT_ID('[dbo].[ufn_getObjectQuoteName]') AND xtype in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[ufn_getObjectQuoteName]
GO

CREATE FUNCTION [dbo].[ufn_getObjectQuoteName]
(		
	@objectName	[nvarchar](max),
	@quoteFor	[nvarchar](8) = NULL /* possible values: filter, xml, sql, undo-xml, folder */
)
RETURNS [nvarchar](max)
/* WITH ENCRYPTION */
AS

-- ============================================================================
-- Copyright (c) 2004-2017 Dan Andrei STEFAN (danandrei.stefan@gmail.com)
-- ============================================================================
-- Author			 : Dan Andrei STEFAN
-- Create date		 : 2004-2017
-- Module			 : Database Analysis & Performance Monitoring
-- ============================================================================

begin
	DECLARE @quoteName [nvarchar](max)

	IF @quoteFor = 'filter' OR @quoteFor IS NULL
		SET @quoteName = N'[' + REPLACE(@objectName, N']', N']]') + N']'
	IF @quoteFor = 'sql' 
		SET @quoteName = REPLACE(@objectName, N'''', N'''''')
	IF @quoteFor = 'xml' 
		begin
			SET @quoteName = @objectName
			SET @quoteName = REPLACE(@quoteName, N'&', N'&amp;')
			SET @quoteName = REPLACE(@quoteName, N'<', N'&lt;')
			SET @quoteName = REPLACE(@quoteName, N'>', N'&gt;')
			SET @quoteName = REPLACE(@quoteName, N'''', N'&apos;')
			SET @quoteName = REPLACE(@quoteName, N'"', N'&quot;')
		end
	IF @quoteFor = 'undo-xml' 
		begin
			SET @quoteName = @objectName
			SET @quoteName = REPLACE(@quoteName, N'&amp;', N'&')
			SET @quoteName = REPLACE(@quoteName, N'&lt;', N'<')
			SET @quoteName = REPLACE(@quoteName, N'&amp;lt;', N'<')
			
			SET @quoteName = REPLACE(@quoteName, N'&gt;', N'>')
			SET @quoteName = REPLACE(@quoteName, N'&amp;gt;', N'>')

			SET @quoteName = REPLACE(@quoteName, N'&apos;', N'''')
			SET @quoteName = REPLACE(@quoteName, N'&amp;apos;', N'''')

			SET @quoteName = REPLACE(@quoteName, N'&quot;', N'"')
			SET @quoteName = REPLACE(@quoteName, N'&amp;quot;', N'"')
		end
	IF @quoteFor = 'folder'
		begin
			SET @quoteName = @objectName
			SET @quoteName = REPLACE(@quoteName, N'''', N'''''')
			SET @quoteName = SUBSTRING(@quoteName, 1, 2) + REPLACE(REPLACE(REPLACE(REPLACE(SUBSTRING(@quoteName, 3, LEN(@quoteName)), N'<', N'_'), N'>', N'_'), N':', N'_'), N'"', N'_')
		end

	RETURN @quoteName
end
GO




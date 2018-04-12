-- ============================================================================
-- Copyright (c) 2004-2018 Dan Andrei STEFAN (danandrei.stefan@gmail.com)
-- ============================================================================
-- Author			 : Dan Andrei STEFAN
-- Create date		 : 11.04.2018
-- Module			 : Database Analysis & Performance Monitoring
-- ============================================================================

-----------------------------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------------------------
SET NOCOUNT ON
GO
INSERT	INTO [dbo].[appInternalTasks] ([id], [descriptor], [task_name], [flg_actions])
		SELECT S.[id], S.[descriptor], S.[task_name], S.[flg_actions]
		FROM (
				SELECT   16384 AS [id], 'dbo.usp_hcCollectDatabaseDetails' AS [descriptor], 'Collect Database Details' AS [task_name], NULL AS [flg_actions] UNION ALL
				SELECT   32768, 'dbo.usp_hcCollectDiskSpaceUsage', 'Collect Disk Space Usage', NULL UNION ALL
				SELECT   65536, 'dbo.usp_hcCollectErrorlogMessages', 'Collect SQL Server errorlog Messages', NULL UNION ALL
				SELECT  131072, 'dbo.usp_hcCollectOSEventLogs', 'Collect OS Event Logs', NULL UNION ALL
				SELECT  262144, 'dbo.usp_hcCollectSQLServerAgentJobsStatus', 'Collect SQL Server Agent Jobs Status', NULL UNION ALL
				SELECT  524288, 'dbo.usp_hcCollectEventMessages', 'Collect Internal Event Messages', NULL 
			)S
		LEFT JOIN [dbo].[appInternalTasks] ait ON S.[id] = ait.[id]
		WHERE ait.[id] IS NULL
GO

RAISERROR('Create procedure: [dbo].[sp_SQLSMTPMail]', 10, 1) WITH NOWAIT

/*
SP_SQLSMTPMail is an OLE automation implementation of the CDOSYS dll for Windows
2000 which utilizes a network SMTP server rather than an Exchange server/Outlook client.
The stored procedure functions similar to xp_sendmail including the ability to run a query and
attach the results. No MAPI profile is required. It is also a working, detailed example of an OLE
automation implementation. This update corrects a problem when the proc is called twice in
the same batch without an intervening 'Go'. The cause is the sp_OAStop. It needs to be removed
or commented out. The stated method of operation in the BOL is incorrect. 11/5/2002 Some people
have reported errors when running this stored procedure. They have not been failures of the stored
procedure. They are errors related to improper configuration/permissions for the SQL server to use
the local network SMTP relay server for either internal or out going mail. 11/20/2002 Fixes a
problem related to the OSQL call to send an attached query. OSQL was not releasing its lock on
the first output file it created until the session ended, hence, calling the proc in a cursor or loop
prevented subsequent query attachments. 04/09/2003 Comment correction.
*/

if exists (select *
             from sysobjects
            where id = object_id(N'[dbo].[sp_SQLSMTPMail]')
              and OBJECTPROPERTY(id, N'IsProcedure') = 1)
   drop procedure [dbo].[sp_SQLSMTPMail]
GO

SET QUOTED_IDENTIFIER OFF    
GO
SET ANSI_NULLS ON
GO

CREATE PROCEDURE dbo.sp_SQLSMTPMail
       @vcTo           varchar(2048) = null,
       @vcBody         varchar(8000) = '',
       @vcSubject      varchar(255)  = null,
       @vcAttachments  varchar(1024) = null,
       @vcQuery        varchar(8000) = null,
       @vcFrom         varchar(128)  = null,
       @vcCC           varchar(2048) = '',
       @vcBCC          varchar(2048) = '',
	   @vcIsHTMLFormat bit = 0,				-- HTML format or Plain Text Format [ Default is Text ]    
       @vcSMTPServer   varchar(255)  = '',  -- put local network smtp server name here
       @cSendUsing     char(1)       = '2',
       @vcPort         varchar(3)    = '25',
       @cAuthenticate  char(1)       = '0',
       @vcDSNOptions   varchar(2)    = '0',
       @vcTimeout      varchar(2)    = '30',
       @vcSenderName   varchar(128)  = null,
       @vcServerName   sysname       = null

As

/*******************************************************************/
--Name        : sp_SQLSMTPMail
--Server      : Generic
--Description : SQL smtp e-mail using CDOSYS, OLE Automation and a
--              network smtp server; For SQL Servers running on
--              windows 2000.
--
--Note        : Be sure to set the default for @vcSMTPServer above to
--              the company network smtp server or you will have to
--              pass it in each time.
--
--Comments    : Getting the network SMTP configured to work properly
--              may require engaging your company network or
--              server people who deal with the netowrk SMTP server.
--              Some errors that the stored proc returns relate to
--              incorrect permissions for the various SQL Servers to
--              use the SMTP relay server to bouce out going mail.
--              Without proper permissions the SQL server appears as
--              a spammer to the local SMTP network server.
--
--Parameters  : See the 'Syntax' Print statements below or call the
--              sp with '?' as the first input.
--
--Date        : 08/22/2001
--Author      : Clinton Herring
--
--History     :
/*******************************************************************/

Set nocount on

-- Determine if the user requested syntax.
If @vcTo = '?'
   Begin
      Print 'Syntax for sp_SQLSMTPMail (based on CDOSYS):'
      Print 'Exec master.dbo.sp_SQLSMTPMail'
      Print '     @vcTo          (varchar(2048)) - Recipient e-mail address list separating each with a '';'' '
      Print '                                       or a '',''. Use a ''?'' to return the syntax.'
      Print '     @vcBody        (varchar(8000)) - Text body; use embedded char(13) + char(10)'
      Print '                                       for carriage returns. The default is nothing'
      Print '     @vcSubject     (varchar(255))) - E-mail subject. The default is a message from'
      Print '                                       @@servername.'
      Print '     @vcAttachments (varchar(1024)) - Attachment list separating each with a '';''.'
      Print '                                       The default is no attachments.'
      Print '     @vcQuery       (varchar(8000)) - In-line query or a query file path; do not '
      Print '                                       use double quotes within the query.'
      Print '     @vcFrom        (varchar(128))  - Sender list defaulted to @@ServerName.'
      Print '     @vcCC          (varchar(2048)) - CC list separating each with a '';'' or a '','''
      Print '                                       The default is no CC addresses.'
      Print '     @vcBCC         (varchar(2048)) - Blind CC list separating each with a '';'' or a '','''
      Print '                                       The default is no BCC addresses.'
      Print '     @vcIsHTMLFormat (Bit) - If 1 then Format of Mail will be HTML Mail otherwise Plain text'
      Print '     @vcSMTPServer  (varchar(255))  - Network smtp server defaulted to your companies network'
      Print '                                       smtp server. Set this in the stored proc code.'
      Print '     @cSendUsing    (char(1))       - Specifies the smpt server method, local or network. The'
      Print '                                       default is network, a value of ''2''.'
      Print '     @vcPort        (varchar(3))    - The smtp server communication port defaulted to ''25''.'
      Print '     @cAuthenticate (char(1))       - The smtp server authentication method defaulted to '
      Print '                                       anonymous, a value of ''0''.'
      Print '     @vcDSNOptions  (varchar(2))    - The smtp server delivery status defaulted to none,'
      Print '                                       a value of ''0''.'
      Print '     @vcTimeout     (varchar(2))    - The smtp server connection timeout defaulted to 30 seconds.'
      Print '     @vcSenderName  (varchar(128))  - Primary sender name defaulted to @@ServerName.'
      Print '     @vcServerName  (sysname)       - SQL Server to which the query is directed defaulted'
      Print '                                       to @@ServerName.'
      Print ''
      Print ''
      Print 'Example:'
      Print 'sp_SQLSMTPMail ''<user@mycompany.com>'', ''This is a test'', @vcSMTPServer = <network smtp relay server>'
      Print ''
      Print 'The above example will send an smpt e-mail to <user@mycompany.com> from @@ServerName'
      Print 'with a subject of ''Message from SQL Server <@@ServerName>'' and a'
      Print 'text body of ''This is a test'' using the network smtp server specified.'
      Print 'See the MSDN online library, Messaging and Collaboration, at '
      Print 'http://www.msdn.microsoft.com/library/ for details about CDOSYS.'
      Print 'subheadings: Messaging and Collaboration>Collaboration Data Objects>CDO for Windows 2000>'
      Print 'Reference>Fields>http://schemas.microsoft.com/cdo/configuration/>smtpserver field'
      Print ''
      Print 'Be sure to set the default for @vcSMTPServer before compiling this stored procedure.'
      Print ''
      Return
   End


-- Declare variables
Declare @iMessageObjId    int
Declare @iHr              int
Declare @iRtn             int
Declare @iFileExists      tinyint
Declare @vcCmd            varchar(255)
Declare @vcQueryOutPath   varchar(50)
Declare @dtDatetime       datetime
Declare @vcErrMssg        varchar(255)
Declare @vcAttachment     varchar(1024)
Declare @iPos             int
Declare @vcErrSource      varchar(255)
Declare @vcErrDescription varchar(255)

-- Set local variables.
Set @dtDatetime = getdate()
Set @iHr = 0

-- Check for minimum parameters.
If @vcTo is null
   Begin
      Set @vcErrMssg = 'You must supply at least 1 recipient.'
      Goto ErrMssg
   End

-- CDOSYS uses commas to separate recipients. Allow users to use
-- either a comma or a semi-colon by replacing semi-colons in the
-- To, CCs and BCCs.
Select @vcTo = Replace(@vcTo, ';', ',')
Select @vcCC = Replace(@vcCC, ';', ',')
Select @vcBCC = Replace(@vcBCC, ';', ',')

-- Set the default SQL Server to the local SQL Server if one
-- is not provided to accommodate instances in SQL 2000.
If @vcServerName is null
   Set @vcServerName = @@servername

-- Set a default "subject" if one is not provided.
If @vcSubject is null
   Set @vcSubject = 'Message from SQL Server ' + @vcServerName

-- Set a default "from" if one is not provided.
If @vcFrom is null
   Set @vcFrom = 'SQL-' + Replace(@vcServerName,'\','$')

-- Set a default "sender name" if one is not provided.
If @vcSenderName is null
   Set @vcSenderName = 'SQL-' + Replace(@vcServerName,'\','$')

-- Create the SMTP message object.
EXEC @iHr = sp_OACreate 'CDO.Message', @iMessageObjId OUT
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error creating object CDO.Message.'
      Goto ErrMssg
   End

-- Set SMTP message object parameters.
-- To
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'To', @vcTo
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "To".'
      Goto ErrMssg
   End

-- Subject
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'Subject', @vcSubject
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "Subject".'
      Goto ErrMssg
   End

-- From
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'From', @vcFrom
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "From".'
      Goto ErrMssg
   End

-- CC
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'CC', @vcCC
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "CC".'
      Goto ErrMssg
   End

-- BCC
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'BCC', @vcBCC
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "BCC".'
      Goto ErrMssg
   End

-- DSNOptions
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'DSNOptions', @vcDSNOptions
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "DSNOptions".'
      Goto ErrMssg
   End

-- Sender
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'Sender', @vcSenderName
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message parameter "Sender".'
      Goto ErrMssg
   End

-- Is there a query to run?
If @vcQuery is not null and @vcQuery <> ''
   Begin
      -- We have a query result to include; temporarily send the output to the
      -- drive with the most free space. Use xp_fixeddrives to determine this.
      -- If a temp table exists with the following name drop it.
      If (Select object_id('tempdb.dbo.#fixeddrives')) > 0
         Exec ('Drop table #fixeddrives')

      -- Create a temp table to work with xp_fixeddrives.
      Create table #fixeddrives(
             Drive char(1) null,
             FreeSpace  varchar(15) null)

      -- Get the fixeddrive info.
      Insert into #fixeddrives Exec master.dbo.xp_fixeddrives

      -- Get the drive letter of the drive with the most free space
      -- Note: The OSQL output file name must be unique for each call within the same session.
      --       Apparently OSQL does not release its lock on the first file created until the session ends.
      --       Hence this alleviates a problem with queries from multiple calls in a cursor or other loop.
      Select @vcQueryOutPath = Drive + ':\TempQueryOut' +
                               ltrim(str(datepart(hh,getdate()))) +
                               ltrim(str(datepart(mi,getdate()))) +
                               ltrim(str(datepart(ss,getdate()))) +
                               ltrim(str(datepart(ms,getdate()))) + '.txt'
        from #fixeddrives
       where FreeSpace = (select max(FreeSpace) from #fixeddrives )

      -- Check for a pattern of '\\*\' or '?:\'.
      -- If found assume the query is a file path.
      If Left(@vcQuery, 35) like '\\%\%' or Left(@vcQuery, 5) like '_:\%'
         Begin
            Select @vcCmd = 'osql /S' + @vcServerName + ' /E /i' +
                            convert(varchar(1024),@vcQuery) +
                            ' /o' + @vcQueryOutPath + ' -n -w5000 '
         End
      Else
         Begin
            Select @vcCmd = 'osql /S' + @vcServerName + ' /E /Q"' + @vcQuery +
                            '" /o' + @vcQueryOutPath + ' -n -w5000 '
         End

      -- Execute the query
      Exec master.dbo.xp_cmdshell @vcCmd, no_output

      -- Add the query results as an attachment if the file was successfully created.
      -- Check to see if the file exists. Use xp_fileexist to determine this.
      -- If a temp table exists with the following name drop it.
      If (Select object_id('tempdb.dbo.#fileexists')) > 0
         Exec ('Drop table #fileexists')

      -- Create a temp table to work with xp_fileexist.
      Create table #fileexists(
             FileExists tinyint null,
             FileIsDirectory  tinyint null,
             ParentDirectoryExists  tinyint null)

      -- Execute xp_fileexist
      Insert into #fileexists exec master.dbo.xp_fileexist @vcQueryOutPath

      -- Now see if we need to add the file as an attachment
      If (select FileExists from #fileexists) = 1
         Begin
            -- Set a variable for later use to delete the file.
            Select @iFileExists = 1

            -- Add the file path to the attachment variable.
            If @vcAttachments is null
               Select @vcAttachments = @vcQueryOutPath
            Else
               Select @vcAttachments = @vcAttachments + '; ' + @vcQueryOutPath
         End
   End

-- Check for multiple attachments separated by a semi-colon ';'.
If @vcAttachments is not null
   Begin
      If right(@vcAttachments,1) <> ';'
         Select @vcAttachments = @vcAttachments + '; '
      Select @iPos = CharIndex(';', @vcAttachments, 1)
      While @iPos > 0
         Begin
            Select @vcAttachment = ltrim(rtrim(substring(@vcAttachments, 1, @iPos -1)))
            Select @vcAttachments = substring(@vcAttachments, @iPos + 1, Len(@vcAttachments)-@iPos)
            EXEC @iHr = sp_OAMethod @iMessageObjId, 'AddAttachment', @iRtn Out, @vcAttachment
            IF @iHr <> 0
               Begin
                  EXEC sp_OAGetErrorInfo @iMessageObjId, @vcErrSource Out, @vcErrDescription Out
                  Select @vcBody = @vcBody + char(13) + char(10) + char(13) + char(10) +
                                   char(13) + char(10) + 'Error adding attachment: ' +
                                   char(13) + char(10) + @vcErrSource + char(13) + char(10) +
                                   @vcAttachment
               End
            Select @iPos = CharIndex(';', @vcAttachments, 1)
         End
   End

--HTMLBody
if @vcIsHTMLFormat=1
begin
EXEC @iHr = sp_OASetProperty @iMessageObjId, 'HTMLBody', @vcBody
   IF @iHr <> 0 
     Begin 
      Set @vcErrMssg = 'Error setting Message parameter "BodyFormat".'
      Goto ErrMssg 
     End
end
else
begin
   -- TextBody
   EXEC @iHr = sp_OASetProperty @iMessageObjId, 'TextBody', @vcBody 
   IF @iHr <> 0 
     Begin 
      Set @vcErrMssg = 'Error setting Message parameter "TextBody".'
      Goto ErrMssg 
     End
end


-- Other Message parameters for reference
--EXEC @iHr = sp_OASetProperty @iMessageObjId, 'MimeFormatted', False
--EXEC @iHr = sp_OASetProperty @iMessageObjId, 'AutoGenerateTextBody', False
--EXEC @iHr = sp_OASetProperty @iMessageObjId, 'MDNRequested', True

-- Set SMTP Message configuration property values.
-- Network SMTP Server location
EXEC @iHr = sp_OASetProperty @iMessageObjId,
'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/smtpserver").Value',
@vcSMTPServer
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message configuraton field "smtpserver".'
      Goto ErrMssg
   End

-- Sendusing
EXEC @iHr = sp_OASetProperty @iMessageObjId,
'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/sendusing").Value',
@cSendUsing
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message configuraton field "sendusing".'
      Goto ErrMssg
   End

-- SMTPConnectionTimeout
EXEC @iHr = sp_OASetProperty @iMessageObjId,
'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SMTPConnectionTimeout").Value',
@vcTimeout
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message configuraton field "SMTPConnectionTimeout".'
      Goto ErrMssg
   End

-- SMTPServerPort
EXEC @iHr = sp_OASetProperty @iMessageObjId,
'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SMTPServerPort").Value',
@vcPort
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message configuraton field "SMTPServerPort".'
      Goto ErrMssg
   End

-- SMTPAuthenticate
EXEC @iHr = sp_OASetProperty @iMessageObjId,
'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SMTPAuthenticate").Value',
@cAuthenticate
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error setting Message configuraton field "SMTPAuthenticate".'
      Goto ErrMssg
   End

-- Other Message Configuration fields for reference
--EXEC @iHr = sp_OASetProperty @iMessageObjId,
--'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SMTPUseSSL").Value',True

--EXEC @iHr = sp_OASetProperty @iMessageObjId,
--'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/LanguageCode").Value','en'

--EXEC @iHr = sp_OASetProperty @iMessageObjId,
--'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SendEmailAddress").Value', 'Test User'

--EXEC @iHr = sp_OASetProperty @iMessageObjId,
--'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SendUserName").Value',null

--EXEC @iHr = sp_OASetProperty @iMessageObjId,
--'Configuration.Fields("http://schemas.microsoft.com/cdo/configuration/SendPassword").Value',null

-- Update the Message object fields and configuration fields.
EXEC @iHr = sp_OAMethod @iMessageObjId, 'Configuration.Fields.Update'
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error updating Message configuration fields.'
      Goto ErrMssg
   End

EXEC @iHr = sp_OAMethod @iMessageObjId, 'Fields.Update'
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error updating Message parameters.'
      Goto ErrMssg
   End

-- Send the message.
EXEC @iHr = sp_OAMethod @iMessageObjId, 'Send'
IF @iHr <> 0
   Begin
      Set @vcErrMssg = 'Error Sending e-mail.'
      Goto ErrMssg
   End
Else
   Print 'Mail sent.'

Cleanup:
   -- Destroy the object and return.
   EXEC @iHr = sp_OADestroy @iMessageObjId
   --EXEC @iHr = sp_OAStop

   -- Delete the query output file if one exists.
   If @iFileExists = 1
      Begin
         Select @vcCmd = 'del ' + @vcQueryOutPath
         Exec master.dbo.xp_cmdshell @vcCmd, no_output
      End
   Return

ErrMssg:
   Begin
      Print @vcErrMssg
      If @iHr <> 0
         Begin
            EXEC sp_OAGetErrorInfo @iMessageObjId, @vcErrSource Out, @vcErrDescription Out
            Print @vcErrSource
            Print @vcErrDescription
         End

      -- Determine whether to exist or go to Cleanup.
      If @vcErrMssg = 'Error creating object CDO.Message.'
         Return
      Else
         Goto Cleanup
   End


Go

Grant Execute on dbo.sp_SQLSMTPMail  to Public
Go

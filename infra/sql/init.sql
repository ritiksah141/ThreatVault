-- ThreatVault SQL schema — Threat Intelligence IOC table.
-- Run once in Azure Portal → SQL Database → Query Editor
-- or via: sqlcmd -S <host> -d threatvault -U tvadmin -P <pass> -i infra/sql/init.sql

IF NOT EXISTS (
  SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[threat_intel]') AND type = 'U'
)
BEGIN
  CREATE TABLE [dbo].[threat_intel] (
    [id]          INT            IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [ioc_type]    NVARCHAR(50)   NOT NULL,        -- IP | Domain | Hash | CVE | URL
    [ioc_value]   NVARCHAR(500)  NOT NULL,
    [severity]    NVARCHAR(20)   NOT NULL DEFAULT 'Medium',  -- Critical | High | Medium | Low
    [source]      NVARCHAR(255)  NULL,
    [description] NVARCHAR(1000) NULL,
    [created_at]  DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
  );
  PRINT 'threat_intel table created.';
END
ELSE
BEGIN
  PRINT 'threat_intel table already exists — skipped.';
END

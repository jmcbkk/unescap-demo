
USE DEV
GO

IF OBJECT_ID('un.v_Time', 'v') IS NOT NULL
  DROP VIEW un.v_Time
GO

CREATE VIEW un.V_Time

AS

select DISTINCT TimeID, Label
from un.[Time]
GO

-- peek
/*
select * from un.v_Time order by TimeID
*/

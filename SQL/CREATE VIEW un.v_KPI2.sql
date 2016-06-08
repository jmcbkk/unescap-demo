
USE DEV
GO

IF OBJECT_ID('un.v_KPI2') IS NOT NULL
  DROP VIEW un.v_KPI2
GO

CREATE VIEW un.v_KPI2
AS

-- this breaks for KPI's that belong to a folder that also has subfolders (e.g.KpiID = 4176)
WITH RecurKPI AS
(
	select OID, ParentID, KpiID, MeasureID, LongName, ShortName, MeasureName, CAST('/' + LongName AS NVARCHAR(1000)) AS [Path]
	from un.KPI 
	where ParentID IS NULL

	UNION ALL

	select k.OID, k.ParentID, k.KpiID, k.MeasureID, k.LongName, k.ShortName, k.MeasureName, CAST(r.[Path] + '/' + k.LongName AS NVARCHAR(1000)) AS [Path]
	from un.KPI k
	join RecurKPI r ON (r.KpiID = k.ParentID)
)
select 
  OID
  --, ParentID
  , KpiID
  , MeasureID
  , LongName
  , ShortName
  , MeasureName
  , LEFT([Path], LEN([Path]) - LEN(LongName) - 1) AS [Path] -- chop off last dir
  , dbo.ufn_RegExMatchSingle('^/(.+?)/', [Path]) AS ParentFolder
from RecurKPI k
/*
where 
  ParentID IS NOT NULL
  AND NOT EXISTS(select * from un.KPI where k.KpiID = ParentID)
  AND MeasureID IS NOT NULL
*/
GO

-- peek
/*

select * from un.KPI order by 1
select * from un.v_KPI2 order by 1
select * from un.v_KPI2 where KpiID = 1512 and MeasureID = 3928
select DISTINCT ParentFolder from un.v_KPI2 order by 1

*/


USE DEV
GO

IF OBJECT_ID('un.v_KPI') IS NOT NULL
  DROP VIEW un.v_KPI
GO

CREATE VIEW un.V_KPI

AS

select 
  --ROW_NUMBER() OVER(ORDER BY OID) AS KMID
  --, ParentID
  OID AS KMID
  , KpiID
  , MeasureID
  , LongName
  , ShortName
  , MeasureName
  , PathID
  , [Path]
  , ParentFolderID
  , ParentFolder
  , IsSubsetKPI
  , CASE WHEN MeasureName LIKE '\%%' ESCAPE '\' THEN 1 ELSE 0 END AS IsPercent
  , CASE 
      WHEN [Path] IN (
       '/Demographic trends/Population/Age structure (5 years range)',
       '/Demographic trends/Population/CRVS',
       '/Demographic trends/Urbanization') OR   
	   ([Path] = '/Demographic trends/Population/Composition' and LongName LIKE 'Population%\[Thousands\]' ESCAPE '\')  THEN 1
	   ELSE 0
	END AS IsPopKpi
from un.KPI k
where 
  ParentID IS NOT NULL
  AND NOT EXISTS(select * from un.KPI where k.KpiID = ParentID)
  AND MeasureID IS NOT NULL
GO

-- peek
/*

select * from un.V_KPI order by PathID, KMID
select * from un.V_KPI where ParentFolderID = 3 order by 1--PathID, KMID 
select count(*), count(DISTINCT KMID) from un.V_KPI 
select * from un.V_KPI where IsPercent = 1 order by PathID, KMID

select * from un.v_KPI where IsPopKpi = 1

*/

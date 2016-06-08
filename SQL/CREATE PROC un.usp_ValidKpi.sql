
USE DEV
GO

IF OBJECT_ID('un.usp_ValidKpi', 'p') IS NOT NULL
  DROP PROC un.usp_ValidKpi
GO

CREATE PROC un.usp_ValidKpi
(
  @TimeID INT
)

AS

select
	k.KMID
	, k.PathID
	, k.LongName
	, k.ParentFolderID 
	, k.IsPercent
	--, s.KpiID
	--, s.MeasureID
from un.[Stats] s
join un.v_KPI k on (k.KpiID = s.KpiID and k.MeasureID = s.MeasureID)
join un.[Time] t on (t.KpiID = s.KpiID and t.MeasureID = s.MeasureID and t.TimeID = s.TimeID)
where 
	t.TimeID = @TimeID
	and k.IsSubsetKpi = 0
	and s.Value != 0
group by
	k.KMID
	, k.PathID
	, k.LongName
	, k.ParentFolderID 
	, k.IsPercent
	--, s.KpiID
	--, s.MeasureID
having 
  COUNT(*) >= 30
  and COUNT(DISTINCT s.Value) > 1
order by
  k.KMID

GO

-- peek
/*
EXEC un.usp_ValidKpi 324 -- 2010
EXEC un.usp_ValidKpi 328 -- 2014
*/
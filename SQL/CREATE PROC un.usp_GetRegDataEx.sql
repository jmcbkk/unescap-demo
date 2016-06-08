
USE DEV
GO

IF OBJECT_ID('un.usp_GetRegDataEx', 'p') IS NOT NULL
  DROP PROC un.usp_GetRegDataEx
GO

CREATE PROC un.usp_GetRegDataEx
(
  @KMID1 INT
  , @KMID2 INT
  , @TimeID INT
)

AS

declare @KpiID1 INT, @measureID1 INT
select @KpiID1 = KpiID, @MeasureID1 = MeasureID  from un.v_KPI where KMID = @KMID1

declare @KpiID2 INT, @measureID2 INT
select @KpiID2 = KpiID, @MeasureID2 = MeasureID  from un.v_KPI where KMID = @KMID2

select
  s1.AreaID
  , s1.AreaName
  , s1.Value AS XValue
  , s2.Value AS YValue
from 
(
	select s.AreaID, a.Name AS AreaName, s.Value
	from un.Stats s
	join un.Area a on (a.AreaID = s.AreaID)
	where s.KpiID = @KpiID1 and s.MeasureID = @MeasureID1 and s.TimeID = @TimeID and s.Value <> 0 -- exlcude zero values, assume these were unreported
) s1
join
(
	select s.AreaID, a.Name AS AreaName, s.Value
	from un.Stats s
	join un.Area a on (a.AreaID = s.AreaID)
	where s.KpiID = @KpiID2 and s.MeasureID = @MeasureID2 and s.TimeID = @TimeID and s.Value <> 0 -- exlcude zero values, assume these were unreported
) s2 on (s2.AreaID = s1.AreaID)
order by
  s1.Value

GO

-- test
/*
--  4 -- Population size [Thousands]
-- 20 -- Fertility rate [Live births per woman]
exec un.usp_GetRegDataEx 4, 20, 328 -- 2014
exec un.usp_GetRegDataEx 5, 625, 328 -- 2014
exec un.usp_GetRegDataEx 117, 823, 328 -- 2014
*/

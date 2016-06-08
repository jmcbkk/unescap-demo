
USE DEV
GO

IF OBJECT_ID('un.usp_GetRegData', 'p') IS NOT NULL
  DROP PROC un.usp_GetRegData
GO

CREATE PROC un.usp_GetRegData
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
  , s1.Value AS XValue
  , s2.Value AS YValue
from 
(
	select AreaID, Value
	from un.Stats
	where KpiID = @KpiID1 and MeasureID = @MeasureID1 and TimeID = @TimeID and Value <> 0 -- exlcude zero values, assume these were unreported
) s1
join
(
	select AreaID, Value
	from un.Stats
	where KpiID = @KpiID2 and MeasureID = @MeasureID2 and TimeID = @TimeID and Value <> 0 -- exlcude zero values, assume these were unreported
) s2 on (s2.AreaID = s1.AreaID)
--WHERE s1.AreaID NOT IN (106,54) -- India, China
order by
  s1.Value

GO

-- test
/*
--  4 -- Population size [Thousands]
-- 20 -- Fertility rate [Live births per woman]
exec un.usp_GetRegData 4, 20, 328 -- 2014
exec un.usp_GetRegData 5, 625, 328 -- 2014
exec un.usp_GetRegData 117, 823, 328 -- 2014
exec un.usp_GetRegData 118, 784, 324 -- 2010
exec un.usp_GetRegData 118, 784, 324 -- 2010
*/

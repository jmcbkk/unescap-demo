
USE DEV
GO

/*
create schema [un]
*/

/*

drop table un.Area
drop table un.Stats
drop table un.[Time]

truncate table un.Stats
truncate table un.[Time]

*/


CREATE TABLE un.[Stats]
(
  AreaID INT
  , TimeID INT
  , KpiID INT
  , MeasureID INT
  , Value FLOAT
)
GO


CREATE TABLE un.[Time]
(
  KpiID INT
  , MeasureID INT
  , TimeID INT
  , Label VARCHAR(16)
)
GO


CREATE TABLE un.Area
(
  AreaID INT
  , Name VARCHAR(50)
)
GO

/*
drop table un.KPI
*/
CREATE TABLE un.KPI
(
  OID INT
  , ParentID INT
  , KpiID INT
  , MeasureID INT
  , LongName NVARCHAR(200)
  , ShortName NVARCHAR(200)
  , MeasureName NVARCHAR(200)
)
GO

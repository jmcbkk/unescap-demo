
USE DEV
GO

IF OBJECT_ID('un.Reg', 'u') IS NOT NULL
  DROP TABLE un.Reg
GO

CREATE TABLE un.Reg
(
  x_kmid INT
  , y_kmid INT
  , timeid INT
  , n INT
  , rsq FLOAT
  , arsq FLOAT
  , b_est FLOAT
  , b_se FLOAT
  , b_tval FLOAT
  , b_pval FLOAT
  , a_est FLOAT
  , a_se FLOAT
  , a_tval FLOAT
  , a_pval FLOAT
  , wilks FLOAT
  , wilks_pval FLOAT
  , f FLOAT
  , f_pval FLOAT
  , model VARCHAR(20)
  , error_desc varchar(50) NULL
)
GO

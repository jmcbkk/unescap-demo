
library(RODBC)
library(ggplot2)

# frame to hold stats
rows <- data.frame(
  #x_name = character()
  #, y_name = character()
  x_kmid = integer()
  , y_kmid = integer()
  , timeid = integer()
  , n = integer()
  , rsq = double()
  , arsq = double()
  , b_est = double()
  , b_se = double()
  , b_tval = double()
  , b_pval = double()
  , a_est = double()
  , a_se = double()
  , a_tval = double()
  , a_pval = double()
  , wilks = double()
  , wilks_pval = double()
  , f = double()
  , f_pval = double()
  , stringsAsFactors = FALSE
)

#
# displays stats (lm & anaova) as wel las charts (qq and scatter)
#
TestIt <- function(kmid1, kmid2, timeid, model, trimper=NULL) 
{
  
	options(scipen=999) # supress sci. notation
	
  conn2 <-odbcConnect("LOCAL_2014EXP_X64", uid="dev", pwd="mom5069!")

  # get data
  tsql = "SET NOCOUNT ON\nEXEC DEV.un.usp_GetRegData %d, %d, %d"
  tsql = sprintf(tsql, kmid1, kmid2, timeid)
  tsqldat <- sqlQuery(conn2, tsql, errors = TRUE)
  
  # get var names
  tsql = sprintf("select LongName, 1 AS OrdID from DEV.un.v_KPI where KMID = %s UNION select LongName, 2 AS OrdID from DEV.un.v_KPI where KMID = %s ORDER BY 2", kmid1, kmid2)
  lbldat <- sqlQuery(conn2, tsql, errors = TRUE)
  
  close(conn2) 

  # re-order by X
  tsqldat <- tsqldat[order(tsqldat$XValue),]
  
  #reset row numbers
  rownames(tsqldat) <- seq(length=nrow(tsqldat))
 
  # trim obs, if passed
  if(!is.null(trimper)){
  	n = length(tsqldat[,1])
  	trim = round(n * trimper)
  	print(sprintf("Shaving off %d observations, from each end ...", trim))
  	tsqldat <- tsqldat[(trim+1):(n-trim),]
  	rownames(tsqldat) <- seq(length=nrow(tsqldat)) # reset again
  }
  
  # trasform data if model passed
  if(model == "y~ln(x)")   { tsqldat$XValue = log(tsqldat$XValue) }
  if(model == "y~sqrt(x)") { tsqldat$XValue = sqrt(tsqldat$XValue) }
  if(model == "ln(y)~x")   { tsqldat$YValue = log(tsqldat$YValue) }
  
  # labels
  xlabel = lbldat[1,1]
  ylabel = lbldat[2,1]

  # correlation
  corr = cor(tsqldat$XValue, tsqldat$YValue)
  
  # regression
  mod <- lm(YValue ~ XValue, data = tsqldat)
  
  #anova
  anov <- anova(mod)

  # wilks-shapiro test for norm. of resids
  stdres = rstandard(mod) 
  shap <- shapiro.test(stdres)

  # !!! add more tests here !!!
  
  ##output
  title = sprintf("Model %s : %s \n ~ f(%s)", model, ylabel, xlabel)
  print(title)

  print(tsqldat)

  print(sprintf("n = %d", length(tsqldat[,1])))
  print(sprintf("Correlation = %f", corr))
  print(summary(mod))
  print(anov)
  print(shap)
  
  ## plots
  
  par(mfrow=c(1,1))

  # scatter
  plot(tsqldat$XValue, tsqldat$YValue, xlab = "", ylab = "", main = "", pch=16, col="blue")
  abline(mod, col="red", lwd=2)
  title(
  	main = "Scatter Plot"
  	#main = title
  	, cex.main = 2.00
  	, xlab = "X"
  	, ylab = "Y"
  	, cex.lab = 1.00
  ) 
  
  # qq
  qqnorm(rstandard(mod), xlab = "", ylab = "", main = "", pch=17, col="blue")
  abline(a=0,b=1, lwd=2, col="red")
  title(
  	main = "Normal Q-Q Plot"
  	, ylab = "Standardized Residuals"
  	, xlab = "Theoretical Quantiles"
  	, cex.main = 2.00
  	, cex.lab = 1.00
  ) 
  
  #par(mfrow=c(2,2))
  #plot(mod, which=1:4, main="")

}


#
# return regression stats (estimates, p-values etc.) as row
#
RegressionIt <- function(regdat, xcol, ycol, trimper = NULL) 
{

  out <- vector("list", length(15))

  err_code = 0

  # trim obs, if passed
  if(!is.null(trimper)){
  	n = length(regdat[,1])
  	trim = round(length(regdat[,1]) * trimper)
  	# re-order by X
  	regdat <- regdat[order(regdat[, xcol]),]
  	# remove top and bottom  trimper % of obs
  	regdat <- regdat[(trim+1):(n-trim),]
  }
  
  # run simple regression model : y = ax + b
  mod <- lm(regdat[, ycol] ~ regdat[, xcol], data = regdat)

  # get resids for later testing
  stdres = rstandard(mod) 
  
  # TODO : why is this happening?
  # Collinear Model -> can only occur in multiple regression!
  if(!is.null(alias(mod)$Complete[1])) 
  { 
  	out[15] = -1 # err_code
    return(out)
  }

  # get reg stats
  rsquared = summary(mod)$r.squared
  arsquared = summary(mod)$adj.r.squared
  coeffs <- unname(summary(mod)$coefficients)
  
  # wilks test
  shap <- shapiro.test(stdres)
  wilk = unname(shap$statistic)
  wpval = unname(shap$p.value)
  
  # get F stat from anova
  lw <- NULL
  anov <- NULL
  tryCatch(
  	anova(mod),
  	warning = function(w){ lw <<- w$message },
  	finally = { anov <-- anova(mod) }
  ) 
  if(!is.null(lw) && grepl("essentially perfect fit", lw)) { err_code = -2 }
    
  f = anov$`F value`[1]
  f_pval = anov$`Pr(>F)`[1]

  # TODO : find way to flatten coeff rows to shorten code (e.g., coeffs[1,])   
  out <- c(rsquared, arsquared, coeffs[1,1], coeffs[1,2], coeffs[1,3], coeffs[1,4], coeffs[2,1], coeffs[2,2], coeffs[2,3], coeffs[2,4], wilk, wpval, f, f_pval, err_code)
  return(out)

}


PlotIt <- function(type)
{
	
	# open sql server conn'n
	conn <-odbcConnect("LOCAL_2014EXP_X64", uid="dev", pwd="mom5069!")
	
	sql = "
	select 
	  x_kmid
	  , y_kmid, timeid
	  , CAST(ROUND(rsq, 3) AS DEC(4,3)) as [rsq]
	  , CAST(ROUND(wilks_pval, 4) AS DEC(5,4)) as [wilks_pval] 
	from DEV.un.Reg r
	where 
	  error_desc = ''
	  and TimeID = 324 
	  and model = 'y~x'
	  and rsq >= 0.95
	  and r.wilks_pval > 0.00009
	order by 
	  wilks_pval DESC"

	# replace newline & tab
	sql = gsub("[\n\t]", " ", sql)
	loop <- sqlQuery(conn, sql, errors = TRUE)
	
	# we have 24 plots, so create an 6x4 grid
	par(mfrow=c(6,4), mar=c(0.25,0.25,0.25,0.25))

	for(i in 1:length(loop[,1]))
	{
		m_kmid1 = loop[i,1]
		m_kmid2 = loop[i,2]
		m_timeid = loop[i,3]
		m_rsq = round(loop[i,4], 3)
		m_wilksp = round(loop[i,5], 4)
		
		# debug
		#print(sprintf("%d -> %d (%d)", m_kmid1, m_kmid2, m_timeid))
		
		sql = "SET NOCOUNT ON\nEXEC DEV.un.usp_GetRegData %d, %d, %d"
		xsql = sprintf(sql, m_kmid1, m_kmid2, m_timeid)
		dat <- sqlQuery(conn, xsql, errors = TRUE)
		mod <- lm(YValue ~ XValue, dat) # regn
		
		if(type == "qq"){
			lbl = sprintf("p-val = %f", m_wilksp)
			lbl = substr(lbl, 1, nchar(lbl) - 2) # sprintf is padding numerics with zeros!
			qqnorm(rstandard(mod), xlab = "", ylab = "", main = "", pch=17, col="blue", xaxt='n', yaxt='n', ann=FALSE, xlim=c(-4.0,4.0), ylim=c(-4.0,4.0))
			abline(a=0,b=1, lwd=2, col="red")
			text(-3.75, 3.25, lbl, col="black", cex=1.5, pos=4, font=2) #bold
		}
		else{
			lbl = sprintf("r2 = %f", m_rsq)
			lbl = substr(lbl, 1, nchar(lbl) - 3) # sprintf is padding numerics with zeros!
			plot(dat$XValue, dat$YValue, xlab = "", ylab = "", main = "", pch=16, col="blue", xaxt='n', yaxt='n', ann=FALSE)
			abline(mod, lwd=2, col="red")
			text(min(dat$XValue) * 0.95, max(dat$YValue) * 0.90, lbl, col="black", cex=1.5, pos=4, font=2)
		}
		
		# test
		#if(i==9) {break}
	}
		
	close(conn) 
	
}


Main <- function ()
{ # BEGIN Main

	
# open sql server conn'n
conn <-odbcConnect("LOCAL_2014EXP_X64", uid="dev", pwd="mom5069!")

# start
ptm <- proc.time()

timeid = 324 # 2010
#timeid = 328 # 2014

# get list of Valid Kpi's (excluded any KPI with N < 30 or with all the same values, on the SQL Side)
sql = "SET NOCOUNT ON\nEXEC DEV.un.usp_ValidKpi %d"
sql = sprintf(sql, timeid)
loop <- sqlQuery(conn, sql, errors = TRUE)

total = 0

#guvnor = 382 # for testing, see SQL script 

# trimmed data
#trimPer = 0.025

model = "y~x"
#model = "y~x (tr 0.025)"
#model = "y~ln(x)"
#model = "ln(y)~x"

for(i in 1:length(loop[,1]))
{

  m_kmid1 = loop[i,1]
  m_pathid1 = loop[i,2]
  m_name1 = loop[i,3]
  m_folderid1 = loop[i,4]
  m_ispercent1 = loop[i,5]
  
  # to split up processing
  #if(m_kmid1 <= guvnor) { next }
  
  for(j in 1:length(loop[,1]))
  {

    m_kmid2 = loop[j,1]
    m_pathid2 = loop[j,2]
    m_name2 = loop[j,3]
    m_folderid2 = loop[j,4]
    m_ispercent2 = loop[j,5]

    # don't run models of vars in the same path, also no need  to run y~x and x~y
    if(m_pathid1 != m_pathid2 && m_kmid1 < m_kmid2) 
		{

   		# filter out ln models that don't pass the following conditions (pre-data retrtrieval)
   		if( model == "y~ln(x)" && (m_ispercent1 != 0 || m_ispercent2 != 1) ) { next }
   		if( model == "ln(y)~x" && (m_ispercent1 != 1 || m_ispercent2 != 0) ) { next }

   		sql = "SET NOCOUNT ON\nEXEC DEV.un.usp_GetRegData %d, %d, %d"
   		xsql = sprintf(sql, m_kmid1, m_kmid2, timeid)
      sqldat <- sqlQuery(conn, xsql, errors = TRUE)
      
      # filter out ln models that don't pass the following conditions (post-data retrtrieval)
      if( model == "y~ln(x)" && !all(sqldatx$XValue>0)) { next }
      if( model == "ln(y)~x" && !all(sqldatx$YValue>0)) { next }
      
      print(sprintf(">> Processing Model : %s ~ f(%s) [%d / %d]" , m_name2, m_name1, m_kmid1, m_kmid2))
      
      rowsEqual = FALSE
      if(all(sqldat$XValue == sqldat$XValue[1]) || all(sqldat$YValue == sqldat$YValue[1]))
      {
      	rowsEqual = TRUE
      }
      	 
      # TODO : clean up this IF block
      n = length(sqldat[,1])
      if(rowsEqual)
      {
      	isql = sprintf("INSERT INTO DEV.un.Reg(x_kmid, y_kmid, timeid, n, model, error_desc) VALUES(%d, %d, %d, %d,'%s','%s')", m_kmid1, m_kmid2, timeid, n, model, "EQUAL VALUES IN A COLUMN")
      	sqlQuery(conn, isql, errors = TRUE)
      }
      else if(n >= 30)
      {

      	if(model == "y~ln(x)") { sqldat$XValue = log(sqldat$XValue) }
      	if(model == "ln(y)~x") { sqldat$YValue = log(sqldat$YValue) }
      	
      	# TODO : get this value from RegressionIT
      	# if trimmed reset N
      	if(!is.null(trimPer)){
      		trim = round(n * trimPer)
      		n = (n-trim) - (trim+1) + 1
      	}
      	
        row <- RegressionIt(sqldat, "XValue", "YValue", trimPer)

        err_msg = ""
        err_code = row[15]
        
        if (err_code == -1) {err_msg = "COLLINEAR MODEL"}
        else if(err_code == -2) {err_msg = "PERFECT FIT"}
        else {err_msg = ""}
        
        new_row <- c(m_kmid1, m_kmid2, timeid, n, row[1:14])
        #rows[nrow(rows) + 1,] <- new_row # noneed to save locally since we are writing to sql
        
        values = paste(new_row, collapse = ",")
        isql = sprintf("INSERT INTO DEV.un.Reg VALUES(%s, '%s', '%s')", values, model, err_msg)
        sqlQuery(conn, isql, errors = TRUE)

      }
      else
      {
        isql = sprintf("INSERT INTO DEV.un.Reg(x_kmid, y_kmid, timeid, n, model, error_desc) VALUES(%d, %d, %d, %d,'%s','%s')", m_kmid1, m_kmid2, timeid, n, model, "INSUFFICIENT DATA")
        sqlQuery(conn, isql, errors = TRUE)
      }
      
      total = total + 1
    
      # alert every 1000 models
      if(total %% 1000 == 0)  { print(sprintf("****************************** %d MODELS PROCESSED ******************************", total)) }

    }
    
  }

}

msg = sprintf("%d Models Processed", total)
print(msg)

close(conn) 

# stop 
proc.time() - ptm

} # END Main


# !!! test !!!

#TestIt(118, 784, 324, "y~ln(x)")
#TestIt(118, 784, 324, "y~ln(x)", 0.05)
#TestIt(118, 784, 324, "y~sqrt(x)")
#TestIt(118, 784, 324, "y~sqrt(x)", 0.05)
#TestIt(781, 825, 324, "y~x")


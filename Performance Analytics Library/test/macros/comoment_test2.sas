%macro comoment_test2(keep=FALSE);
%global pass notes;

%if &keep=FALSE %then %do;
	filename x temp;
%end;
%else %do;
	filename x "&dir\comoment_test2_submit.sas";
%end;

data _null_;
file x;
put "submit /r;";
put "require(PerformanceAnalytics)";
put "prices = as.xts(read.zoo('&dir\\prices.csv',";
put "                 sep=',',";
put "                 header=TRUE";
put "                 )";
put "		)";
put "returns = Return.calculate(prices, method='discrete')";
put "returns = CoKurtosis(returns,returns)";
put "endsubmit;";
run;


proc iml;
%include x;

call importdatasetfromr("returns_from_R","returns");
quit;

data prices;
set input.prices;
run;

%return_calculate(prices,updateInPlace=TRUE,method=DISCRETE)
%comoments(prices,outCoKurt= cokurt);

/*If tables have 0 records then delete them.*/
proc sql noprint;
 %local nv;
 select count(*) into :nv TRIMMED from cokurt;
 %if ^&nv %then %do;
 	drop table cokurt;
 %end;
 
 select count(*) into :nv TRIMMED from returns_from_r;
 %if ^&nv %then %do;
 	drop table returns_from_r;
 %end;
quit ;

%if ^%sysfunc(exist(cokurt)) %then %do;
/*Error creating the data set, ensure compare fails*/
data cokurt;
	date = -1;
	IBM = -999;
	GE = IBM;
	DOW = IBM;
	GOOGL = IBM;
	SPY = IBM;
run;
%end;

%if ^%sysfunc(exist(returns_from_r)) %then %do;
/*Error creating the data set, ensure compare fails*/
data returns_from_r;
	date = 1;
	IBM = 999;
	GE = IBM;
	DOW = IBM;
	GOOGL = IBM;
	SPY = IBM;
run;
%end;

proc compare base=returns_from_r 
			 compare=cokurt 
			 method=absolute
			 out=diff(where=(_type_ = "DIF"
			            and (abs(IBM) > 1e-5 or abs(GE) > 1e-5
			              or abs(DOW) > 1e-5 or abs(GOOGL) > 1e-5)
			 		))
			noprint
			 ;
run;

data _null_;
if 0 then set diff nobs=n;
call symputx("n",n,"l");
stop;
run;

%if &n = 0 %then %do;
	%put NOTE: NO ERROR IN TEST Comoment_TEST2;
	%let pass=TRUE;
	%let notes=Passed;
%end;
%else %do;
	%put ERROR: PROBLEM IN TEST Comoment_TEST2;
	%let pass=FALSE;
	%let notes=Differences detected in outputs.;
%end;

%if &keep=FALSE %then %do;
	proc datasets lib=work nolist;
	delete diff prices cokurt returns_from_r M3;
	quit;
%end;

%mend;

*Name:RASHPINDER KAUR CHAHAL
PROJECT SAS;

libname project "D:\sas\Advanced_SAS\Project";

DATA project.telecom;
    INFILE "D:\sas\Advanced_SAS\Project\New_Wireless_Fixed.txt" DSD; 
	Informat Acctno $14. Actdt mmddyy10. Deactdt mmddyy10. Sales dollar10.2;
    INPUT Acctno  1-13
          @15 Actdt mmddyy10. 
          @26 Deactdt mmddyy10.
          DeactReason $ 41-44
          GoodCredit 53
          RatePlan 62
          DealerType $ 65-66
          Age 74-75
          Province $ 80-82
          @88 Sales  
; 
    format Actdt mmddyy10. Deactdt mmddyy10. Sales dollar10.2; 
run;

proc print data=project.telecom (obs=15);run;

*Objective: The wireless company would like to investigate the customer distribution and
business behaviors, and then gain insightful understanding about the customers, and to 
forecast the deactivation trends for the next 6 months.;

*Checking if all the account numbers are unique;
proc sql;
    select count(distinct Acctno) as Unique_Accts,
           count(Acctno) as Total_Accts
    from project.telecom;
quit;

*On observation, no of total accounts and unique accounts are same which means Acctno is 
unique for each row that means account numbers can be primary key for our dataset.
;

*Activation/Deactivation counts;
proc sql;
    select count(distinct acctno) as Activated_Accts, 
           count(deactdt) as Deactivated_Accts
    from project.telecom;
quit;

*
Number of Active accounts are equal to total number of accounts and number of deactivated 
accounts are 19635.
;

proc sql;
    select min(actdt) as Earliest_Activation format=mmddyy10.,
           max(actdt) as Latest_Activation format=mmddyy10.,
           min(deactdt) as Earliest_Deactivation format=mmddyy10.,
           max(deactdt) as Latest_Deactivation format=mmddyy10.
    from project.telecom;
quit;

data project.telecom_status;
set project.telecom;
if missing(deactdt) then Status='Active account';
else Status='Deactivated';
run;
proc print data=project.telecom_status (obs=5);run;

*1.2 What are the age and province distributions of active and deactivated customers? 
And is there any association between Age and activation, 
how about between Province and activation;

PROC MEANS DATA=project.telecom_status N MEAN MEDIAN STD MIN MAX;
   CLASS Status;
   VAR Age;
   TITLE "Age Distribution of Active vs. Deactivated Customers";
RUN;

PROC TTEST DATA=project.telecom_status;
   CLASS Status;
   VAR Age;
   TITLE "T-Test for Age and Account Status";
RUN;
*There is no significant difference in the age distribution between active and deactivated customers.
The variances of age are similar for both groups.
Age does not seem to be a strong factor in account deactivation.

Since p > 0.05, the difference in age is not statistically significant.
Age does not appear to be significantly different between active and deactivated customers.;


PROC FREQ DATA=project.telecom_status;
   TABLES Province*Status / NOCOL NOROW NOPERCENT CHISQ;
   TITLE "Province Distribution for Active vs. Deactivated Customers";
RUN;

*Since p > 0.05 in all tests,
Province and Account Status are NOT significantly associated.
This means the province a customer is from does not impact whether their account is 
active or deactivated.;

PROC SGPLOT DATA=PROJECT.TELECOM_STATUS;
VBAR PROVINCE / GROUP=STATUS GROUPDISPLAY=CLUSTER;
RUN;

*1.3 Customer Segmentation
Segment customers into defined groups for age and sales.

Sales Segments;
data project.segment;
    set project.telecom_status;
	if Sales eq . then Sales_Segment= 'Unknown';
    else if Sales < 100 then Sales_Segment = '< $100';
    else if 100 <= Sales < 500 then Sales_Segment = '$100-$500';
    else if 500 <= Sales < 800 then Sales_Segment = '$500-$800';
    else Sales_Segment = '$800+';
run;

*Age Segments;
data project.segment1;
    set project.segment;
	if Age eq . then Age_Segment = 'Unknown';
    else if Age < 20 then Age_Segment = '< 20';
    else if 20 <= Age < 41 then Age_Segment = '21-40';
    else if 41 <= Age < 61 then Age_Segment = '41-60';
    else Age_Segment = '60+';
run;

proc print data=project.segment1(obs=5);run;

*1.4 Statistical Analysis: Tenure Calculation and stats;
*Date used here is 20 January 2001 because the earliest activation is January 20, 1999 and
the analysis dataset is for two years so the maximum limit of the date will range upto two 
years from the earliest activated date.;

data project.tenure;
    set project.segment1;
	date=mdy(01,20,2001);
	if Status eq 'Deactivated' then Tenure = deactdt - actdt;
	else Tenure=date-actdt;
	format date actdt deactdt mmddyy10.;
run;

proc print data=project.tenure (obs=5);run;

proc means data=project.tenure n mean std min max;
    var Tenure;
	class Status;
run;

*Number of Accounts Deactivated per Month;
proc sql;
    select month(deactdt) as Deactivation_Month, 
           count(acctno) as Num_Deactivated
    from project.tenure
    group by Deactivation_Month;
quit;

*Segmenting by Account Status and Tenure;
data project.segmented_tenure;
    set project.tenure;  
    if missing(Tenure) then Tenure_Group ='Unspecified';
    else if Tenure < 30 then Tenure_Group = '< 30 days';
    else if Tenure >= 31 and Tenure < 61 then Tenure_Group = '31 - 60 days';
    else if Tenure >= 61 and Tenure < 365 then Tenure_Group = '61 days - 1 year';
    else if Tenure >= 365 then Tenure_Group = '1 year+';

run;

proc freq data=project.segmented_tenure;
    tables Status*Tenure_Group ;
    title "Account Segmentation by Status and Tenure";
run;
title'';
*Testing Association between Tenure and Customer Attributes
(Good Credit, Rate Plan, Dealer Type);
proc freq data=project.segmented_tenure;
    tables Tenure_Group*GoodCredit / chisq;
    tables Tenure_Group*RatePlan / chisq;
    tables Tenure_Group*DealerType / chisq;
run;

*Association Between Account Status and Tenure Segments;
proc freq data=project.segmented_tenure;
    tables Status*Tenure_Group / chisq;
run;

*Sales Amount by Account Status, Good Credit, and Customer Age Segments;
proc means data=project.segmented_tenure;
    class Status GoodCredit Age_Segment;
    var Sales;
run;

*Bivariate Analysis
To ensure you include bivariate analysis:

Continuous vs Continuous (Sales vs Tenure);
proc corr data=project.segmented_tenure;
var Sales Tenure;
title 'Correlation between Sales and Tenure';
run;

proc sgscatter data=project.segmented_tenure;
    matrix Sales Tenure;
run;

*Continuous vs Categorical (Sales vs Account Status):;
proc ttest data=project.segmented_tenure;
    class Status;
    var Sales;
	title'T-Test for Status and Sales';
run;

*Categorical vs Categorical (Province vs Account Status);
proc freq data=project.segmented_tenure;
    tables Province*Status/chisq;
	title "Chi-square test between Province and Account Status";
run;


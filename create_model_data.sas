/***********************************************************
*
* Project:       
* Program Name:  create_model_data.sas
* Author:        U-degobah\rsowers
*
* Creation Date: <2015-08-25 22:16:36> 
* Time-stamp:    <2015-10-19 19:24:36>
*
* Input:
*
* Output:
*
* Purpose:
*
* Modified:
*
************************************************************/

%macro create_model_data(projectPath = C:\cygwin64\home\rsowers\projects\glg ,
                         rawPath     = &projectPath\data\raw ,
                         outPath     = &projectPath\data ,
                         curExport   = &projectPath\current_data_exp.xls ,
                         coefExport  = &projectPath\coef_data_exp.xls ,
                         sumExport   = &projectPath\summary_data_exp.xls ,
                         fullExport  = &projectPath\full_export.xls ,
                         dateExport  = &projectPath\date_map.xls ,
                         histExport  = &projectPath\hist_export.xls ,
                         currentDS   = glg_hist_data );

    libname rawlib "&rawPath";
    libname outlib "&outPath";

/***********************************************************
* Summarize the current data
************************************************************/

    proc sql noprint;
        create table tmp_raw_data as select
            week,
            site,
            (case when missing(impressions) then 0 else impressions end) as impressions,
            (case when missing(clicks) then 0 else clicks end) as clicks,
            (case when missing(total_media_cost) then 0 else total_media_cost end) as total_media_cost,
            (case when missing(total_pageloads) then 0 else total_pageloads end) as total_pageloads,
            (case when missing(total_real_conversions) then 0 else total_real_conversions end) as total_real_conversions,
            (case when missing(total_value) then 0 else total_value end) as total_value
            from rawlib.&currentDS;

        create table raw_model_data_final as select
            week,
            site,
            (case when sum(clicks)>sum(impressions) then sum(clicks) else sum(impressions) end) as impressions,
            sum(clicks) as clicks,
            sum(total_media_cost) as total_media_cost,
            sum(total_pageloads) as total_pageloads,
            ((calculated total_pageloads)/(calculated impressions)) as conv_rate format=percent12.2,
            ((calculated clicks)/(calculated impressions)) as click_conv_rate format=percent12.2,
            ((calculated total_media_cost)/(calculated impressions)) as cost_per_imp format=dollar12.2,
            max(((calculated total_media_cost)/(calculated total_pageloads)),.01) as cost_per_conv format=dollar12.2,
            sum(total_real_conversions) as conv_count,
            sum(total_value) as value
            from tmp_raw_data
            where total_media_cost gt 200
            group by site, week;
        quit;
    run;

    proc export data = raw_model_data_final
        outfile = "&histExport" 
        dbms = excel2000 replace;
        sheet = "Model Coeficients"; 
    run;

    proc sql noprint;
        create table raw_model_data as select
            trim(site) as model_group, *
            from raw_model_data_final
            where week = "9/28/2015";
        
        create table raw_model_no_twit as select *
            from raw_model_data
            where upcase(site) ne "TWITTER.COM";

        create table raw_model_twit as select *
            from raw_model_data
            where upcase(site) eq "TWITTER.COM";
        quit;
    run;

/***********************************************************
* Use historical data to create models (non twitter)
************************************************************/

    proc sql noprint;
        create table tmp_model_group as select distinct model_group
            from raw_model_no_twit;
        quit;
    run;

    data _NULL_;
        set tmp_model_group end=last_obs;
        call symput(compress("model_group_"||_N_),upcase(trim(model_group)));
        if last_obs then call symput("model_group_count",_N_);
    run;    

    %do i = 1 %to &model_group_count;
        %put RHSNOTE(): &&model_group_&i;

        proc sql noprint;
            create table tmp_model_data_&i as select *
                from raw_model_no_twit
                where upcase(model_group) eq "&&model_group_&i"
                order by week desc;
            quit;
        run;

        data tmp_model_data_&i;
            set tmp_model_data_&i (obs=2);
        run;

        %put RHSNOTE(): &&model_group_&i;
        
        proc sql noprint;
            select max(int((max(impressions))*1.25),5) into :max_imp_count
                from tmp_model_data_&i;

            select int(avg(impressions)) into :avg_imp_count
                from tmp_model_data_&i;

            select max(avg(cost_per_imp),.01) into :per_imp_spend
                from tmp_model_data_&i;
            quit;
        run;

        %put RHSNOTE: &max_imp_count;
        %put RHSNOTE: &avg_imp_count;
        %put RHSNOTE: &per_imp_spend;

        data tmp_model_linear_&i (where=(ln_imp_cost>0));
            %do j = 1 %to &max_imp_count %by 100;
                imp_num = &j;
                imp_cost = &j * &per_imp_spend;
                ln_imp_cost = log(&j * &per_imp_spend);
                output;
                %end;
        run;

        proc reg data = tmp_model_linear_&i outest = tmp_model_output_&i rsquare;
            model imp_num = ln_imp_cost;
        run;

        data tmp_model_output_&i;
            set tmp_model_output_&i;
            model_group = "&&model_group_&i";
        run;

        %end;

    data model_coefs_no_twit;
        set %do i = 1 %to &model_group_count; tmp_model_output_&i %end;;
    run;

    proc export data = model_coefs_no_twit
        outfile = "&coefExport" 
        dbms = excel2000 replace;
        sheet = "Model Coeficients"; 
    run;

/***********************************************************
* Use historical data to create models (twitter only)
************************************************************/

    
    
%mend create_model_data;

%create_model_data;

